//
//  BuildingPlacementView.swift
//  earthlord
//
//  建造确认页
//  选择建筑位置并确认建造
//

import SwiftUI
import MapKit
import CoreLocation

struct BuildingPlacementView: View {

    // MARK: - 属性

    let template: BuildingTemplate
    let territory: Territory
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var buildingManager = BuildingManager.shared

    /// 选中的坐标
    @State private var selectedCoordinate: CLLocationCoordinate2D?

    /// 是否正在建造
    @State private var isBuilding: Bool = false

    /// 错误信息
    @State private var errorMessage: String?

    /// 自定义建筑名称
    @State private var customName: String = ""

    // MARK: - 计算属性

    /// 领地坐标数组
    private var territoryCoordinates: [CLLocationCoordinate2D] {
        territory.toCoordinates()
    }

    /// 领地内的现有建筑
    private var existingBuildings: [PlayerBuilding] {
        buildingManager.getBuildings(for: territory.id.uuidString)
    }

    /// 实际使用的建筑名称
    private var buildingName: String {
        customName.isEmpty ? template.name : customName
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 地图选点
                    BuildingLocationPickerView(
                        territoryCoordinates: territoryCoordinates,
                        existingBuildings: existingBuildings,
                        selectedCoordinate: $selectedCoordinate
                    )
                    .frame(height: UIScreen.main.bounds.height * 0.45)

                    // 信息面板
                    infoPanel
                }
            }
            .navigationTitle("选择位置")
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

    // MARK: - 信息面板

    private var infoPanel: some View {
        VStack(spacing: 16) {
            // 建筑信息
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(template.category.color.opacity(0.15))
                        .frame(width: 50, height: 50)

                    Image(systemName: template.icon)
                        .font(.title2)
                        .foregroundColor(template.category.color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    HStack(spacing: 8) {
                        Label(template.formattedBuildTime, systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        Label(template.category.displayName, systemImage: template.category.icon)
                            .font(.caption)
                            .foregroundColor(template.category.color)
                    }
                }

                Spacer()
            }

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 自定义名称输入
            VStack(alignment: .leading, spacing: 8) {
                Text("建筑名称（可选）")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                TextField("默认: \(template.name)", text: $customName)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(ApocalypseTheme.background)
                    .cornerRadius(8)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            // 位置状态
            HStack {
                Image(systemName: selectedCoordinate != nil ? "checkmark.circle.fill" : "mappin.slash")
                    .foregroundColor(selectedCoordinate != nil ? ApocalypseTheme.success : ApocalypseTheme.textMuted)

                Text(selectedCoordinate != nil ? "已选择位置" : "点击地图选择位置")
                    .font(.subheadline)
                    .foregroundColor(selectedCoordinate != nil ? ApocalypseTheme.textPrimary : ApocalypseTheme.textMuted)

                Spacer()

                if let coord = selectedCoordinate {
                    Text(String(format: "%.4f, %.4f", coord.latitude, coord.longitude))
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
            .padding(12)
            .background(ApocalypseTheme.background)
            .cornerRadius(8)

            // 错误信息
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.danger)
                    .multilineTextAlignment(.center)
            }

            // 确认建造按钮
            Button {
                Task {
                    await startConstruction()
                }
            } label: {
                HStack {
                    if isBuilding {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "hammer.fill")
                    }
                    Text(isBuilding ? "建造中..." : "确认建造")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(selectedCoordinate != nil && !isBuilding ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                )
            }
            .disabled(selectedCoordinate == nil || isBuilding)
        }
        .padding(20)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(20, corners: [.topLeft, .topRight])
    }

    // MARK: - 建造方法

    private func startConstruction() async {
        guard let location = selectedCoordinate else { return }

        isBuilding = true
        errorMessage = nil

        do {
            _ = try await buildingManager.startConstruction(
                templateId: template.templateId,
                territoryId: territory.id.uuidString,
                location: (lat: location.latitude, lon: location.longitude)
            )

            // 建造成功，关闭页面
            dismiss()
            onConfirm()

        } catch {
            errorMessage = error.localizedDescription
        }

        isBuilding = false
    }
}

// MARK: - 圆角扩展

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    BuildingPlacementView(
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
        territory: Territory(
            id: UUID(),
            ownerId: UUID(),
            name: "测试领地",
            path: [
                ["lat": 23.0, "lon": 113.0],
                ["lat": 23.001, "lon": 113.0],
                ["lat": 23.001, "lon": 113.001],
                ["lat": 23.0, "lon": 113.001]
            ],
            areaSqm: 1500,
            pointCount: 4,
            isActive: true,
            bboxMinLat: 23.0,
            bboxMaxLat: 23.001,
            bboxMinLon: 113.0,
            bboxMaxLon: 113.001,
            startedAt: nil,
            completedAt: nil,
            createdAt: Date(),
            updatedAt: nil
        )
    ) {
        print("Confirmed")
    }
}
