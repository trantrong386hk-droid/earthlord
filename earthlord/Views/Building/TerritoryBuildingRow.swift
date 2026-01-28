//
//  TerritoryBuildingRow.swift
//  earthlord
//
//  领地建筑行组件
//  显示建筑信息和操作菜单
//

import SwiftUI

/// 领地建筑行
struct TerritoryBuildingRow: View {

    let building: PlayerBuilding
    let template: BuildingTemplate?
    let onRename: () -> Void
    let onDemolish: () -> Void
    let onUpgrade: () -> Void

    @State private var showMenu = false

    var body: some View {
        // 如果建筑正在建造中或升级中，使用 TimelineView 自动刷新
        if building.status.isInProgress {
            TimelineView(.periodic(from: .now, by: 1.0)) { context in
                buildingRowContent
            }
        } else {
            buildingRowContent
        }
    }

    // MARK: - 建筑行内容

    private var buildingRowContent: some View {
        HStack(spacing: 12) {
            // 左侧图标
            buildingIcon

            // 中间信息
            VStack(alignment: .leading, spacing: 4) {
                // 名称和等级
                HStack(spacing: 6) {
                    Text(building.buildingName)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .lineLimit(1)

                    Text("Lv.\(building.level)")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.warning)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ApocalypseTheme.warning.opacity(0.15))
                        .cornerRadius(4)
                }

                // 状态或分类
                HStack(spacing: 8) {
                    // 分类
                    if let template = template {
                        Label(template.category.displayName, systemImage: template.category.icon)
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }

                    // 状态
                    statusView
                }
            }

            Spacer()

            // 右侧操作按钮
            Menu {
                if building.status == .active {
                    if let tmpl = template, building.level >= tmpl.maxLevel {
                        Button {} label: {
                            Label("已达最高等级", systemImage: "checkmark.circle.fill")
                        }
                        .disabled(true)
                    } else {
                        Button {
                            onUpgrade()
                        } label: {
                            Label("升级", systemImage: "arrow.up.circle")
                        }
                    }
                }

                if building.status == .upgrading {
                    Button {} label: {
                        Label("升级中...", systemImage: "clock")
                    }
                    .disabled(true)
                }

                Button {
                    onRename()
                } label: {
                    Label("重命名", systemImage: "pencil")
                }

                Divider()

                Button(role: .destructive) {
                    onDemolish()
                } label: {
                    Label("拆除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title2)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - 建筑图标

    private var buildingIcon: some View {
        ZStack {
            Circle()
                .fill(iconBackgroundColor.opacity(0.15))
                .frame(width: 50, height: 50)

            if building.status.isInProgress {
                // 建造中/升级中显示进度环
                Circle()
                    .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 3)
                    .frame(width: 50, height: 50)

                Circle()
                    .trim(from: 0, to: building.buildProgress)
                    .stroke(
                        building.status == .upgrading ? ApocalypseTheme.info : ApocalypseTheme.warning,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
            }

            Image(systemName: template?.icon ?? "building.2")
                .font(.title2)
                .foregroundColor(iconBackgroundColor)
        }
    }

    private var iconBackgroundColor: Color {
        switch building.status {
        case .constructing:
            return ApocalypseTheme.warning
        case .upgrading:
            return ApocalypseTheme.info
        case .active:
            return template?.category.color ?? ApocalypseTheme.primary
        }
    }

    // MARK: - 状态视图

    @ViewBuilder
    private var statusView: some View {
        switch building.status {
        case .constructing:
            HStack(spacing: 4) {
                Image(systemName: "hammer")
                    .font(.caption2)
                Text(building.formattedRemainingTime)
                    .font(.caption)
            }
            .foregroundColor(ApocalypseTheme.warning)

        case .upgrading:
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.circle")
                    .font(.caption2)
                Text("升级中 \(building.formattedRemainingTime)")
                    .font(.caption)
            }
            .foregroundColor(ApocalypseTheme.info)

        case .active:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                Text("运行中")
                    .font(.caption)
            }
            .foregroundColor(ApocalypseTheme.success)
        }
    }
}

#Preview {
    ZStack {
        ApocalypseTheme.background
            .ignoresSafeArea()

        VStack(spacing: 12) {
            TerritoryBuildingRow(
                building: PlayerBuilding(
                    id: UUID(),
                    userId: UUID(),
                    territoryId: "test",
                    templateId: "campfire",
                    buildingName: "篝火",
                    status: .active,
                    level: 2,
                    locationLat: nil,
                    locationLon: nil,
                    buildStartedAt: Date(),
                    buildCompletedAt: Date(),
                    createdAt: Date(),
                    updatedAt: nil
                ),
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
                onRename: {},
                onDemolish: {},
                onUpgrade: {}
            )

            TerritoryBuildingRow(
                building: PlayerBuilding(
                    id: UUID(),
                    userId: UUID(),
                    territoryId: "test",
                    templateId: "shelter",
                    buildingName: "我的小屋",
                    status: .constructing,
                    level: 1,
                    locationLat: nil,
                    locationLon: nil,
                    buildStartedAt: Date().addingTimeInterval(-30),
                    buildCompletedAt: Date().addingTimeInterval(30),
                    createdAt: Date(),
                    updatedAt: nil
                ),
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
                onRename: {},
                onDemolish: {},
                onUpgrade: {}
            )
        }
        .padding()
    }
}
