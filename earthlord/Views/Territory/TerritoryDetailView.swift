//
//  TerritoryDetailView.swift
//  earthlord
//
//  领地详情页（全屏地图布局）
//  显示领地地图、建筑列表、悬浮工具栏
//

import SwiftUI
import MapKit

struct TerritoryDetailView: View {

    // MARK: - 属性

    let territory: Territory
    var onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var territoryManager = TerritoryManager.shared
    @StateObject private var buildingManager = BuildingManager.shared

    // MARK: - 状态

    /// 是否显示信息面板
    @State private var showInfoPanel: Bool = false

    /// 是否显示建筑浏览器
    @State private var showBuildingBrowser: Bool = false

    /// 选中的模板（用于建造确认页）
    @State private var selectedTemplateForConstruction: BuildingTemplate?

    /// 是否显示删除确认
    @State private var showDeleteAlert: Bool = false

    /// 是否正在删除
    @State private var isDeleting: Bool = false

    /// 删除错误信息
    @State private var deleteError: String?

    /// 是否显示重命名弹窗
    @State private var showRenameAlert: Bool = false

    /// 新名称输入
    @State private var newTerritoryName: String = ""

    /// 选中的建筑（用于操作）
    @State private var selectedBuilding: PlayerBuilding?

    /// 是否显示建筑重命名弹窗
    @State private var showBuildingRenameAlert: Bool = false

    /// 新建筑名称
    @State private var newBuildingName: String = ""

    /// 是否显示拆除确认
    @State private var showDemolishAlert: Bool = false

    /// 选中的建筑（用于升级确认页）
    @State private var selectedBuildingForUpgrade: PlayerBuilding?

    /// 刷新触发器（用于强制更新建造进度）
    @State private var refreshTrigger: Int = 0

    /// 建造进度刷新定时器
    @State private var progressTimer: Timer?

    // MARK: - 计算属性

    /// 领地内的建筑（使用 refreshTrigger 强制刷新）
    private var buildings: [PlayerBuilding] {
        _ = refreshTrigger // 触发依赖
        return buildingManager.getBuildings(for: territory.id.uuidString)
    }

    /// 当前领地名称（可能已更新）
    private var currentTerritoryName: String {
        territoryManager.myTerritories.first(where: { $0.id == territory.id })?.displayName ?? territory.displayName
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 1. 全屏地图（底层）
            TerritoryMapView(
                territory: territory,
                buildings: buildings,
                showsUserLocation: true,
                onBuildingTap: { building in
                    selectedBuilding = building
                }
            )
            .ignoresSafeArea()

            // 2. 悬浮工具栏（顶部）
            VStack {
                TerritoryToolbarView(
                    territoryName: currentTerritoryName,
                    buildingCount: buildings.count,
                    onBack: { dismiss() },
                    onRename: {
                        newTerritoryName = territory.name ?? ""
                        showRenameAlert = true
                    },
                    onBuild: { showBuildingBrowser = true },
                    onToggleInfo: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showInfoPanel.toggle()
                        }
                    }
                )
                .padding(.top, 8)

                Spacer()
            }

            // 3. 可折叠信息面板（底部）
            VStack {
                Spacer()

                if showInfoPanel {
                    infoPanelView
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            // 加载领地内的建筑
            Task {
                await buildingManager.fetchPlayerBuildings(territoryId: territory.id.uuidString)
            }
            // 启动建造进度刷新定时器
            startProgressTimer()
        }
        .onDisappear {
            // 停止定时器
            stopProgressTimer()
        }
        // Sheet: 建筑浏览器
        .sheet(isPresented: $showBuildingBrowser) {
            BuildingBrowserView(
                territoryId: territory.id.uuidString
            ) { template in
                // 关闭浏览器后延迟打开建造确认页
                showBuildingBrowser = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    selectedTemplateForConstruction = template
                }
            }
        }
        // Sheet: 建造确认页
        .sheet(item: $selectedTemplateForConstruction) { template in
            BuildingPlacementView(
                template: template,
                territory: territory
            ) {
                // 建造成功后刷新并展开信息面板
                Task {
                    await buildingManager.fetchPlayerBuildings(territoryId: territory.id.uuidString)
                }
                // 自动展开信息面板显示建造进度
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showInfoPanel = true
                }
                // 启动进度刷新定时器
                startProgressTimer()
            }
        }
        // Alert: 删除确认
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                Task { await deleteTerritory() }
            }
        } message: {
            Text("删除后无法恢复，确定要删除这块领地吗？")
        }
        // Alert: 重命名领地
        .alert("重命名领地", isPresented: $showRenameAlert) {
            TextField("领地名称", text: $newTerritoryName)
            Button("取消", role: .cancel) { }
            Button("确定") {
                Task { await renameTerritory() }
            }
        } message: {
            Text("请输入新的领地名称")
        }
        // Alert: 重命名建筑
        .alert("重命名建筑", isPresented: $showBuildingRenameAlert) {
            TextField("建筑名称", text: $newBuildingName)
            Button("取消", role: .cancel) { }
            Button("确定") {
                Task { await renameBuilding() }
            }
        } message: {
            Text("请输入新的建筑名称")
        }
        // Alert: 拆除建筑确认
        .alert("确认拆除", isPresented: $showDemolishAlert) {
            Button("取消", role: .cancel) { }
            Button("拆除", role: .destructive) {
                Task { await demolishBuilding() }
            }
        } message: {
            Text("拆除后建筑将被永久删除，确定要拆除吗？")
        }
        // Sheet: 升级确认页
        .sheet(item: $selectedBuildingForUpgrade) { building in
            BuildingUpgradeView(building: building) {
                // 升级开始后刷新并展开信息面板
                Task {
                    await buildingManager.fetchPlayerBuildings(territoryId: territory.id.uuidString)
                }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showInfoPanel = true
                }
                startProgressTimer()
            }
        }
    }

    // MARK: - 信息面板

    private var infoPanelView: some View {
        VStack(spacing: 0) {
            // 拖动指示条
            RoundedRectangle(cornerRadius: 3)
                .fill(ApocalypseTheme.textMuted)
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 16) {
                    // 领地信息卡片
                    territoryInfoSection

                    // 建筑列表
                    buildingListSection

                    // 危险操作
                    dangerZoneSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .frame(maxHeight: UIScreen.main.bounds.height * 0.6)
        .background(
            ApocalypseTheme.cardBackground
                .cornerRadius(20, corners: [.topLeft, .topRight])
        )
    }

    // MARK: - 领地信息区域

    private var territoryInfoSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(ApocalypseTheme.primary)
                Text("领地信息")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Spacer()
            }

            HStack(spacing: 16) {
                // 面积
                VStack(spacing: 4) {
                    Text(territory.formattedArea)
                        .font(.title3.bold())
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Text("面积")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(ApocalypseTheme.textMuted.opacity(0.3))
                    .frame(width: 1, height: 40)

                // 建筑数
                VStack(spacing: 4) {
                    Text("\(buildings.count)")
                        .font(.title3.bold())
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Text("建筑")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(ApocalypseTheme.textMuted.opacity(0.3))
                    .frame(width: 1, height: 40)

                // 坐标点
                VStack(spacing: 4) {
                    Text("\(territory.pointCount ?? 0)")
                        .font(.title3.bold())
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Text("坐标点")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 12)
            .background(ApocalypseTheme.background)
            .cornerRadius(12)
        }
    }

    // MARK: - 建筑列表区域

    private var buildingListSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "building.2.fill")
                    .foregroundColor(ApocalypseTheme.success)
                Text("建筑列表")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Spacer()

                Button {
                    showBuildingBrowser = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("建造")
                    }
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }

            if buildings.isEmpty {
                // 空状态
                VStack(spacing: 12) {
                    Image(systemName: "hammer")
                        .font(.largeTitle)
                        .foregroundColor(ApocalypseTheme.textMuted)

                    Text("暂无建筑")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textMuted)

                    Button {
                        showBuildingBrowser = true
                    } label: {
                        Text("开始建造")
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.primary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(ApocalypseTheme.background)
                .cornerRadius(12)
            } else {
                // 建筑列表
                ForEach(buildings, id: \.id) { building in
                    TerritoryBuildingRow(
                        building: building,
                        template: buildingManager.getTemplate(for: building.templateId),
                        onRename: {
                            selectedBuilding = building
                            newBuildingName = building.buildingName
                            showBuildingRenameAlert = true
                        },
                        onDemolish: {
                            selectedBuilding = building
                            showDemolishAlert = true
                        },
                        onUpgrade: {
                            selectedBuildingForUpgrade = building
                        }
                    )
                }
            }
        }
    }

    // MARK: - 危险操作区域

    private var dangerZoneSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(ApocalypseTheme.danger)
                Text("危险操作")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Spacer()
            }

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
                    Text(isDeleting ? "删除中..." : "删除领地")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(ApocalypseTheme.danger)
                .cornerRadius(12)
            }
            .disabled(isDeleting)

            if let error = deleteError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.danger)
            }

            Text("删除领地后将无法恢复，请谨慎操作")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - 方法

    /// 删除领地
    private func deleteTerritory() async {
        isDeleting = true
        deleteError = nil

        do {
            try await territoryManager.deleteTerritory(id: territory.id)
            dismiss()
            onDelete?()
        } catch {
            deleteError = error.localizedDescription
        }

        isDeleting = false
    }

    /// 重命名领地
    private func renameTerritory() async {
        guard !newTerritoryName.isEmpty else { return }

        do {
            try await territoryManager.renameTerritory(id: territory.id, newName: newTerritoryName)
        } catch {
            print("重命名领地失败: \(error)")
        }
    }

    /// 重命名建筑
    private func renameBuilding() async {
        guard let building = selectedBuilding, !newBuildingName.isEmpty else { return }

        do {
            try await buildingManager.renameBuilding(buildingId: building.id, newName: newBuildingName)
        } catch {
            print("重命名建筑失败: \(error)")
        }

        selectedBuilding = nil
    }

    /// 拆除建筑
    private func demolishBuilding() async {
        guard let building = selectedBuilding else { return }

        do {
            try await buildingManager.demolishBuilding(buildingId: building.id)
        } catch {
            print("拆除建筑失败: \(error)")
        }

        selectedBuilding = nil
    }

    // MARK: - 定时器管理

    /// 启动建造/升级进度刷新定时器
    private func startProgressTimer() {
        stopProgressTimer()

        // 每秒刷新一次
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            // 检查是否有进行中的建筑（建造或升级）
            let inProgressBuildings = buildings.filter { $0.status.isInProgress }

            if inProgressBuildings.isEmpty {
                // 没有进行中的建筑，停止定时器
                stopProgressTimer()
                return
            }

            // 触发视图刷新
            refreshTrigger += 1

            // 检查是否有建筑完成
            for building in inProgressBuildings {
                if let completedAt = building.buildCompletedAt, Date() >= completedAt {
                    Task {
                        if building.status == .constructing {
                            await buildingManager.completeConstruction(buildingId: building.id)
                        } else if building.status == .upgrading {
                            await buildingManager.completeUpgrade(buildingId: building.id, newLevel: building.level + 1)
                        }
                    }
                }
            }
        }
    }

    /// 停止定时器
    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
}

#Preview {
    TerritoryDetailView(
        territory: Territory(
            id: UUID(),
            ownerId: UUID(),
            name: "测试领地",
            path: [
                ["lat": 23.0, "lon": 113.0],
                ["lat": 23.002, "lon": 113.0],
                ["lat": 23.002, "lon": 113.002],
                ["lat": 23.0, "lon": 113.002]
            ],
            areaSqm: 40000,
            pointCount: 4,
            isActive: true,
            bboxMinLat: 23.0,
            bboxMaxLat: 23.002,
            bboxMinLon: 113.0,
            bboxMaxLon: 113.002,
            startedAt: nil,
            completedAt: nil,
            createdAt: Date(),
            updatedAt: nil
        )
    )
}
