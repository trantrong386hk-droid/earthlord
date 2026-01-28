//
//  BuildingDetailView.swift
//  earthlord
//
//  建筑详情页
//  显示建筑模板详细信息和资源需求
//

import SwiftUI

struct BuildingDetailView: View {

    // MARK: - 属性

    let template: BuildingTemplate
    let territoryId: String
    let onStartConstruction: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var buildingManager = BuildingManager.shared
    @StateObject private var inventoryManager = InventoryManager.shared

    // MARK: - 计算属性

    /// 建造检查结果
    private var canBuildResult: BuildCheckResult {
        buildingManager.canBuild(template: template, territoryId: territoryId)
    }

    /// 玩家资源（资源名称 -> 数量）
    private var playerResources: [String: Int] {
        var resources: [String: Int] = [:]

        for item in inventoryManager.items {
            if !item.isAIGenerated {
                if let dbDef = inventoryManager.itemDefinitionsCache.values.first(where: { dbItem in
                    let nameMapping: [String: String] = [
                        "瓶装水": "water_bottle",
                        "矿泉水": "water_bottle",
                        "净化水": "water_purified",
                        "罐头食品": "canned_food",
                        "压缩饼干": "energy_bar",
                        "新鲜水果": "canned_food",
                        "急救包": "first_aid_kit",
                        "抗生素": "medicine",
                        "肾上腺素": "medicine",
                        "木材": "wood",
                        "金属板": "scrap_metal",
                        "电子元件": "electronic_parts",
                        "稀有矿石": "scrap_metal"
                    ]
                    let mappedId = nameMapping[dbItem.name] ?? "unknown"
                    return mappedId == item.definitionId
                }) {
                    resources[dbDef.name, default: 0] += item.quantity
                }
            }
        }

        return resources
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 建筑图标和基本信息
                        headerSection

                        // 描述
                        descriptionSection

                        // 属性信息
                        attributesSection

                        // 资源需求
                        resourcesSection

                        // 建造按钮
                        buildButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(template.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("返回") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
    }

    // MARK: - 头部区域

    private var headerSection: some View {
        VStack(spacing: 16) {
            // 图标
            ZStack {
                Circle()
                    .fill(template.category.color.opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: template.icon)
                    .font(.system(size: 44))
                    .foregroundColor(template.category.color)
            }

            // Tier 星级
            HStack(spacing: 4) {
                ForEach(0..<template.tier, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.subheadline)
                }
            }
            .foregroundColor(ApocalypseTheme.warning)

            // 分类标签
            Text(template.category.displayName)
                .font(.subheadline)
                .foregroundColor(template.category.color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(template.category.color.opacity(0.15))
                .cornerRadius(12)
        }
        .padding(.top, 20)
    }

    // MARK: - 描述区域

    private var descriptionSection: some View {
        ApocalypseCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(ApocalypseTheme.primary)
                    Text("建筑说明")
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Spacer()
                }

                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                Text(template.description)
                    .font(.body)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .lineSpacing(4)
            }
        }
    }

    // MARK: - 属性区域

    private var attributesSection: some View {
        ApocalypseCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(ApocalypseTheme.info)
                    Text("建筑属性")
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Spacer()
                }

                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                // 建造时间
                attributeRow(
                    icon: "clock",
                    title: "建造时间",
                    value: template.formattedBuildTime,
                    color: ApocalypseTheme.warning
                )

                // 最大等级
                attributeRow(
                    icon: "arrow.up.circle",
                    title: "最高等级",
                    value: "Lv.\(template.maxLevel)",
                    color: ApocalypseTheme.success
                )

                // 数量限制
                let existingCount = buildingManager.getBuildingCount(
                    templateId: template.templateId,
                    territoryId: territoryId
                )
                attributeRow(
                    icon: "number.circle",
                    title: "建造数量",
                    value: "\(existingCount)/\(template.maxPerTerritory)",
                    color: existingCount >= template.maxPerTerritory ? ApocalypseTheme.danger : ApocalypseTheme.info
                )
            }
        }
    }

    private func attributeRow(icon: String, title: String, value: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(color)
                .frame(width: 24)

            Text(title)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
    }

    // MARK: - 资源需求区域

    private var resourcesSection: some View {
        ApocalypseCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "cube.box")
                        .foregroundColor(ApocalypseTheme.primary)
                    Text("所需资源")
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Spacer()
                }

                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                ForEach(Array(template.requiredResources.keys.sorted()), id: \.self) { resourceName in
                    if let requiredAmount = template.requiredResources[resourceName] {
                        ResourceRow(
                            resourceName: resourceName,
                            requiredAmount: requiredAmount,
                            availableAmount: playerResources[resourceName] ?? 0
                        )
                    }
                }
            }
        }
    }

    // MARK: - 建造按钮

    private var buildButton: some View {
        VStack(spacing: 12) {
            Button {
                onStartConstruction()
            } label: {
                HStack {
                    Image(systemName: "hammer.fill")
                    Text("开始建造")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(canBuildResult.canBuild ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                )
            }
            .disabled(!canBuildResult.canBuild)

            // 错误提示
            if let error = canBuildResult.error {
                Text(error.errorDescription ?? "无法建造")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.danger)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 8)
    }
}

#Preview {
    BuildingDetailView(
        template: BuildingTemplate(
            id: UUID(),
            templateId: "campfire",
            name: "篝火",
            category: .survival,
            tier: 1,
            description: "最基础的生存设施，提供光源和温暖，可用于烹饪简单食物。",
            icon: "flame.fill",
            requiredResources: ["木材": 30, "石头": 20],
            buildTimeSeconds: 30,
            maxPerTerritory: 3,
            maxLevel: 3
        ),
        territoryId: "test-territory"
    ) {
        print("Start construction")
    }
}
