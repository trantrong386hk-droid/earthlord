//
//  BuildingCard.swift
//  earthlord
//
//  建筑卡片组件
//  用于建筑浏览器中显示建筑模板
//

import SwiftUI

/// 建筑卡片
struct BuildingCard: View {

    let template: BuildingTemplate
    let existingCount: Int
    let onTap: () -> Void

    /// 是否已达上限
    private var isMaxReached: Bool {
        existingCount >= template.maxPerTerritory
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // 图标
                ZStack {
                    Circle()
                        .fill(template.category.color.opacity(0.15))
                        .frame(width: 60, height: 60)

                    Image(systemName: template.icon)
                        .font(.title)
                        .foregroundColor(isMaxReached ? ApocalypseTheme.textMuted : template.category.color)
                }

                // 名称
                Text(template.name)
                    .font(.headline)
                    .foregroundColor(isMaxReached ? ApocalypseTheme.textMuted : ApocalypseTheme.textPrimary)
                    .lineLimit(1)

                // Tier 标签
                HStack(spacing: 4) {
                    ForEach(0..<template.tier, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.caption2)
                    }
                }
                .foregroundColor(ApocalypseTheme.warning)

                // 建造时间
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(template.formattedBuildTime)
                        .font(.caption)
                }
                .foregroundColor(ApocalypseTheme.textSecondary)

                // 数量限制
                if template.maxPerTerritory > 0 {
                    Text("\(existingCount)/\(template.maxPerTerritory)")
                        .font(.caption2)
                        .foregroundColor(isMaxReached ? ApocalypseTheme.danger : ApocalypseTheme.textMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isMaxReached ? ApocalypseTheme.danger.opacity(0.15) : ApocalypseTheme.textMuted.opacity(0.15))
                        )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(ApocalypseTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isMaxReached ? ApocalypseTheme.textMuted.opacity(0.2) : ApocalypseTheme.primary.opacity(0.3),
                        lineWidth: 1
                    )
            )
            .opacity(isMaxReached ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isMaxReached)
    }
}

// MARK: - BuildingCategory 颜色扩展

extension BuildingCategory {
    var color: Color {
        switch self {
        case .survival:
            return ApocalypseTheme.primary
        case .storage:
            return ApocalypseTheme.info
        case .production:
            return ApocalypseTheme.success
        case .energy:
            return ApocalypseTheme.warning
        }
    }
}

#Preview {
    ZStack {
        ApocalypseTheme.background
            .ignoresSafeArea()

        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            BuildingCard(
                template: BuildingTemplate(
                    id: UUID(),
                    templateId: "campfire",
                    name: "篝火",
                    category: .survival,
                    tier: 1,
                    description: "提供光源和温暖",
                    icon: "flame.fill",
                    requiredResources: ["木材": 30],
                    buildTimeSeconds: 30,
                    maxPerTerritory: 3,
                    maxLevel: 3
                ),
                existingCount: 1
            ) {}

            BuildingCard(
                template: BuildingTemplate(
                    id: UUID(),
                    templateId: "shelter",
                    name: "庇护所",
                    category: .survival,
                    tier: 1,
                    description: "提供遮风挡雨",
                    icon: "house.fill",
                    requiredResources: ["木材": 50],
                    buildTimeSeconds: 60,
                    maxPerTerritory: 1,
                    maxLevel: 5
                ),
                existingCount: 1
            ) {}
        }
        .padding()
    }
}
