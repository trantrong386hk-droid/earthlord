//
//  LanguageManager.swift
//  earthlord
//
//  EarthLord 语言管理器
//  负责 App 内语言切换，独立于系统语言设置
//

import Foundation
import SwiftUI
import Combine

// MARK: - 语言选项
/// App 支持的语言选项
enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"      // 跟随系统
    case zhHans = "zh-Hans"     // 简体中文
    case english = "en"         // English

    var id: String { rawValue }

    /// 显示名称（固定显示，不随语言切换变化）
    var displayName: String {
        switch self {
        case .system:
            return "跟随系统"
        case .zhHans:
            return "简体中文"
        case .english:
            return "English"
        }
    }

    /// 获取实际的语言代码
    var languageCode: String? {
        switch self {
        case .system:
            return nil
        case .zhHans:
            return "zh-Hans"
        case .english:
            return "en"
        }
    }
}

// MARK: - 自定义本地化 Bundle
/// 用于动态语言切换的 Bundle 管理
class LanguageBundle {
    static var current: Bundle = .main

    static func setLanguage(_ languageCode: String?) {
        let code: String
        if let lang = languageCode {
            code = lang
        } else {
            // 跟随系统
            let preferred = Locale.preferredLanguages.first ?? "zh-Hans"
            if preferred.hasPrefix("zh") {
                code = "zh-Hans"
            } else {
                code = "en"
            }
        }

        print("🌐 [LanguageBundle] 设置语言: \(code)")

        if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            print("🌐 [LanguageBundle] 使用 \(code).lproj")
            current = bundle
        } else {
            print("🌐 [LanguageBundle] 使用主 Bundle (源语言)")
            current = .main
        }
    }
}

// MARK: - 语言管理器
/// 管理 App 内语言切换
@MainActor
class LanguageManager: ObservableObject {

    // MARK: - 单例
    static let shared = LanguageManager()

    // MARK: - 常量
    private let userDefaultsKey = "app_language_preference"

    // MARK: - 发布属性

    /// 当前选择的语言
    @Published var currentLanguage: AppLanguage {
        didSet {
            saveLanguagePreference()
            applyLanguage()
        }
    }

    /// 语言变化触发器（用于强制刷新视图）
    @Published var refreshID: UUID = UUID()

    // MARK: - 初始化
    private init() {
        // 从 UserDefaults 读取保存的语言偏好
        if let savedLanguage = UserDefaults.standard.string(forKey: userDefaultsKey),
           let language = AppLanguage(rawValue: savedLanguage) {
            self.currentLanguage = language
        } else {
            self.currentLanguage = .system
        }

        // 应用语言设置
        applyLanguageSync()
    }

    // MARK: - 公开方法

    /// 设置语言
    func setLanguage(_ language: AppLanguage) {
        guard language != currentLanguage else { return }
        currentLanguage = language
    }

    /// 获取本地化字符串
    func localized(_ key: String) -> String {
        return LanguageBundle.current.localizedString(forKey: key, value: nil, table: nil)
    }

    // MARK: - 私有方法

    /// 保存语言偏好到 UserDefaults
    private func saveLanguagePreference() {
        UserDefaults.standard.set(currentLanguage.rawValue, forKey: userDefaultsKey)
    }

    /// 同步应用语言设置（初始化时使用）
    private func applyLanguageSync() {
        LanguageBundle.setLanguage(currentLanguage.languageCode)
    }

    /// 应用语言设置
    private func applyLanguage() {
        print("🌐 [语言管理器] 应用语言: \(currentLanguage.displayName)")
        LanguageBundle.setLanguage(currentLanguage.languageCode)
        // 触发视图刷新
        refreshID = UUID()
        print("🌐 [语言管理器] 刷新 ID: \(refreshID)")
    }
}

// MARK: - String 本地化扩展
extension String {
    /// 使用当前语言获取本地化字符串
    var localized: String {
        return LanguageBundle.current.localizedString(forKey: self, value: nil, table: nil)
    }

    /// 使用当前语言获取带参数的本地化字符串
    func localized(with arguments: CVarArg...) -> String {
        return String(format: self.localized, arguments: arguments)
    }
}

// MARK: - LocalizedText 视图
/// 自动响应语言切换的文本视图
struct LocalizedText: View {
    let key: String
    @ObservedObject private var languageManager = LanguageManager.shared

    init(_ key: String) {
        self.key = key
    }

    var body: some View {
        Text(key.localized)
            .id(languageManager.refreshID)
    }
}
