//
//  ScavengeResultView.swift
//  earthlord
//
//  搜刮结果展示页面
//  展示从 POI 搜刮获得的物品
//

import SwiftUI

struct ScavengeResultView: View {

    // MARK: - 属性

    /// POI 信息
    let poi: POI

    /// 获得的物品
    let loot: [ExplorationLoot]

    /// 关闭弹窗
    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                // 背景
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // 顶部 POI 信息
                        poiHeader

                        // 获得物品列表
                        if loot.isEmpty {
                            emptyLootView
                        } else {
                            lootSection
                        }

                        Spacer(minLength: 40)

                        // 确认按钮
                        confirmButton
                    }
                    .padding(20)
                }
            }
            .navigationTitle("搜刮结果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: - POI 信息头部

    private var poiHeader: some View {
        VStack(spacing: 16) {
            // 图标
            ZStack {
                Circle()
                    .fill(Color(poi.type.markerColor).opacity(0.2))
                    .frame(width: 80, height: 80)

                Image(systemName: poi.type.iconName)
                    .font(.system(size: 36))
                    .foregroundColor(Color(poi.type.markerColor))
            }

            // 名称和类型
            VStack(spacing: 4) {
                Text(poi.name)
                    .font(.title2.bold())
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(poi.type.displayName)
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 搜刮完成提示
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(ApocalypseTheme.success)
                Text("搜刮完成")
                    .foregroundColor(ApocalypseTheme.success)
            }
            .font(.subheadline.bold())
        }
        .padding(.vertical, 16)
    }

    // MARK: - 物品列表

    private var lootSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "gift.fill")
                    .foregroundColor(ApocalypseTheme.primary)
                Text("获得物品")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Text("\(loot.count) 件")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 物品列表
            VStack(spacing: 12) {
                ForEach(loot) { item in
                    lootItemRow(item)
                }
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    /// 单个物品行
    private func lootItemRow(_ item: ExplorationLoot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // 物品图标
                itemIcon(for: item)

                // 物品信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.displayName)
                        .font(.subheadline.bold())
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    HStack(spacing: 8) {
                        // 稀有度
                        Text(item.displayRarity.displayName)
                            .font(.caption)
                            .foregroundColor(rarityColor(item.displayRarity))

                        // AI 标记
                        if item.isAIGenerated {
                            Text("AI")
                                .font(.caption2.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(ApocalypseTheme.primary)
                                .cornerRadius(4)
                        }

                        // 品质（如果有）
                        if let quality = item.quality {
                            Text("• \(quality.displayName)")
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textMuted)
                        }
                    }
                }

                Spacer()

                // 数量
                Text("×\(item.quantity)")
                    .font(.headline.bold().monospacedDigit())
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            // AI 故事（如果有）
            if let story = item.aiStory, !story.isEmpty {
                Text(story)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .padding(.top, 4)
                    .lineLimit(nil)
            }
        }
        .padding(12)
        .background(ApocalypseTheme.background.opacity(0.5))
        .cornerRadius(12)
    }

    /// 物品图标（支持 AI 物品）
    private func itemIcon(for item: ExplorationLoot) -> some View {
        let iconName: String
        let color: Color

        if item.isAIGenerated {
            iconName = categoryIcon(item.aiCategory ?? "杂项")
            color = rarityColor(item.displayRarity)
        } else if let definition = item.definition {
            iconName = definition.category.iconName
            color = rarityColor(definition.rarity)
        } else {
            iconName = "questionmark.circle"
            color = .gray
        }

        return Image(systemName: iconName)
            .font(.title2)
            .foregroundColor(color)
            .frame(width: 44, height: 44)
            .background(color.opacity(0.15))
            .cornerRadius(10)
    }

    /// AI 分类图标映射
    private func categoryIcon(_ category: String) -> String {
        switch category {
        case "医疗": return "cross.case.fill"
        case "食物": return "fork.knife"
        case "工具": return "wrench.and.screwdriver.fill"
        case "武器": return "bolt.fill"
        case "材料": return "cube.fill"
        default: return "shippingbox.fill"
        }
    }

    /// 稀有度颜色
    private func rarityColor(_ rarity: ItemRarity) -> Color {
        switch rarity {
        case .common: return .gray
        case .uncommon: return .green
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        }
    }

    // MARK: - 空物品视图

    private var emptyLootView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("这里已经被搜刮一空了...")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - 确认按钮

    private var confirmButton: some View {
        Button {
            dismiss()
        } label: {
            HStack {
                Image(systemName: "checkmark")
                Text("确认")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(ApocalypseTheme.primary)
            .cornerRadius(16)
        }
    }
}

// MARK: - Preview

#Preview {
    ScavengeResultView(
        poi: MockPOIData.pois[0],
        loot: MockExplorationResultData.currentLoot
    )
}
