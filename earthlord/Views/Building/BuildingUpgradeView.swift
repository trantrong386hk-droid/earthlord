//
//  BuildingUpgradeView.swift
//  earthlord
//
//  建筑升级确认页
//  显示升级信息、所需资源和确认按钮
//

import SwiftUI

struct BuildingUpgradeView: View {

    // MARK: - 属性

    let building: PlayerBuilding
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var buildingManager = BuildingManager.shared

    // MARK: - 状态

    @State private var isUpgrading: Bool = false
    @State private var errorMessage: String?

    // MARK: - 计算属性

    private var template: BuildingTemplate? {
        buildingManager.getTemplate(for: building.templateId)
    }

    private var upgradeResources: [String: Int] {
        guard let template = template else { return [:] }
        return buildingManager.getUpgradeResources(template: template, currentLevel: building.level)
    }

    private var upgradeTimeSeconds: Int {
        guard let template = template else { return 0 }
        return buildingManager.getUpgradeTimeSeconds(template: template, currentLevel: building.level)
    }

    private var formattedUpgradeTime: String {
        let seconds = upgradeTimeSeconds
        if seconds < 60 {
            return "\(seconds)秒"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            let secs = seconds % 60
            return secs > 0 ? "\(minutes)分\(secs)秒" : "\(minutes)分钟"
        } else {
            let hours = seconds / 3600
            let minutes = (seconds % 3600) / 60
            return minutes > 0 ? "\(hours)小时\(minutes)分" : "\(hours)小时"
        }
    }

    private var playerResources: [String: Int] {
        buildingManager.getPlayerResources()
    }

    private var canPerformUpgrade: Bool {
        buildingManager.canUpgrade(building: building).canBuild
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 建筑信息
                        buildingInfoSection

                        // 升级等级
                        upgradeLevelSection

                        // 所需资源
                        requiredResourcesSection

                        // 错误信息
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.danger)
                                .multilineTextAlignment(.center)
                        }

                        // 确认升级按钮
                        confirmButton
                    }
                    .padding(20)
                }
            }
            .navigationTitle("升级建筑")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
    }

    // MARK: - 建筑信息

    private var buildingInfoSection: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill((template?.category.color ?? ApocalypseTheme.primary).opacity(0.15))
                    .frame(width: 60, height: 60)

                Image(systemName: template?.icon ?? "building.2")
                    .font(.title)
                    .foregroundColor(template?.category.color ?? ApocalypseTheme.primary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(building.buildingName)
                    .font(.title3.bold())
                    .foregroundColor(ApocalypseTheme.textPrimary)

                if let template = template {
                    Label(template.category.displayName, systemImage: template.category.icon)
                        .font(.subheadline)
                        .foregroundColor(template.category.color)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 升级等级信息

    private var upgradeLevelSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundColor(ApocalypseTheme.info)
                Text("升级信息")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Spacer()
            }

            HStack(spacing: 20) {
                // 当前等级
                VStack(spacing: 4) {
                    Text("Lv.\(building.level)")
                        .font(.title2.bold())
                        .foregroundColor(ApocalypseTheme.warning)
                    Text("当前等级")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)

                // 箭头
                Image(systemName: "arrow.right")
                    .font(.title2)
                    .foregroundColor(ApocalypseTheme.info)

                // 目标等级
                VStack(spacing: 4) {
                    Text("Lv.\(building.level + 1)")
                        .font(.title2.bold())
                        .foregroundColor(ApocalypseTheme.info)
                    Text("目标等级")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 12)

            // 升级时间
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(ApocalypseTheme.textSecondary)
                Text("升级时间")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                Spacer()
                Text(formattedUpgradeTime)
                    .font(.subheadline.bold())
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }
            .padding(12)
            .background(ApocalypseTheme.background)
            .cornerRadius(8)
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 所需资源

    private var requiredResourcesSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "shippingbox.fill")
                    .foregroundColor(ApocalypseTheme.warning)
                Text("所需资源")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Spacer()
            }

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            ForEach(Array(upgradeResources.keys.sorted()), id: \.self) { resourceName in
                ResourceRow(
                    resourceName: resourceName,
                    requiredAmount: upgradeResources[resourceName] ?? 0,
                    availableAmount: playerResources[resourceName] ?? 0
                )
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 确认按钮

    private var confirmButton: some View {
        Button {
            Task {
                await startUpgrade()
            }
        } label: {
            HStack {
                if isUpgrading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                }
                Text(isUpgrading ? "升级中..." : "确认升级")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(canPerformUpgrade && !isUpgrading ? ApocalypseTheme.info : ApocalypseTheme.textMuted)
            )
        }
        .disabled(!canPerformUpgrade || isUpgrading)
    }

    // MARK: - 升级方法

    private func startUpgrade() async {
        isUpgrading = true
        errorMessage = nil

        do {
            try await buildingManager.upgradeBuilding(buildingId: building.id)
            dismiss()
            onConfirm()
        } catch {
            errorMessage = error.localizedDescription
        }

        isUpgrading = false
    }
}

#Preview {
    BuildingUpgradeView(
        building: PlayerBuilding(
            id: UUID(),
            userId: UUID(),
            territoryId: "test",
            templateId: "campfire",
            buildingName: "篝火",
            status: .active,
            level: 1,
            locationLat: nil,
            locationLon: nil,
            buildStartedAt: Date(),
            buildCompletedAt: Date(),
            createdAt: Date(),
            updatedAt: nil
        )
    ) {
        print("Upgrade confirmed")
    }
}
