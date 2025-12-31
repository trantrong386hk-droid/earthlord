import SwiftUI

/// 根视图：控制启动页、认证页与主界面的切换
struct RootView: View {
    /// 认证管理器
    @StateObject private var authManager = AuthManager.shared

    /// 语言管理器
    @EnvironmentObject var languageManager: LanguageManager

    /// 启动页是否完成
    @State private var splashFinished = false

    var body: some View {
        ZStack {
            if !splashFinished {
                // 启动页
                SplashView(isFinished: $splashFinished)
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
    }
}

#Preview {
    RootView()
        .environmentObject(LanguageManager.shared)
}
