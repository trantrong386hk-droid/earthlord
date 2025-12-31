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
    var body: some Scene {
        WindowGroup {
            RootView()
                .onOpenURL { url in
                    print("🔵 [App] 收到 URL 回调: \(url)")
                    // 处理 Google Sign-In 回调
                    AuthManager.shared.handleGoogleSignInURL(url)
                }
        }
    }
}
