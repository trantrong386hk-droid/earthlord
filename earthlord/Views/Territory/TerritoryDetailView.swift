//
//  TerritoryDetailView.swift
//  earthlord
//
//  领地详情页
//  显示领地信息、地图预览、删除功能和未来功能占位
//

import SwiftUI
import MapKit

struct TerritoryDetailView: View {

    // MARK: - 属性

    let territory: Territory
    var onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var territoryManager = TerritoryManager.shared

    /// 是否显示删除确认弹窗
    @State private var showDeleteAlert: Bool = false

    /// 是否正在删除
    @State private var isDeleting: Bool = false

    /// 删除错误信息
    @State private var deleteError: String?

    // MARK: - 地图相关

    /// 地图区域
    @State private var mapRegion: MKCoordinateRegion

    init(territory: Territory, onDelete: (() -> Void)? = nil) {
        self.territory = territory
        self.onDelete = onDelete

        // 初始化地图区域
        if let center = territory.centerCoordinate {
            _mapRegion = State(initialValue: MKCoordinateRegion(
                center: center,
                latitudinalMeters: 500,
                longitudinalMeters: 500
            ))
        } else {
            // 默认区域（如果没有边界框）
            let coords = territory.toCoordinates()
            if let first = coords.first {
                _mapRegion = State(initialValue: MKCoordinateRegion(
                    center: first,
                    latitudinalMeters: 500,
                    longitudinalMeters: 500
                ))
            } else {
                _mapRegion = State(initialValue: MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 23.0, longitude: 113.0),
                    latitudinalMeters: 1000,
                    longitudinalMeters: 1000
                ))
            }
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 地图预览
                        mapPreview

                        // 领地信息
                        territoryInfoCard

                        // 未来功能占位
                        futureFeaturesCard

                        // 危险操作区
                        dangerZoneCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(Text(territory.displayName))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭".localized) {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
            .alert("确认删除".localized, isPresented: $showDeleteAlert) {
                Button("取消".localized, role: .cancel) { }
                Button("删除".localized, role: .destructive) {
                    Task {
                        await deleteTerritory()
                    }
                }
            } message: {
                Text("删除后无法恢复，确定要删除这块领地吗？".localized)
            }
        }
    }

    // MARK: - 地图预览

    private var mapPreview: some View {
        ZStack {
            Map(coordinateRegion: $mapRegion, annotationItems: [territory]) { item in
                MapAnnotation(coordinate: item.centerCoordinate ?? CLLocationCoordinate2D()) {
                    Image(systemName: "flag.fill")
                        .font(.title2)
                        .foregroundColor(ApocalypseTheme.success)
                }
            }
            .frame(height: 200)
            .cornerRadius(16)
            .disabled(true)  // 禁止交互

            // 渐变遮罩
            VStack {
                Spacer()
                LinearGradient(
                    gradient: Gradient(colors: [Color.clear, ApocalypseTheme.cardBackground.opacity(0.8)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 60)
            }
            .cornerRadius(16)
        }
    }

    // MARK: - 领地信息卡片

    private var territoryInfoCard: some View {
        ApocalypseCard {
            VStack(spacing: 16) {
                // 标题
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(ApocalypseTheme.primary)
                    Text("领地信息".localized)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Spacer()
                }

                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                // 信息行
                infoRow(icon: "square.dashed", title: "面积".localized, value: territory.formattedArea)

                if let pointCount = territory.pointCount {
                    infoRow(icon: "mappin.circle", title: "坐标点".localized, value: "\(pointCount) 个")
                }

                infoRow(icon: "calendar", title: "创建时间".localized, value: territory.formattedCreatedAt)

                if let center = territory.centerCoordinate {
                    infoRow(
                        icon: "location",
                        title: "中心坐标".localized,
                        value: String(format: "%.4f, %.4f", center.latitude, center.longitude)
                    )
                }
            }
        }
    }

    // MARK: - 信息行组件

    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(width: 24)

            Text(title)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
    }

    // MARK: - 未来功能占位

    private var futureFeaturesCard: some View {
        ApocalypseCard {
            VStack(spacing: 16) {
                // 标题
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(ApocalypseTheme.warning)
                    Text("更多功能".localized)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Spacer()
                }

                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                // 功能占位
                futureFunctionRow(icon: "pencil", title: "重命名领地".localized)
                futureFunctionRow(icon: "building.2", title: "建筑系统".localized)
                futureFunctionRow(icon: "arrow.left.arrow.right", title: "领地交易".localized)
                futureFunctionRow(icon: "person.2", title: "领地联盟".localized)
            }
        }
    }

    // MARK: - 未来功能行组件

    private func futureFunctionRow(icon: String, title: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textMuted)
                .frame(width: 24)

            Text(title)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textMuted)

            Spacer()

            Text("敬请期待".localized)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.warning)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(ApocalypseTheme.warning.opacity(0.15))
                .cornerRadius(8)
        }
    }

    // MARK: - 危险操作区

    private var dangerZoneCard: some View {
        ApocalypseCard {
            VStack(spacing: 16) {
                // 标题
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(ApocalypseTheme.danger)
                    Text("危险操作".localized)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Spacer()
                }

                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                // 删除按钮
                Button {
                    showDeleteAlert = true
                } label: {
                    HStack {
                        if isDeleting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "trash.fill")
                        }
                        Text(isDeleting ? "删除中...".localized : "删除领地".localized)
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(ApocalypseTheme.danger)
                    .cornerRadius(12)
                }
                .disabled(isDeleting)

                // 错误提示
                if let error = deleteError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.danger)
                }

                // 提示文字
                Text("删除领地后将无法恢复，请谨慎操作".localized)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - 方法

    /// 删除领地
    private func deleteTerritory() async {
        isDeleting = true
        deleteError = nil

        do {
            try await territoryManager.deleteTerritory(id: territory.id)
            TerritoryLogger.shared.log("领地删除成功: \(territory.id)", type: .success)

            // 关闭详情页
            dismiss()

            // 回调刷新列表
            onDelete?()

        } catch {
            deleteError = error.localizedDescription
            TerritoryLogger.shared.log("领地删除失败: \(error.localizedDescription)", type: .error)
        }

        isDeleting = false
    }
}

#Preview {
    TerritoryDetailView(
        territory: Territory(
            id: UUID(),
            ownerId: UUID(),
            name: "测试领地",
            path: [["lat": 23.0, "lon": 113.0]],
            areaSqm: 1500,
            pointCount: 20,
            isActive: true,
            bboxMinLat: 22.9,
            bboxMaxLat: 23.1,
            bboxMinLon: 112.9,
            bboxMaxLon: 113.1,
            startedAt: nil,
            completedAt: nil,
            createdAt: Date(),
            updatedAt: nil
        )
    )
}
