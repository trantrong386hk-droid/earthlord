//
//  SettingsView.swift
//  earthlord
//
//  设置页面
//

import SwiftUI

struct SettingsView: View {
    // MARK: - 属性
    @ObservedObject private var authManager = AuthManager.shared
    @Environment(\.dismiss) private var dismiss

    /// 是否显示删除账户确认弹窗
    @State private var showDeleteConfirmation: Bool = false

    /// 是否正在删除
    @State private var isDeleting: Bool = false

    /// 删除确认输入文字
    @State private var deleteConfirmText: String = ""

    /// Toast 消息
    @State private var toastMessage: String?

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // 账户设置区域
                        accountSection

                        // 通用设置区域
                        generalSection

                        // 危险区域
                        dangerZoneSection

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }

                // 加载遮罩
                if isDeleting {
                    deletingOverlay
                }

                // Toast 提示
                if let message = toastMessage {
                    toastView(message: message)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }
                }
            }
            .sheet(isPresented: $showDeleteConfirmation) {
                DeleteAccountConfirmationSheet(
                    confirmText: $deleteConfirmText,
                    isDeleting: $isDeleting,
                    onConfirm: performDeleteAccount,
                    onCancel: {
                        deleteConfirmText = ""
                        showDeleteConfirmation = false
                    }
                )
                .presentationDetents([.medium])
            }
        }
    }

    // MARK: - 账户设置区域
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("账户")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .padding(.leading, 4)

            VStack(spacing: 2) {
                SettingsRow(icon: "person.circle", title: "个人资料", showArrow: true) {
                    showToast("功能开发中...")
                }

                SettingsRow(icon: "lock.shield", title: "隐私设置", showArrow: true) {
                    showToast("功能开发中...")
                }

                SettingsRow(icon: "key", title: "修改密码", showArrow: true) {
                    showToast("功能开发中...")
                }
            }
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(16)
        }
    }

    // MARK: - 通用设置区域
    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("通用")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .padding(.leading, 4)

            VStack(spacing: 2) {
                SettingsRow(icon: "globe", title: "语言", value: "简体中文", showArrow: true) {
                    showToast("功能开发中...")
                }

                SettingsRow(icon: "moon", title: "深色模式", value: "跟随系统", showArrow: true) {
                    showToast("功能开发中...")
                }

                SettingsRow(icon: "bell.badge", title: "推送通知", showArrow: true) {
                    showToast("功能开发中...")
                }
            }
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(16)
        }
    }

    // MARK: - 危险区域
    private var dangerZoneSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("危险区域")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.danger)
                .padding(.leading, 4)

            VStack(spacing: 2) {
                Button {
                    showDeleteConfirmation = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "trash")
                            .font(.body)
                            .foregroundColor(ApocalypseTheme.danger)
                            .frame(width: 24)

                        Text("删除账户")
                            .font(.body)
                            .foregroundColor(ApocalypseTheme.danger)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.danger.opacity(0.5))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .background(ApocalypseTheme.danger.opacity(0.1))
            .cornerRadius(16)

            Text("删除账户后，所有数据将被永久删除且无法恢复。")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)
                .padding(.leading, 4)
        }
    }

    // MARK: - 删除中遮罩
    private var deletingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.danger))
                    .scaleEffect(1.5)

                Text("正在删除账户...")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding(32)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(16)
        }
    }

    // MARK: - Toast 视图
    private func toastView(message: String) -> some View {
        VStack {
            Spacer()

            Text(message)
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.8))
                .cornerRadius(8)
                .padding(.bottom, 100)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.easeInOut, value: toastMessage)
    }

    // MARK: - 方法

    /// 显示 Toast
    private func showToast(_ message: String) {
        withAnimation {
            toastMessage = message
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                toastMessage = nil
            }
        }
    }

    /// 执行删除账户
    private func performDeleteAccount() {
        print("🔴 [设置页面] 用户确认删除账户")
        isDeleting = true
        showDeleteConfirmation = false
        deleteConfirmText = ""

        Task {
            let success = await authManager.deleteAccount()

            await MainActor.run {
                isDeleting = false

                if success {
                    print("✅ [设置页面] 账户删除成功，即将跳转登录页")
                    // 删除成功后会自动跳转到登录页（因为 isAuthenticated = false）
                } else {
                    print("❌ [设置页面] 账户删除失败")
                    showToast(authManager.errorMessage ?? "删除失败，请稍后重试")
                }
            }
        }
    }
}

// MARK: - 设置行组件
struct SettingsRow: View {
    let icon: String
    let title: String
    var value: String? = nil
    var showArrow: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(ApocalypseTheme.primary)
                    .frame(width: 24)

                Text(title)
                    .font(.body)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                if let value = value {
                    Text(value)
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }

                if showArrow {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }
}

// MARK: - 删除账户确认弹窗
struct DeleteAccountConfirmationSheet: View {
    @Binding var confirmText: String
    @Binding var isDeleting: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    /// 确认文字是否正确
    private var isConfirmTextCorrect: Bool {
        confirmText == "删除"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // 警告图标
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(ApocalypseTheme.danger)

                    // 标题
                    Text("确认删除账户")
                        .font(.title2.bold())
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    // 说明
                    VStack(spacing: 8) {
                        Text("此操作不可撤销！")
                            .font(.headline)
                            .foregroundColor(ApocalypseTheme.danger)

                        Text("删除账户后，以下数据将被永久删除：")
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        VStack(alignment: .leading, spacing: 4) {
                            Label("个人资料和设置", systemImage: "person.crop.circle")
                            Label("游戏进度和成就", systemImage: "gamecontroller")
                            Label("领地和建筑数据", systemImage: "building.2")
                            Label("所有历史记录", systemImage: "clock")
                        }
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)
                    }

                    // 确认输入
                    VStack(alignment: .leading, spacing: 8) {
                        Text("请输入 \"删除\" 以确认：")
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        TextField("输入 删除", text: $confirmText)
                            .padding()
                            .background(ApocalypseTheme.cardBackground)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        isConfirmTextCorrect
                                            ? ApocalypseTheme.danger
                                            : ApocalypseTheme.textMuted.opacity(0.3),
                                        lineWidth: 1
                                    )
                            )
                    }

                    Spacer()

                    // 按钮
                    VStack(spacing: 12) {
                        Button {
                            onConfirm()
                        } label: {
                            Text("永久删除我的账户")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    isConfirmTextCorrect
                                        ? ApocalypseTheme.danger
                                        : ApocalypseTheme.textMuted
                                )
                                .cornerRadius(12)
                        }
                        .disabled(!isConfirmTextCorrect || isDeleting)

                        Button {
                            onCancel()
                        } label: {
                            Text("取消")
                                .font(.headline)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                    }
                }
                .padding(24)
            }
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    SettingsView()
}
