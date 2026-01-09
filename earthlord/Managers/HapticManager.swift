//
//  HapticManager.swift
//  earthlord
//
//  震动反馈管理器
//  单例模式管理所有震动反馈，避免生成器被提前释放导致崩溃
//

import UIKit

class HapticManager {

    // MARK: - 单例

    static let shared = HapticManager()

    // MARK: - 持久化的震动生成器

    /// 重度冲击生成器（用于 danger 级别）
    private let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)

    /// 中度冲击生成器（用于 warning 级别）
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)

    /// 通知反馈生成器（用于 caution 和 violation 级别）
    private let notificationGenerator = UINotificationFeedbackGenerator()

    // MARK: - 状态控制

    /// 是否正在播放震动序列（防止叠加）
    private var isPlaying = false

    // MARK: - 初始化

    private init() {
        // 预热生成器
        prepare()
    }

    // MARK: - 公开方法

    /// 根据预警级别触发震动反馈
    /// - Parameter level: 预警级别
    func playFeedback(for level: WarningLevel) {
        // 防止震动序列叠加
        guard !isPlaying else { return }

        switch level {
        case .safe:
            // 安全：无震动
            break

        case .caution:
            // 注意：轻震 1 次
            notificationGenerator.notificationOccurred(.warning)

        case .warning:
            // 警告：中震 2 次
            isPlaying = true
            mediumGenerator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.mediumGenerator.impactOccurred()
                self?.isPlaying = false
            }

        case .danger:
            // 危险：强震 3 次
            isPlaying = true
            heavyGenerator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.heavyGenerator.impactOccurred()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    self?.heavyGenerator.impactOccurred()
                    self?.isPlaying = false
                }
            }

        case .violation:
            // 违规：错误震动
            notificationGenerator.notificationOccurred(.error)
        }
    }

    /// 预热震动生成器（提高首次响应速度）
    func prepare() {
        heavyGenerator.prepare()
        mediumGenerator.prepare()
        notificationGenerator.prepare()
    }

    /// 停止当前震动序列
    func stop() {
        isPlaying = false
    }
}
