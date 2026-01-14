//
//  ExplorationResultView.swift
//  earthlord
//
//  探索结果展示页面
//  以 Sheet 形式弹出，显示探索收获和统计数据
//

import SwiftUI

struct ExplorationResultView: View {

    // MARK: - 属性

    /// 探索结果数据（可选，失败时为 nil）
    let result: ExplorationResult?

    /// 累计统计数据（可选，失败时为 nil）
    let stats: ExplorationStats?

    /// 错误信息（可选，成功时为 nil）
    var errorMessage: String? = nil

    /// 重试回调
    var onRetry: (() -> Void)? = nil

    /// 关闭页面
    @Environment(\.dismiss) private var dismiss

    /// 动画状态
    @State private var showContent: Bool = false
    @State private var showStats: Bool = false
    @State private var showItems: Bool = false
    @State private var showCheckmarks: Bool = false

    /// 数字动画进度（0~1）
    @State private var numberAnimationProgress: Double = 0

    /// 是否发生错误
    private var hasError: Bool {
        errorMessage != nil
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景
            ApocalypseTheme.background
                .ignoresSafeArea()

            if hasError {
                // 错误状态
                errorStateView
            } else if let result = result, let stats = stats {
                // 成功状态
                successContentView(result: result, stats: stats)
            }
        }
        .onAppear {
            // 只有成功时才执行入场动画
            guard !hasError else {
                withAnimation(.easeOut(duration: 0.5)) {
                    showContent = true
                }
                return
            }

            // 延迟动画，增加仪式感
            withAnimation(.easeOut(duration: 0.5)) {
                showContent = true
            }
            // 统计数字动画
            withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
                showStats = true
            }
            // 数字跳动效果
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                numberAnimationProgress = 1.0
            }
            // 奖励物品动画
            withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
                showItems = true
            }
            // 对勾弹跳动画（延迟到物品全部出现后）
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5, blendDuration: 0)) {
                    showCheckmarks = true
                }
            }
        }
    }

    // MARK: - 错误状态视图

    private var errorStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            // 错误图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.danger.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.danger)
            }
            .scaleEffect(showContent ? 1.0 : 0.5)
            .opacity(showContent ? 1.0 : 0)

            // 错误标题
            Text("探索失败")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .opacity(showContent ? 1.0 : 0)
                .offset(y: showContent ? 0 : 20)

            // 错误信息
            Text(errorMessage ?? "未知错误")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .opacity(showContent ? 1.0 : 0)
                .offset(y: showContent ? 0 : 20)

            Spacer()

            // 操作按钮
            VStack(spacing: 12) {
                // 重试按钮
                if let onRetry = onRetry {
                    Button {
                        onRetry()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.clockwise")
                                .font(.headline)

                            Text("重新探索")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .cornerRadius(12)
                        )
                        .shadow(color: ApocalypseTheme.primary.opacity(0.4), radius: 8, y: 4)
                    }
                }

                // 关闭按钮
                Button {
                    dismiss()
                } label: {
                    Text("返回")
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(ApocalypseTheme.cardBackground)
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
            .opacity(showContent ? 1.0 : 0)
            .offset(y: showContent ? 0 : 20)
        }
    }

    // MARK: - 成功状态内容

    private func successContentView(result: ExplorationResult, stats: ExplorationStats) -> some View {
        // 根据行走距离计算奖励等级
        let tier = RewardTier.from(distance: result.distanceWalked)

        return ScrollView {
            VStack(spacing: 24) {
                // 成就标题（带等级徽章）
                achievementHeader(tier: tier)
                    .padding(.top, 30)

                // 统计数据卡片
                statsSection(result: result, stats: stats)
                    .padding(.horizontal, 16)

                // 奖励物品卡片
                rewardsSection(result: result)
                    .padding(.horizontal, 16)

                // 确认按钮
                confirmButton
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
            }
        }
    }

    // MARK: - 成就标题

    private func achievementHeader(tier: RewardTier) -> some View {
        VStack(spacing: 16) {
            // 大图标（带动画）- 根据等级显示不同徽章
            ZStack {
                // 光晕效果
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [tier.badgeColor.opacity(0.3), Color.clear],
                            center: .center,
                            startRadius: 30,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .scaleEffect(showContent ? 1.0 : 0.5)
                    .opacity(showContent ? 1.0 : 0)

                // 外圈
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: tier.badgeGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 100, height: 100)
                    .scaleEffect(showContent ? 1.0 : 0.3)

                // 徽章图标
                Image(systemName: tier.badgeIcon)
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: tier.badgeGradient,
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .scaleEffect(showContent ? 1.0 : 0.3)
            }

            // 等级标签
            if tier != .none {
                Text(tier.displayName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: tier.badgeGradient,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .scaleEffect(showContent ? 1.0 : 0.5)
                    .opacity(showContent ? 1.0 : 0)
            }

            // 标题文字
            VStack(spacing: 8) {
                Text("探索完成！")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(tier == .none ? "距离不足，未获得奖励" : "你发现了新的物资")
                    .font(.subheadline)
                    .foregroundColor(tier == .none ? ApocalypseTheme.textMuted : ApocalypseTheme.textSecondary)
            }
            .opacity(showContent ? 1.0 : 0)
            .offset(y: showContent ? 0 : 20)
        }
    }

    // MARK: - 统计数据区域

    private func statsSection(result: ExplorationResult, stats: ExplorationStats) -> some View {
        VStack(spacing: 12) {
            // 行走距离
            StatRow(
                icon: "figure.walk",
                iconColor: .cyan,
                title: "行走距离",
                current: result.formattedDistance,
                total: stats.formattedTotalDistance,
                animationProgress: numberAnimationProgress
            )
            .opacity(showStats ? 1 : 0)
            .offset(y: showStats ? 0 : 15)
            .animation(.easeOut(duration: 0.3).delay(0), value: showStats)

            // 探索时长（单独样式）
            ApocalypseCard(padding: 14) {
                HStack {
                    // 图标
                    Image(systemName: "clock.fill")
                        .font(.title3)
                        .foregroundColor(.orange)
                        .frame(width: 36, height: 36)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(8)

                    // 标题
                    Text("探索时长")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Spacer()

                    // 时长
                    Text(result.formattedDuration)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .scaleEffect(showStats ? 1.0 : 0.5)
                        .opacity(showStats ? 1.0 : 0)
                }
            }
            .opacity(showStats ? 1 : 0)
            .offset(y: showStats ? 0 : 15)
            .animation(.easeOut(duration: 0.3).delay(0.2), value: showStats)
        }
        .opacity(showContent ? 1.0 : 0)
        .offset(y: showContent ? 0 : 30)
    }

    // MARK: - 奖励物品区域

    private func rewardsSection(result: ExplorationResult) -> some View {
        ApocalypseCard(padding: 16, showBorder: true) {
            VStack(spacing: 14) {
                // 标题
                HStack {
                    Image(systemName: "gift.fill")
                        .font(.title3)
                        .foregroundColor(ApocalypseTheme.primary)

                    Text("获得物品")
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Spacer()

                    Text("\(result.loot.count) 件")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }

                // 分隔线
                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                // 物品列表
                VStack(spacing: 10) {
                    ForEach(Array(result.loot.enumerated()), id: \.element.id) { index, loot in
                        if let definition = loot.definition {
                            RewardItemRow(
                                icon: definition.category.iconName,
                                iconColor: categoryColor(definition.category),
                                name: definition.name,
                                quantity: loot.quantity,
                                rarity: definition.rarity,
                                showCheckmark: showCheckmarks
                            )
                            .opacity(showItems ? 1.0 : 0)
                            .offset(x: showItems ? 0 : -20)
                            .animation(
                                .easeOut(duration: 0.3).delay(Double(index) * 0.2),
                                value: showItems
                            )
                        }
                    }
                }

                // 底部提示
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.success)
                        .scaleEffect(showCheckmarks ? 1.0 : 0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.5), value: showCheckmarks)

                    Text("已添加到背包")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.success)
                }
                .padding(.top, 4)
                .opacity(showItems ? 1.0 : 0)
            }
        }
        .opacity(showContent ? 1.0 : 0)
        .offset(y: showContent ? 0 : 30)
    }

    /// 分类对应的颜色
    private func categoryColor(_ category: ItemCategory) -> Color {
        switch category {
        case .water: return .cyan
        case .food: return .orange
        case .medical: return .red
        case .material: return .brown
        case .tool: return .gray
        case .weapon: return .purple
        case .misc: return .gray
        }
    }

    // MARK: - 确认按钮

    private var confirmButton: some View {
        Button {
            dismiss()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "checkmark")
                    .font(.headline)

                Text("收下物资")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .cornerRadius(14)
            )
            .shadow(color: ApocalypseTheme.primary.opacity(0.4), radius: 10, y: 5)
        }
        .opacity(showItems ? 1.0 : 0)
        .scaleEffect(showItems ? 1.0 : 0.9)
    }
}

// MARK: - 统计行组件

private struct StatRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let current: String
    let total: String
    var animationProgress: Double = 1.0

    var body: some View {
        ApocalypseCard(padding: 14) {
            HStack(spacing: 12) {
                // 图标
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(iconColor)
                    .frame(width: 36, height: 36)
                    .background(iconColor.opacity(0.15))
                    .cornerRadius(8)

                // 标题和数据
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)

                    HStack(spacing: 8) {
                        // 本次
                        Text(current)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                            .scaleEffect(animationProgress > 0.5 ? 1.0 : 0.8)
                            .opacity(animationProgress > 0 ? 1.0 : 0)

                        // 分隔符
                        Text("/")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textMuted)

                        // 累计
                        Text("累计 \(total)")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }

                Spacer()
            }
        }
    }
}

// MARK: - 奖励物品行组件

private struct RewardItemRow: View {
    let icon: String
    let iconColor: Color
    let name: String
    let quantity: Int
    let rarity: ItemRarity
    var showCheckmark: Bool = true

    /// 稀有度颜色
    private var rarityColor: Color {
        switch rarity {
        case .common: return .gray
        case .uncommon: return .green
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(iconColor)
                .frame(width: 32, height: 32)
                .background(iconColor.opacity(0.15))
                .clipShape(Circle())

            // 物品名称
            Text(name)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 稀有度标签（非普通时显示）
            if rarity != .common {
                Text(rarity.displayName)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(rarityColor))
            }

            Spacer()

            // 数量
            Text("x\(quantity)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(ApocalypseTheme.primary)

            // 对勾（带弹跳动画）
            Image(systemName: "checkmark.circle.fill")
                .font(.body)
                .foregroundColor(ApocalypseTheme.success)
                .scaleEffect(showCheckmark ? 1.0 : 0)
                .animation(.spring(response: 0.4, dampingFraction: 0.5), value: showCheckmark)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview("成功") {
    ExplorationResultView(
        result: MockExplorationResultData.currentResult,
        stats: MockExplorationResultData.stats
    )
}

#Preview("失败") {
    ExplorationResultView(
        result: nil,
        stats: nil,
        errorMessage: "网络连接失败，请检查网络设置后重试",
        onRetry: {
            print("重试探索")
        }
    )
}
