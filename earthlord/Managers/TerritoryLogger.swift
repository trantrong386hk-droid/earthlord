//
//  TerritoryLogger.swift
//  earthlord
//
//  圈地功能日志管理器
//  用于在 App 内显示调试日志，方便真机测试
//

import Foundation
import Combine

// MARK: - 日志类型

/// 日志类型枚举
enum LogType: String {
    case info = "INFO"
    case success = "SUCCESS"
    case warning = "WARNING"
    case error = "ERROR"
}

// MARK: - 日志条目

/// 单条日志记录
struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let type: LogType
}

// MARK: - 日志管理器

/// 圈地功能日志管理器（单例）
@MainActor
class TerritoryLogger: ObservableObject {

    // MARK: - 单例

    static let shared = TerritoryLogger()

    // MARK: - 发布属性

    /// 日志数组
    @Published var logs: [LogEntry] = []

    /// 格式化的日志文本（用于显示）
    @Published var logText: String = ""

    // MARK: - 私有属性

    /// 最大日志条数（防止内存溢出）
    private let maxLogCount = 200

    /// 时间格式化器（显示用）
    private let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    /// 时间格式化器（导出用）
    private let exportFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    // MARK: - 初始化

    private init() {
        // 私有初始化，确保只能通过 shared 访问
    }

    // MARK: - 公开方法

    /// 添加日志
    /// - Parameters:
    ///   - message: 日志消息
    ///   - type: 日志类型（默认 info）
    func log(_ message: String, type: LogType = .info) {
        let entry = LogEntry(
            timestamp: Date(),
            message: message,
            type: type
        )

        // 添加新日志
        logs.append(entry)

        // 限制日志数量，超出时移除最旧的
        if logs.count > maxLogCount {
            logs.removeFirst()
        }

        // 更新格式化文本
        updateLogText()

        // 同时打印到控制台（方便 Xcode 调试）
        let timeStr = displayFormatter.string(from: entry.timestamp)
        print("📋 [\(timeStr)] [\(type.rawValue)] \(message)")
    }

    /// 清空所有日志
    func clear() {
        logs.removeAll()
        logText = ""
        print("📋 [日志] 已清空")
    }

    /// 导出日志为文本
    /// - Returns: 包含头信息的完整日志文本
    func export() -> String {
        let exportTime = exportFormatter.string(from: Date())

        var text = """
        === 圈地功能测试日志 ===
        导出时间: \(exportTime)
        日志条数: \(logs.count)

        """

        for entry in logs {
            let timeStr = exportFormatter.string(from: entry.timestamp)
            text += "[\(timeStr)] [\(entry.type.rawValue)] \(entry.message)\n"
        }

        return text
    }

    // MARK: - 私有方法

    /// 更新格式化的日志文本
    private func updateLogText() {
        var text = ""
        for entry in logs {
            let timeStr = displayFormatter.string(from: entry.timestamp)
            text += "[\(timeStr)] [\(entry.type.rawValue)] \(entry.message)\n"
        }
        logText = text
    }
}
