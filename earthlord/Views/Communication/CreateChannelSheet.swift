//
//  CreateChannelSheet.swift
//  earthlord
//
//  创建频道页面
//  支持选择类型、输入名称和描述
//

import SwiftUI
import Auth

struct CreateChannelSheet: View {
    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var communicationManager = CommunicationManager.shared
    @Environment(\.dismiss) private var dismiss

    let onChannelCreated: (CommunicationChannel) -> Void

    @State private var selectedType: ChannelType = .public
    @State private var channelName = ""
    @State private var channelDescription = ""
    @State private var isCreating = false
    @State private var showError = false
    @State private var errorMessage = ""

    // 名称验证
    private var isNameValid: Bool {
        channelName.count >= 2 && channelName.count <= 50
    }

    private var nameHelperText: String {
        if channelName.isEmpty {
            return "请输入频道名称"
        } else if channelName.count < 2 {
            return "名称至少需要 2 个字符"
        } else if channelName.count > 50 {
            return "名称最多 50 个字符"
        }
        return "名称有效"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 类型选择
                    typeSelectionSection

                    // 名称输入
                    nameInputSection

                    // 描述输入
                    descriptionInputSection

                    // 创建按钮
                    createButton
                }
                .padding(20)
            }
            .background(ApocalypseTheme.background)
            .navigationTitle("创建频道")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .alert("创建失败", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - 类型选择

    private var typeSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("频道类型")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(ChannelType.userCreatable, id: \.self) { type in
                    typeCard(type)
                }
            }
        }
    }

    private func typeCard(_ type: ChannelType) -> some View {
        Button(action: { selectedType = type }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(selectedType == type ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
                        .frame(width: 48, height: 48)

                    Image(systemName: type.iconName)
                        .font(.system(size: 22))
                        .foregroundColor(selectedType == type ? .white : ApocalypseTheme.textSecondary)
                }

                Text(type.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(selectedType == type ? ApocalypseTheme.primary : ApocalypseTheme.textPrimary)

                Text(type.description)
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedType == type ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary.opacity(0.3), lineWidth: selectedType == type ? 2 : 1)
            )
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedType == type ? ApocalypseTheme.primary.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 名称输入

    private var nameInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("频道名称")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            HStack {
                TextField("输入频道名称...", text: $channelName)
                    .textFieldStyle(.plain)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .padding(12)

                if !channelName.isEmpty {
                    Image(systemName: isNameValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isNameValid ? .green : .red)
                        .padding(.trailing, 12)
                }
            }
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(10)

            HStack {
                Text(nameHelperText)
                    .font(.caption)
                    .foregroundColor(isNameValid || channelName.isEmpty ? ApocalypseTheme.textSecondary : .red)

                Spacer()

                Text("\(channelName.count)/50")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
    }

    // MARK: - 描述输入

    private var descriptionInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("频道描述")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("(可选)")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            TextEditor(text: $channelDescription)
                .scrollContentBackground(.hidden)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .frame(height: 80)
                .padding(8)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(10)

            HStack {
                Spacer()
                Text("\(channelDescription.count)/200")
                    .font(.caption)
                    .foregroundColor(channelDescription.count > 200 ? .red : ApocalypseTheme.textSecondary)
            }
        }
    }

    // MARK: - 创建按钮

    private var createButton: some View {
        Button(action: createChannel) {
            HStack(spacing: 8) {
                if isCreating {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.8)
                }
                Text(isCreating ? "创建中..." : "创建频道")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isNameValid && !isCreating ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary.opacity(0.3))
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!isNameValid || isCreating)
        .padding(.top, 8)
    }

    // MARK: - 创建频道

    private func createChannel() {
        guard let userId = authManager.currentUser?.id else {
            errorMessage = "请先登录"
            showError = true
            return
        }

        guard isNameValid else { return }

        let description = channelDescription.isEmpty ? nil : channelDescription

        isCreating = true

        Task {
            if let channel = await communicationManager.createChannel(
                userId: userId,
                type: selectedType,
                name: channelName,
                description: description
            ) {
                await MainActor.run {
                    isCreating = false
                    onChannelCreated(channel)
                }
            } else {
                await MainActor.run {
                    isCreating = false
                    errorMessage = communicationManager.errorMessage ?? "创建失败，请重试"
                    showError = true
                }
            }
        }
    }
}

#Preview {
    CreateChannelSheet(onChannelCreated: { _ in })
}
