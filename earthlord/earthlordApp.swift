//
//  earthlordApp.swift
//  earthlord
//
//  Created by lili on 2025/12/23.
//

import SwiftUI
import GoogleSignIn

@main
struct earthlordApp: App {
    /// 语言管理器 - 在 App 启动时初始化
    @StateObject private var languageManager = LanguageManager.shared

    init() {
        // 确保语言设置在 App 启动时就应用
        _ = LanguageManager.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(languageManager)
                .onOpenURL { url in
                    print("🔵 [App] 收到 URL 回调: \(url)")
                    // 处理 Google Sign-In 回调
                    AuthManager.shared.handleGoogleSignInURL(url)
                }
        }
    }
}
