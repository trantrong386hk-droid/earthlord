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
        HStack(spacing: 12) {
            // 物品图标
            if let definition = item.definition {
                Image(systemName: definition.category.iconName)
                    .font(.title2)
                    .foregroundColor(rarityColor(definition.rarity))
                    .frame(width: 44, height: 44)
                    .background(rarityColor(definition.rarity).opacity(0.15))
                    .cornerRadius(10)
            }

            // 物品信息
            VStack(alignment: .leading, spacing: 4) {
                if let definition = item.definition {
                    Text(definition.name)
                        .font(.subheadline.bold())
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    HStack(spacing: 8) {
                        // 稀有度
                        Text(definition.rarity.displayName)
                            .font(.caption)
                            .foregroundColor(rarityColor(definition.rarity))

                        // 品质（如果有）
                        if let quality = item.quality {
                            Text("• \(quality.displayName)")
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textMuted)
                        }
                    }
                }
            }

            Spacer()

            // 数量
            Text("×\(item.quantity)")
                .font(.headline.bold().monospacedDigit())
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .padding(12)
        .background(ApocalypseTheme.background.opacity(0.5))
        .cornerRadius(12)
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
