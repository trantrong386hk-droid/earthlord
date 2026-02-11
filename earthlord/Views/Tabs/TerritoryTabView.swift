//
//  TerritoryTabView.swift
//  earthlord
//
//  领地管理页面
//  显示用户领地列表、统计信息，支持查看详情和删除
//

import SwiftUI

struct TerritoryTabView: View {

    // MARK: - 属性

    @ObservedObject private var languageManager = LanguageManager.shared
    @StateObject private var territoryManager = TerritoryManager.shared
    @StateObject private var buildingManager = BuildingManager.shared

    /// 选中的领地（用于显示详情页）
    @State private var selectedTerritory: Territory?

    /// 是否正在加载
    @State private var isLoading: Bool = false

    /// 错误信息
    @State private var errorMessage: String?

    /// 刷新触发器
    @State private var refreshTrigger: UUID = UUID()

    // MARK: - 计算属性

    /// 总面积
    private var totalArea: Double {
        territoryManager.myTerritories.reduce(0) { $0 + $1.areaSqm }
    }

    /// 格式化总面积
    private var formattedTotalArea: String {
        if totalArea >= 1_000_000 {
            return String(format: "%.2f km²", totalArea / 1_000_000)
        } else if totalArea >= 10_000 {
            return String(format: "%.2f 公顷", totalArea / 10_000)
        } else {
            return String(format: "%.0f m²", totalArea)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                if isLoading && territoryManager.myTerritories.isEmpty {
                    // 首次加载中
                    loadingView
                } else if territoryManager.myTerritories.isEmpty {
                    // 空状态
                    emptyStateView
                } else {
                    // 领地列表
                    territoryListView
                }
            }
            .navigationTitle(Text("我的领地".localized))
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .refreshable {
                await loadMyTerritories()
            }
        }
        .sheet(item: $selectedTerritory) { territory in
            TerritoryDetailView(
                territory: territory,
                onDelete: {
                    // 删除后刷新列表
                    Task {
                        await loadMyTerritories()
                    }
                }
            )
        }
        .onAppear {
            Task {
                await loadMyTerritories()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .territoryUpdated)) { _ in
            // 领地更新时刷新列表
            Task {
                await loadMyTerritories()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .territoryDeleted)) { _ in
            // 领地删除时刷新列表
            Task {
                await loadMyTerritories()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .buildingUpdated)) { _ in
            // 建筑更新时刷新（用于更新建筑数量显示）
            refreshTrigger = UUID()
        }
        .id(languageManager.refreshID)
    }

    // MARK: - 领地列表视图

    private var territoryListView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 统计卡片
                statisticsCard

                // 领地列表标题
                HStack {
                    Text("领地列表".localized)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Spacer()

                    Text("\(territoryManager.myTerritories.count) 块")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                .padding(.horizontal, 4)

                // 领地卡片列表
                ForEach(territoryManager.myTerritories) { territory in
                    TerritoryCard(territory: territory)
                        .onTapGesture {
                            selectedTerritory = territory
                        }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
    }

    // MARK: - 统计卡片

    private var statisticsCard: some View {
        ApocalypseCard {
            HStack(spacing: 0) {
                // 领地数量
                VStack(spacing: 8) {
                    Image(systemName: "flag.fill")
                        .font(.title2)
                        .foregroundColor(ApocalypseTheme.primary)

                    Text("\(territoryManager.myTerritories.count)")
                        .font(.title.bold())
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text("领地数量".localized)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)

                // 分隔线
                Rectangle()
                    .fill(ApocalypseTheme.textMuted.opacity(0.3))
                    .frame(width: 1, height: 60)

                // 总面积
                VStack(spacing: 8) {
                    Image(systemName: "map.fill")
                        .font(.title2)
                        .foregroundColor(ApocalypseTheme.success)

                    Text(formattedTotalArea)
                        .font(.title3.bold())
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text("总面积".localized)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - 加载中视图

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                .scaleEffect(1.2)

            Text("加载中...".localized)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    // MARK: - 空状态视图

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "map")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("暂无领地".localized)
                .font(.title2.bold())
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("去地图页面圈占你的第一块领地吧！".localized)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.danger)
                    .padding(.top, 8)
            }
        }
    }

    // MARK: - 方法

    /// 加载我的领地
    private func loadMyTerritories() async {
        isLoading = true
        errorMessage = nil

        do {
            try await territoryManager.loadMyTerritories()
        } catch {
            errorMessage = error.localizedDescription
            TerritoryLogger.shared.log("加载我的领地失败: \(error.localizedDescription)", type: .error)
        }

        isLoading = false
    }
}

// MARK: - 领地卡片组件

struct TerritoryCard: View {

    let territory: Territory

    var body: some View {
        ApocalypseCard {
            HStack(spacing: 16) {
                // 领地图标
                ZStack {
                    Circle()
                        .fill(ApocalypseTheme.success.opacity(0.15))
                        .frame(width: 50, height: 50)

                    Image(systemName: "flag.fill")
                        .font(.title2)
                        .foregroundColor(ApocalypseTheme.success)
                }

                // 领地信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(territory.displayName)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 12) {
                        // 面积
                        Label(territory.formattedArea, systemImage: "square.dashed")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        // 点数
                        if let pointCount = territory.pointCount {
                            Label("\(pointCount) 点", systemImage: "mappin.circle")
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }
                    }

                    // 创建时间
                    Text(territory.formattedCreatedAt)
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }

                Spacer()

                // 箭头
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
    }
}

#Preview {
    TerritoryTabView()
}
