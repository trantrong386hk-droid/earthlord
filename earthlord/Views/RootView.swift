import SwiftUI

/// 根视图：控制启动页、认证页、新手引导与主界面的切换
struct RootView: View {
    /// 认证管理器
    @StateObject private var authManager = AuthManager.shared

    /// 语言管理器
    @EnvironmentObject var languageManager: LanguageManager

    /// 启动页是否完成
    @State private var splashFinished = false

    /// 是否已完成新手引导
    @AppStorage("has_completed_onboarding") private var hasCompletedOnboarding = false

    var body: some View {
        ZStack {
            if !splashFinished {
                // 启动页
                SplashView(isFinished: $splashFinished)
                    .transition(.opacity)
            } else if !hasCompletedOnboarding {
                // 首次使用：显示新手引导
                OnboardingView {
                    hasCompletedOnboarding = true
                }
                .transition(.opacity)
            } else if !authManager.isAuthenticated {
                // 未登录：显示认证页面
                AuthView()
                    .transition(.opacity)
            } else {
                // 已登录：显示主界面
                MainTabView()
                    .transition(.opacity)
            }
        }
        .id(languageManager.refreshID)  // 语言切换时刷新整个视图树
        .animation(.easeInOut(duration: 0.3), value: splashFinished)
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: hasCompletedOnboarding)
        .onAppear {
            // [测试用] 临时注释老用户检查，测试完恢复
            // if !hasCompletedOnboarding {
            //     let hasLanguagePref = UserDefaults.standard.string(forKey: "app_language_preference") != nil
            //     let hasExplorationCount = UserDefaults.standard.integer(forKey: "daily_exploration_count") > 0
            //     if hasLanguagePref || hasExplorationCount {
            //         hasCompletedOnboarding = true
            //     }
            // }
            // [测试用] 强制重置 onboarding 状态
            hasCompletedOnboarding = false
        }
    }
}

#Preview {
    RootView()
        .environmentObject(LanguageManager.shared)
}
