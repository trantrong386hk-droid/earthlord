//
//  CallsignSettingsSheet.swift
//  earthlord
//
//  呼号设置弹窗 - 用户电台身份标识
//

import SwiftUI
import Auth
import Supabase

struct CallsignSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var authManager = AuthManager.shared

    @State private var callsign = ""
    @State private var currentCallsign: String?
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    private let client = supabase

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 呼号说明
                    callsignInfoSection

                    // 输入表单
                    callsignInputSection

                    // 推荐格式
                    recommendedFormatsSection

                    // 保存按钮
                    saveButton
                }
                .padding(20)
            }
            .background(ApocalypseTheme.background)
            .navigationTitle("呼号设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .alert("保存成功", isPresented: $showSuccess) {
                Button("确定") {
                    dismiss()
                }
            } message: {
                Text("您的呼号已更新")
            }
            .onAppear {
                loadCurrentCallsign()
            }
        }
    }

    // MARK: - 呼号说明

    private var callsignInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(ApocalypseTheme.primary)

                Text("什么是呼号？")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            Text("呼号是您在通讯频道中的身份标识，其他生存者通过呼号识别您。一个好的呼号应该简洁、易读、有辨识度。")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(ApocalypseTheme.primary.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - 输入表单

    private var callsignInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("呼号")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                if let current = currentCallsign {
                    Text("当前: \(current)")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }

            TextField("输入呼号", text: $callsign)
                .font(.body)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .padding(14)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isValidCallsign ? Color.clear : Color.red.opacity(0.5),
                            lineWidth: 1
                        )
                )
                .autocapitalization(.allCharacters)
                .disableAutocorrection(true)

            // 验证提示
            if !callsign.isEmpty && !isValidCallsign {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))

                    Text(validationMessage)
                        .font(.caption)
                }
                .foregroundColor(.red)
            }

            // 错误消息
            if let error = errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))

                    Text(error)
                        .font(.caption)
                }
                .foregroundColor(.red)
            }
        }
    }

    // MARK: - 推荐格式

    private var recommendedFormatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("推荐格式")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            VStack(alignment: .leading, spacing: 8) {
                FormatExampleRow(format: "BJ-Alpha-001", description: "地区-单位-编号")
                FormatExampleRow(format: "Survivor-42", description: "昵称-编号")
                FormatExampleRow(format: "Eagle-Eye", description: "代号风格")
            }
            .padding(14)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)

            Text("• 长度: 3-20 个字符\n• 仅支持字母、数字、连字符（-）")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.7))
        }
    }

    // MARK: - 保存按钮

    private var saveButton: some View {
        Button(action: saveCallsign) {
            HStack {
                if isSaving {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))

                    Text("保存呼号")
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(
                isValidCallsign && !isSaving
                    ? ApocalypseTheme.primary
                    : ApocalypseTheme.textSecondary.opacity(0.3)
            )
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!isValidCallsign || isSaving)
    }

    // MARK: - 验证逻辑

    private var isValidCallsign: Bool {
        let trimmed = callsign.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard trimmed.count >= 3 && trimmed.count <= 20 else { return false }

        // 只允许字母、数字、连字符
        let pattern = "^[A-Za-z0-9-]+$"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        return regex.firstMatch(in: trimmed, range: range) != nil
    }

    private var validationMessage: String {
        let trimmed = callsign.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count < 3 {
            return "呼号至少需要 3 个字符"
        } else if trimmed.count > 20 {
            return "呼号最多 20 个字符"
        } else {
            return "仅支持字母、数字、连字符"
        }
    }

    // MARK: - 数据操作

    private func loadCurrentCallsign() {
        guard let userId = authManager.currentUser?.id else { return }

        isLoading = true
        Task {
            do {
                struct UserProfile: Codable {
                    let callsign: String?
                }

                let profiles: [UserProfile] = try await client
                    .from("user_profiles")
                    .select("callsign")
                    .eq("user_id", value: userId.uuidString)
                    .execute()
                    .value

                if let profile = profiles.first, let existingCallsign = profile.callsign {
                    currentCallsign = existingCallsign
                    callsign = existingCallsign
                }
            } catch {
                print("❌ [呼号] 加载失败: \(error)")
            }
            isLoading = false
        }
    }

    private func saveCallsign() {
        guard let userId = authManager.currentUser?.id else { return }

        isSaving = true
        errorMessage = nil

        Task {
            do {
                struct UpsertData: Encodable {
                    let userId: String
                    let callsign: String

                    enum CodingKeys: String, CodingKey {
                        case userId = "user_id"
                        case callsign
                    }
                }

                let data = UpsertData(
                    userId: userId.uuidString,
                    callsign: callsign.trimmingCharacters(in: .whitespacesAndNewlines)
                )

                try await client
                    .from("user_profiles")
                    .upsert(data)
                    .execute()

                showSuccess = true
            } catch {
                errorMessage = "保存失败: \(error.localizedDescription)"
                print("❌ [呼号] 保存失败: \(error)")
            }
            isSaving = false
        }
    }
}

// MARK: - 格式示例行

struct FormatExampleRow: View {
    let format: String
    let description: String

    var body: some View {
        HStack {
            Text(format)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            Text(description)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }
}

// MARK: - 预览

#Preview {
    CallsignSettingsSheet()
}
