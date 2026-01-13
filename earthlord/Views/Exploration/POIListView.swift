//
//  POIListView.swift
//  earthlord
//
//  附近兴趣点列表页面
//  显示可探索的 POI 地点，支持分类筛选
//

import SwiftUI

struct POIListView: View {

    // MARK: - 状态

    /// 是否正在搜索
    @State private var isSearching: Bool = false

    /// 当前选中的筛选分类（nil 表示全部）
    @State private var selectedCategory: POIType? = nil

    /// POI 列表数据
    @State private var pois: [POI] = MockPOIData.pois

    /// 模拟 GPS 坐标（假数据）
    private let mockCoordinate = (lat: 22.5431, lon: 114.0579)

    // MARK: - 计算属性

    /// 根据筛选条件过滤后的 POI 列表
    private var filteredPOIs: [POI] {
        if let category = selectedCategory {
            return pois.filter { $0.type == category }
        }
        return pois
    }

    /// 已发现的 POI 数量
    private var discoveredCount: Int {
        pois.filter { $0.discoveryStatus != .undiscovered }.count
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 状态栏
                statusBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // 搜索按钮
                searchButton
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                // 筛选工具栏
                filterToolbar
                    .padding(.top, 16)

                // POI 列表
                poiList
                    .padding(.top, 12)
            }
        }
        .navigationTitle("附近地点")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 状态栏

    private var statusBar: some View {
        ApocalypseCard(padding: 12) {
            HStack {
                // GPS 坐标
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.success)

                    Text(String(format: "%.4f, %.4f", mockCoordinate.lat, mockCoordinate.lon))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                Spacer()

                // 发现数量
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.primary)

                    Text("附近发现 \(discoveredCount) 个地点")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
    }

    // MARK: - 搜索按钮

    private var searchButton: some View {
        Button {
            performSearch()
        } label: {
            HStack(spacing: 12) {
                if isSearching {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)

                    Text("搜索中...")
                        .font(.headline)
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.title3)
                        .foregroundColor(.white)

                    Text("搜索附近POI")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSearching ? ApocalypseTheme.textMuted : ApocalypseTheme.primary)
            )
            .shadow(color: ApocalypseTheme.primary.opacity(isSearching ? 0 : 0.4), radius: 8, y: 4)
        }
        .disabled(isSearching)
        .animation(.easeInOut(duration: 0.2), value: isSearching)
    }

    // MARK: - 筛选工具栏

    private var filterToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // 全部按钮
                FilterChip(
                    title: "全部",
                    icon: "square.grid.2x2.fill",
                    color: ApocalypseTheme.primary,
                    isSelected: selectedCategory == nil
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = nil
                    }
                }

                // 各分类按钮
                ForEach(filterCategories, id: \.type) { item in
                    FilterChip(
                        title: item.title,
                        icon: item.icon,
                        color: item.color,
                        isSelected: selectedCategory == item.type
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = item.type
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    /// 筛选分类配置
    private var filterCategories: [(type: POIType, title: String, icon: String, color: Color)] {
        [
            (.hospital, "医院", "cross.case.fill", .red),
            (.supermarket, "超市", "cart.fill", .green),
            (.factory, "工厂", "building.2.fill", .gray),
            (.pharmacy, "药店", "pills.fill", .purple),
            (.gasStation, "加油站", "fuelpump.fill", .orange)
        ]
    }

    // MARK: - POI 列表

    private var poiList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if filteredPOIs.isEmpty {
                    // 空状态
                    emptyStateView
                } else {
                    ForEach(filteredPOIs) { poi in
                        // 使用 NavigationLink 实现跳转到详情页
                        NavigationLink(destination: POIDetailView(poi: poi)) {
                            POIRowContent(poi: poi)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100) // 避开底部 Tab 栏
        }
    }

    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 48))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("未找到相关地点")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("尝试搜索附近或选择其他分类")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - 方法

    /// 执行搜索（模拟网络请求）
    private func performSearch() {
        isSearching = true

        // 模拟 1.5 秒网络请求
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isSearching = false
            // 这里可以刷新 POI 数据
            print("搜索完成，刷新 POI 列表")
        }
    }
}

// MARK: - 筛选按钮组件

private struct FilterChip: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : ApocalypseTheme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? color : ApocalypseTheme.cardBackground)
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected ? Color.clear : ApocalypseTheme.textMuted.opacity(0.3),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - POI 行内容组件（用于 NavigationLink）

private struct POIRowContent: View {
    let poi: POI

    /// POI 类型对应的颜色
    private var typeColor: Color {
        switch poi.type {
        case .hospital: return .red
        case .supermarket: return .green
        case .factory: return .gray
        case .pharmacy: return .purple
        case .gasStation: return .orange
        case .warehouse: return .brown
        case .house: return .cyan
        case .police: return .blue
        case .military: return .yellow
        }
    }

    /// POI 类型对应的图标
    private var typeIcon: String {
        switch poi.type {
        case .hospital: return "cross.case.fill"
        case .supermarket: return "cart.fill"
        case .factory: return "building.2.fill"
        case .pharmacy: return "pills.fill"
        case .gasStation: return "fuelpump.fill"
        case .warehouse: return "shippingbox.fill"
        case .house: return "house.fill"
        case .police: return "shield.lefthalf.filled"
        case .military: return "star.fill"
        }
    }

    /// 发现状态文字和颜色
    private var discoveryInfo: (text: String, color: Color) {
        switch poi.discoveryStatus {
        case .undiscovered:
            return ("未发现", ApocalypseTheme.textMuted)
        case .discovered:
            return ("已发现", ApocalypseTheme.info)
        case .explored:
            return ("已探索", ApocalypseTheme.success)
        }
    }

    /// 资源状态文字和颜色
    private var resourceInfo: (text: String, color: Color, icon: String) {
        switch poi.resourceStatus {
        case .unknown:
            return ("未知", ApocalypseTheme.textMuted, "questionmark.circle")
        case .hasResources:
            return ("有物资", ApocalypseTheme.success, "cube.box.fill")
        case .looted:
            return ("已搜空", ApocalypseTheme.danger, "xmark.circle")
        }
    }

    var body: some View {
        ApocalypseCard(padding: 14) {
            HStack(spacing: 14) {
                // 左侧：类型图标
                Image(systemName: typeIcon)
                    .font(.title2)
                    .foregroundColor(typeColor)
                    .frame(width: 48, height: 48)
                    .background(typeColor.opacity(0.15))
                    .cornerRadius(10)

                // 中间：名称和状态
                VStack(alignment: .leading, spacing: 6) {
                    // 名称
                    Text(poi.name)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    // 类型文字
                    Text(poi.type.displayName)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    // 状态标签
                    HStack(spacing: 8) {
                        // 发现状态
                        HStack(spacing: 4) {
                            Circle()
                                .fill(discoveryInfo.color)
                                .frame(width: 6, height: 6)
                            Text(discoveryInfo.text)
                                .font(.caption2)
                                .foregroundColor(discoveryInfo.color)
                        }

                        // 分隔线
                        Text("·")
                            .foregroundColor(ApocalypseTheme.textMuted)

                        // 资源状态
                        HStack(spacing: 4) {
                            Image(systemName: resourceInfo.icon)
                                .font(.caption2)
                                .foregroundColor(resourceInfo.color)
                            Text(resourceInfo.text)
                                .font(.caption2)
                                .foregroundColor(resourceInfo.color)
                        }
                    }
                }

                Spacer()

                // 右侧：危险等级和箭头
                VStack(alignment: .trailing, spacing: 8) {
                    // 危险等级
                    HStack(spacing: 2) {
                        ForEach(0..<5, id: \.self) { index in
                            Image(systemName: index < poi.dangerLevel ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
                                .font(.system(size: 8))
                                .foregroundColor(index < poi.dangerLevel ? dangerColor(level: poi.dangerLevel) : ApocalypseTheme.textMuted.opacity(0.3))
                        }
                    }

                    // 箭头
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
        }
    }

    /// 根据危险等级返回颜色
    private func dangerColor(level: Int) -> Color {
        switch level {
        case 1...2: return ApocalypseTheme.success
        case 3: return ApocalypseTheme.warning
        case 4...5: return ApocalypseTheme.danger
        default: return ApocalypseTheme.textMuted
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        POIListView()
    }
}
