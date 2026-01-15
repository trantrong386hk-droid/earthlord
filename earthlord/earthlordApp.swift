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

    /// 监听 App 生命周期状态
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // 确保语言设置在 App 启动时就应用
        _ = LanguageManager.shared

        // App 启动时开始位置上报
        print("🔵 [App] 初始化玩家位置上报...")
        Task { @MainActor in
            PlayerLocationManager.shared.startReporting()
        }
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
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    handleScenePhaseChange(from: oldPhase, to: newPhase)
                }
        }
    }

    // MARK: - 生命周期处理

    /// 处理 App 生命周期变化
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            // App 回到前台
            print("🔵 [App] 进入前台，恢复位置上报")
            Task { @MainActor in
                PlayerLocationManager.shared.startReporting()
            }

        case .inactive:
            // App 即将进入后台（过渡状态）
            break

        case .background:
            // App 进入后台
            print("🔵 [App] 进入后台，停止位置上报并标记离线")
            Task { @MainActor in
                PlayerLocationManager.shared.stopReporting()
                await PlayerLocationManager.shared.markOffline()
            }

        @unknown default:
            break
        }
    }
}
