//
//  SubscriptionBadge.swift
//  earthlord
//
//  订阅升级提示横幅组件
//  嵌入现有视图中，提示用户升级获取更多权益
//

import SwiftUI

struct SubscriptionBadge: View {
    /// 提示文字
    let text: String

    /// 图标
    var icon: String = "crown.fill"

    /// 点击回调
    var onTap: (() -> Void)?

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.primary)

                Text(text)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Text("升级")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(ApocalypseTheme.primary.opacity(0.1))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(ApocalypseTheme.primary.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - 即时建造按钮

struct InstantBuildButton: View {
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.caption)
                Text("即时完成")
                    .font(.caption.bold())
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: [ApocalypseTheme.warning, ApocalypseTheme.primary],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(8)
        }
    }
}

// MARK: - 探索奖励加成提示

struct ExplorationBonusBadge: View {
    let multiplier: Double

    var body: some View {
        if multiplier > 1.0 {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.caption2)
                Text("奖励 x\(String(format: "%.1f", multiplier))")
                    .font(.caption2.bold())
            }
            .foregroundColor(ApocalypseTheme.success)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(ApocalypseTheme.success.opacity(0.15))
            .cornerRadius(6)
        }
    }
}

// MARK: - 每日剩余次数指示器

struct DailyLimitIndicator: View {
    let remaining: Int
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            if remaining == -1 {
                Image(systemName: "infinity")
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.primary)
            } else if remaining == 0 {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.danger)
            } else {
                Image(systemName: "circle.fill")
                    .font(.system(size: 6))
                    .foregroundColor(remaining <= 1 ? ApocalypseTheme.warning : ApocalypseTheme.success)
            }

            Text(remaining == -1 ? "\(label): 无限" : "\(label): \(remaining)")
                .font(.caption2)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        SubscriptionBadge(text: "升级精英幸存者，背包扩容至 50kg")
        InstantBuildButton { }
        ExplorationBonusBadge(multiplier: 1.5)
        DailyLimitIndicator(remaining: 2, label: "探索")
        DailyLimitIndicator(remaining: 0, label: "圈地")
        DailyLimitIndicator(remaining: -1, label: "搜刮")
    }
    .padding()
    .background(ApocalypseTheme.background)
}
