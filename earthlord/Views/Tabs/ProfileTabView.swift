import SwiftUI
import Supabase

struct ProfileTabView: View {
    // MARK: - 属性
    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var languageManager = LanguageManager.shared
    @Environment(\.openURL) private var openURL

    /// 是否显示退出确认弹窗
    @State private var showLogoutAlert: Bool = false

    /// 是否正在退出
    @State private var isLoggingOut: Bool = false

    /// 是否显示语言选择弹窗
    @State private var showLanguagePicker: Bool = false

    /// 是否显示删除账户确认弹窗
    @State private var showDeleteConfirmation: Bool = false

    /// 是否正在删除账户
    @State private var isDeleting: Bool = false

    /// 删除确认输入文字
    @State private var deleteConfirmText: String = ""

    /// Toast 消息
    @State private var toastMessage: String?

    /// 是否显示付费墙
    @State private var showPaywall: Bool = false

    /// 是否显示商店
    @State private var showShop: Bool = false

    // MARK: - Body
    var body: some View {
        ZStack {
            // 背景
            ApocalypseTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // 用户信息卡片
                    userInfoCard

                    // 统计数据
                    statsSection

                    // 功能菜单
                    menuSection

                    // 退出登录按钮
                    logoutButton

                    // 删除账户按钮
                    deleteAccountButton

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }

            // 加载遮罩
            if isLoggingOut {
                loadingOverlay(message: "正在退出...".localized)
            }

            // 删除中遮罩
            if isDeleting {
                loadingOverlay(message: "正在删除账户...".localized)
            }

            // Toast 提示
            if let message = toastMessage {
                toastView(message: message)
            }
        }
        .alert("退出登录", isPresented: $showLogoutAlert) {
            Button("取消", role: .cancel) { }
            Button("退出", role: .destructive) {
                performLogout()
            }
        } message: {
            Text("确定要退出当前账号吗？")
        }
        .id(LanguageManager.shared.refreshID)
        .sheet(isPresented: $showLanguagePicker) {
            LanguagePickerSheet(
                languageManager: languageManager,
                onDismiss: {
                    showLanguagePicker = false
                }
            )
            .presentationDetents([.height(280)])
        }
        .sheet(isPresented: $showDeleteConfirmation) {
            DeleteAccountSheet(
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
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showShop) {
            ConsumableShopView()
        }
    }

    // MARK: - 用户信息卡片
    private var userInfoCard: some View {
        VStack(spacing: 16) {
            // 头像
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: ApocalypseTheme.primary.opacity(0.4), radius: 10)

                // 用户名首字母或默认图标
                if let email = authManager.currentUser?.email,
                   let firstChar = email.first {
                    Text(String(firstChar).uppercased())
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }
            }

            // 用户名/邮箱
            VStack(spacing: 4) {
                Text(displayName)
                    .font(.title2.bold())
                    .foregroundColor(ApocalypseTheme.textPrimary)

                if let email = authManager.currentUser?.email {
                    Text(email)
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }

            // 幸存者等级标签
            HStack(spacing: 6) {
                if EntitlementManager.shared.isSubscribed {
                    Image(systemName: "crown.fill")
                        .font(.caption)
                    Text("精英幸存者".localized)
                        .font(.caption.bold())
                } else {
                    Image(systemName: "shield.checkered")
                        .font(.caption)
                    Text("幸存者 Lv.1".localized)
                        .font(.caption.bold())
                }
            }
            .foregroundColor(ApocalypseTheme.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(ApocalypseTheme.primary.opacity(0.15))
            .cornerRadius(20)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - 统计数据
    private var statsSection: some View {
        HStack(spacing: 12) {
            StatCard(icon: "map", title: "领地".localized, number: "0", unit: "块".localized)
            StatCard(icon: "building.2", title: "建筑".localized, number: "0", unit: "座".localized)
            StatCard(icon: "calendar", title: "存活".localized, number: "1", unit: "天".localized)
        }
    }

    // MARK: - 通用设置
    private var menuSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 会员服务菜单组
            iapMenuSection

            Text("通用".localized)
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .padding(.leading, 4)

            VStack(spacing: 2) {
                MenuRow(icon: "globe", title: "语言".localized, value: languageManager.currentLanguage.displayName, showArrow: true) {
                    showLanguagePicker = true
                }

                MenuRow(icon: "moon", title: "深色模式".localized, value: "跟随系统".localized, showArrow: true) {
                    showToast("功能开发中...".localized)
                }

                MenuRow(icon: "questionmark.circle.fill", title: "技术支持".localized, showArrow: true) {
                    if let url = URL(string: "https://trantrong386hk-droid.github.io/earthlord-support/support.html") {
                        openURL(url)
                    }
                }

                MenuRow(icon: "hand.raised.fill", title: "隐私政策".localized, showArrow: true) {
                    if let url = URL(string: "https://trantrong386hk-droid.github.io/earthlord-support/privacy.html") {
                        openURL(url)
                    }
                }
            }
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(16)
        }
    }

    // MARK: - 会员服务菜单
    private var iapMenuSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("会员服务".localized)
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .padding(.leading, 4)

            VStack(spacing: 2) {
                if EntitlementManager.shared.isSubscribed {
                    // 已订阅：显示会员管理
                    MenuRow(
                        icon: "crown.fill",
                        title: "精英幸存者".localized,
                        value: subscriptionStatusText,
                        showArrow: true
                    ) {
                        // 打开系统订阅管理
                        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                            openURL(url)
                        }
                    }
                } else {
                    // 未订阅：显示升级入口
                    MenuRow(icon: "crown.fill", title: "精英幸存者".localized, value: "升级".localized, showArrow: true) {
                        showPaywall = true
                    }
                }

                MenuRow(icon: "bag.fill", title: "物资商店".localized, showArrow: true) {
                    showShop = true
                }
            }
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(16)
        }
    }

    /// 订阅状态文字
    private var subscriptionStatusText: String {
        if let expiresAt = StoreKitManager.shared.subscriptionStatus.expiresAt {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy/MM/dd"
            return "到期 \(formatter.string(from: expiresAt))"
        }
        return "已订阅"
    }

    // MARK: - 退出登录按钮
    private var logoutButton: some View {
        Button {
            showLogoutAlert = true
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("退出登录".localized)
            }
            .font(.headline)
            .foregroundColor(ApocalypseTheme.danger)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(ApocalypseTheme.danger.opacity(0.1))
            .cornerRadius(12)
        }
    }

    // MARK: - 删除账户按钮
    private var deleteAccountButton: some View {
        Button {
            showDeleteConfirmation = true
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("删除账户".localized)
            }
            .font(.subheadline)
            .foregroundColor(ApocalypseTheme.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }

    // MARK: - 加载遮罩
    private func loadingOverlay(message: String) -> some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                    .scaleEffect(1.5)

                Text(verbatim: message)
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

    /// 显示 Toast 提示
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

    // MARK: - 计算属性

    /// 显示名称
    private var displayName: String {
        if let email = authManager.currentUser?.email {
            // 取邮箱 @ 前面的部分作为用户名
            return email.components(separatedBy: "@").first ?? "幸存者".localized
        }
        return "幸存者".localized
    }

    // MARK: - 方法

    /// 执行退出登录
    private func performLogout() {
        isLoggingOut = true

        Task {
            await authManager.signOut()

            await MainActor.run {
                isLoggingOut = false
            }
        }
    }

    /// 执行删除账户
    private func performDeleteAccount() {
        print("🔴 [个人页面] 用户确认删除账户")
        isDeleting = true
        showDeleteConfirmation = false
        deleteConfirmText = ""

        Task {
            let success = await authManager.deleteAccount()

            await MainActor.run {
                isDeleting = false

                if success {
                    print("✅ [个人页面] 账户删除成功")
                } else {
                    print("❌ [个人页面] 账户删除失败: \(authManager.errorMessage ?? "未知错误")")
                }
            }
        }
    }
}

// MARK: - 菜单行组件
/// 注意：调用时需传入已本地化的字符串（使用 .localized）
struct MenuRow: View {
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

                Text(verbatim: title)
                    .font(.body)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                if let value = value {
                    Text(verbatim: value)
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
struct DeleteAccountSheet: View {
    @Binding var confirmText: String
    @Binding var isDeleting: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    /// 确认文字是否正确（支持中英文）
    private var isConfirmTextCorrect: Bool {
        confirmText == "删除" || confirmText.lowercased() == "delete"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    // 警告图标
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(ApocalypseTheme.danger)

                    // 标题
                    Text("确认删除账户".localized)
                        .font(.title3.bold())
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    // 说明
                    Text("此操作不可撤销！删除后所有数据将永久丢失。".localized)
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .multilineTextAlignment(.center)

                    // 确认输入
                    VStack(alignment: .leading, spacing: 8) {
                        Text("请输入 \"删除\" 以确认：".localized)
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        TextField("输入 删除".localized, text: $confirmText)
                            .foregroundColor(ApocalypseTheme.textPrimary)
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
                            Text("永久删除账户".localized)
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
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
                            Text("取消".localized)
                                .font(.headline)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
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
    ProfileTabView()
}
