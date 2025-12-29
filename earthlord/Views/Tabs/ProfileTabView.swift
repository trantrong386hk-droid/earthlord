import SwiftUI
import Supabase

struct ProfileTabView: View {
    // MARK: - 属性
    @ObservedObject private var authManager = AuthManager.shared

    /// 是否显示退出确认弹窗
    @State private var showLogoutAlert: Bool = false

    /// 是否正在退出
    @State private var isLoggingOut: Bool = false

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

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }

            // 加载遮罩
            if isLoggingOut {
                loadingOverlay
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
                Image(systemName: "shield.checkered")
                    .font(.caption)
                Text("幸存者 Lv.1")
                    .font(.caption.bold())
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
            StatCard(icon: "map", title: "领地", number: "0", unit: "块")
            StatCard(icon: "building.2", title: "建筑", number: "0", unit: "座")
            StatCard(icon: "calendar", title: "存活", number: "1", unit: "天")
        }
    }

    // MARK: - 功能菜单
    private var menuSection: some View {
        VStack(spacing: 2) {
            MenuRow(icon: "gearshape", title: "设置", showArrow: true) {
                // TODO: 跳转设置页
            }

            MenuRow(icon: "bell", title: "通知", showArrow: true) {
                // TODO: 跳转通知页
            }

            MenuRow(icon: "questionmark.circle", title: "帮助与反馈", showArrow: true) {
                // TODO: 跳转帮助页
            }

            MenuRow(icon: "info.circle", title: "关于", showArrow: true) {
                // TODO: 跳转关于页
            }
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - 退出登录按钮
    private var logoutButton: some View {
        Button {
            showLogoutAlert = true
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("退出登录")
            }
            .font(.headline)
            .foregroundColor(ApocalypseTheme.danger)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(ApocalypseTheme.danger.opacity(0.1))
            .cornerRadius(12)
        }
    }

    // MARK: - 加载遮罩
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                    .scaleEffect(1.5)

                Text("正在退出...")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding(32)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(16)
        }
    }

    // MARK: - 计算属性

    /// 显示名称
    private var displayName: String {
        if let email = authManager.currentUser?.email {
            // 取邮箱 @ 前面的部分作为用户名
            return email.components(separatedBy: "@").first ?? "幸存者"
        }
        return "幸存者"
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
}

// MARK: - 菜单行组件
struct MenuRow: View {
    let icon: String
    let title: String
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

#Preview {
    ProfileTabView()
}
