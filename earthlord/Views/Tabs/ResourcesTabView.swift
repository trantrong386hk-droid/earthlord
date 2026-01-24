//
//  ResourcesTabView.swift
//  earthlord
//
//  资源模块主入口页面
//  包含 POI、背包、已购、领地、交易等子模块
//

import SwiftUI

/// 资源子模块类型
enum ResourceSegment: Int, CaseIterable {
    case poi = 0        // 兴趣点
    case backpack = 1   // 背包
    case purchased = 2  // 已购
    case territory = 3  // 领地
    case trade = 4      // 交易

    var title: String {
        switch self {
        case .poi: return "POI"
        case .backpack: return "背包"
        case .purchased: return "已购"
        case .territory: return "领地"
        case .trade: return "交易"
        }
    }
}

struct ResourcesTabView: View {

    // MARK: - 状态

    /// 当前选中的分段
    @State private var selectedSegment: ResourceSegment = .poi

    /// 交易开关状态（假数据）
    @State private var isTradingEnabled: Bool = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 分段选择器
                    segmentPicker
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    // 内容区域
                    contentArea
                }
            }
            .navigationTitle("资源")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // 交易开关
                    tradingToggle
                }
            }
        }
    }

    // MARK: - 分段选择器

    private var segmentPicker: some View {
        HStack(spacing: 0) {
            ForEach(ResourceSegment.allCases, id: \.self) { segment in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedSegment = segment
                    }
                } label: {
                    Text(segment.title)
                        .font(.subheadline)
                        .fontWeight(selectedSegment == segment ? .semibold : .regular)
                        .foregroundColor(selectedSegment == segment ? .white : ApocalypseTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedSegment == segment
                                ? ApocalypseTheme.primary
                                : Color.clear
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - 交易开关

    private var tradingToggle: some View {
        HStack(spacing: 8) {
            Text("交易")
                .font(.caption)
                .foregroundColor(isTradingEnabled ? ApocalypseTheme.success : ApocalypseTheme.textMuted)

            Toggle("", isOn: $isTradingEnabled)
                .toggleStyle(SwitchToggleStyle(tint: ApocalypseTheme.success))
                .labelsHidden()
                .scaleEffect(0.8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(ApocalypseTheme.cardBackground.opacity(0.8))
        .cornerRadius(8)
    }

    // MARK: - 内容区域

    @ViewBuilder
    private var contentArea: some View {
        switch selectedSegment {
        case .poi:
            // POI 列表
            POIContentView()

        case .backpack:
            // 背包
            BackpackContentView()

        case .purchased:
            // 已购（占位）
            placeholderView(
                icon: "bag.fill",
                title: "已购物品",
                subtitle: "功能开发中"
            )

        case .territory:
            // 领地资源（占位）
            placeholderView(
                icon: "building.2.fill",
                title: "领地资源",
                subtitle: "功能开发中"
            )

        case .trade:
            // 交易（占位）
            placeholderView(
                icon: "arrow.left.arrow.right",
                title: "资源交易",
                subtitle: "功能开发中"
            )
        }
    }

    // MARK: - 占位视图

    private func placeholderView(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)

            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - POI 内容视图（去掉导航标题）

private struct POIContentView: View {
    /// 是否正在搜索
    @State private var isSearching: Bool = false

    /// 当前选中的筛选分类
    @State private var selectedCategory: POIType? = nil

    /// POI 列表数据
    @State private var pois: [POI] = MockPOIData.pois

    /// 搜索按钮缩放效果
    @State private var searchButtonScale: CGFloat = 1.0

    /// 列表项是否已显示（用于入场动画）
    @State private var itemsAppeared: Bool = false

    /// 模拟 GPS 坐标
    private let mockCoordinate = (lat: 22.5431, lon: 114.0579)

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

    var body: some View {
        VStack(spacing: 0) {
            // 状态栏
            statusBar
                .padding(.horizontal, 16)
                .padding(.top, 12)

            // 搜索按钮
            searchButton
                .padding(.horizontal, 16)
                .padding(.top, 12)

            // 筛选工具栏
            filterToolbar
                .padding(.top, 12)

            // POI 列表
            poiList
                .padding(.top, 8)
        }
        .onAppear {
            // 延迟触发列表入场动画
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.3)) {
                    itemsAppeared = true
                }
            }
        }
    }

    private var statusBar: some View {
        ApocalypseCard(padding: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.success)

                    Text(String(format: "%.4f, %.4f", mockCoordinate.lat, mockCoordinate.lon))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                Spacer()

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

    private var searchButton: some View {
        Button {
            // 点击缩放动画
            withAnimation(.easeInOut(duration: 0.1)) {
                searchButtonScale = 0.95
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    searchButtonScale = 1.0
                }
            }
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
        .scaleEffect(searchButtonScale)
        .disabled(isSearching)
    }

    private var filterToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                FilterButton(
                    title: "全部",
                    icon: "square.grid.2x2.fill",
                    color: ApocalypseTheme.primary,
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }

                ForEach(filterCategories, id: \.type) { item in
                    FilterButton(
                        title: item.title,
                        icon: item.icon,
                        color: item.color,
                        isSelected: selectedCategory == item.type
                    ) {
                        selectedCategory = item.type
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var filterCategories: [(type: POIType, title: String, icon: String, color: Color)] {
        [
            (.hospital, "医院", "cross.case.fill", .red),
            (.supermarket, "超市", "cart.fill", .green),
            (.factory, "工厂", "building.2.fill", .gray),
            (.pharmacy, "药店", "pills.fill", .purple),
            (.gasStation, "加油站", "fuelpump.fill", .orange)
        ]
    }

    private var poiList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if filteredPOIs.isEmpty {
                    emptyView
                } else {
                    ForEach(Array(filteredPOIs.enumerated()), id: \.element.id) { index, poi in
                        NavigationLink(destination: POIDetailView(poi: poi)) {
                            POIRowCard(poi: poi)
                        }
                        .buttonStyle(.plain)
                        // 错开入场动画
                        .opacity(itemsAppeared ? 1 : 0)
                        .offset(y: itemsAppeared ? 0 : 20)
                        .animation(
                            .easeOut(duration: 0.3).delay(Double(index) * 0.08),
                            value: itemsAppeared
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
        // 切换分类时重置动画
        .onChange(of: selectedCategory) { _, _ in
            itemsAppeared = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.easeOut(duration: 0.3)) {
                    itemsAppeared = true
                }
            }
        }
    }

    /// 空状态视图 - 根据情况显示不同内容
    private var emptyView: some View {
        VStack(spacing: 16) {
            if pois.isEmpty {
                // 没有任何POI数据
                Image(systemName: "map")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.textMuted)

                Text("附近暂无兴趣点")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("点击搜索按钮发现周围的废墟")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textMuted)
            } else {
                // 筛选后没有结果
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.textMuted)

                Text("没有找到该类型的地点")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("尝试选择其他分类")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 80)
    }

    private func performSearch() {
        isSearching = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isSearching = false
        }
    }
}

// MARK: - 背包内容视图（去掉导航标题）

private struct BackpackContentView: View {
    /// 背包管理器（使用 ObservedObject 引用单例）
    @ObservedObject private var inventoryManager = InventoryManager.shared

    @State private var searchText: String = ""
    @State private var selectedCategory: ItemCategory? = nil

    /// 物品列表是否已显示（用于入场动画）
    @State private var itemsAppeared: Bool = false

    /// 动画用的容量百分比
    @State private var animatedCapacityPercentage: Double = 0

    /// 背包物品列表（从 InventoryManager 获取）
    private var items: [BackpackItem] {
        inventoryManager.items
    }

    /// 背包最大容量（物品数量）
    private let maxCapacity: Double = 100.0

    /// 当前物品数量
    private var currentCapacity: Double {
        Double(items.count)
    }

    private var capacityPercentage: Double {
        min(currentCapacity / maxCapacity, 1.0)
    }

    private var filteredItems: [BackpackItem] {
        var result = items

        // 使用 displayCategory 支持 AI 物品
        if let category = selectedCategory {
            result = result.filter { $0.displayCategory == category }
        }

        // 使用 displayName 支持 AI 物品
        if !searchText.isEmpty {
            result = result.filter { item in
                item.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    private var capacityColor: Color {
        if capacityPercentage > 0.9 {
            return ApocalypseTheme.danger
        } else if capacityPercentage > 0.7 {
            return ApocalypseTheme.warning
        } else {
            return ApocalypseTheme.success
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 容量卡片
            capacityCard
                .padding(.horizontal, 16)
                .padding(.top, 12)

            // 搜索框
            searchBar
                .padding(.horizontal, 16)
                .padding(.top, 12)

            // 分类筛选
            categoryFilter
                .padding(.top, 10)

            // 物品列表
            itemList
                .padding(.top, 8)
        }
        .task {
            // 加载背包数据
            await inventoryManager.loadInventory()
        }
        .onAppear {
            // 进度条动画
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeOut(duration: 0.6)) {
                    animatedCapacityPercentage = capacityPercentage
                }
            }
            // 列表入场动画
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.3)) {
                    itemsAppeared = true
                }
            }
        }
        // 监听物品变化时更新容量动画
        .onChange(of: inventoryManager.items.count) { _, _ in
            withAnimation(.easeOut(duration: 0.6)) {
                animatedCapacityPercentage = capacityPercentage
            }
        }
        // 切换分类时重置动画
        .onChange(of: selectedCategory) { _, _ in
            itemsAppeared = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.easeOut(duration: 0.3)) {
                    itemsAppeared = true
                }
            }
        }
    }

    private var capacityCard: some View {
        ApocalypseCard(padding: 14) {
            VStack(spacing: 10) {
                HStack {
                    Image(systemName: "bag.fill")
                        .font(.body)
                        .foregroundColor(ApocalypseTheme.primary)

                    Text("背包容量")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Spacer()

                    Text(String(format: "%.0f / %.0f", currentCapacity, maxCapacity))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(capacityColor)
                        .contentTransition(.numericText())
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(ApocalypseTheme.textMuted.opacity(0.3))

                        RoundedRectangle(cornerRadius: 5)
                            .fill(capacityColor)
                            .frame(width: geometry.size.width * animatedCapacityPercentage)
                            .animation(.easeOut(duration: 0.6), value: animatedCapacityPercentage)
                    }
                }
                .frame(height: 10)

                if capacityPercentage > 0.9 {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundColor(ApocalypseTheme.danger)
                        Text("背包快满了！")
                            .font(.caption2)
                            .foregroundColor(ApocalypseTheme.danger)
                        Spacer()
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(ApocalypseTheme.textMuted)

            TextField("搜索物品...", text: $searchText)
                .foregroundColor(ApocalypseTheme.textPrimary)

            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(10)
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                FilterButton(
                    title: "全部",
                    icon: "square.grid.2x2.fill",
                    color: ApocalypseTheme.primary,
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }

                ForEach(categoryOptions, id: \.category) { option in
                    FilterButton(
                        title: option.title,
                        icon: option.icon,
                        color: option.color,
                        isSelected: selectedCategory == option.category
                    ) {
                        selectedCategory = option.category
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var categoryOptions: [(category: ItemCategory, title: String, icon: String, color: Color)] {
        [
            (.food, "食物", "fork.knife", .orange),
            (.water, "水", "drop.fill", .cyan),
            (.material, "材料", "cube.fill", .brown),
            (.tool, "工具", "wrench.and.screwdriver.fill", .gray),
            (.medical, "医疗", "cross.case.fill", .red)
        ]
    }

    private var itemList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if inventoryManager.isLoading {
                    // 加载中
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                        Text("加载中...")
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else if filteredItems.isEmpty {
                    emptyStateView
                } else {
                    ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                        BackpackItemCard(item: item) { usedItem in
                            // 使用物品
                            Task {
                                try? await inventoryManager.useItem(itemId: usedItem.id)
                            }
                        }
                        // 错开入场动画
                        .opacity(itemsAppeared ? 1 : 0)
                        .offset(y: itemsAppeared ? 0 : 20)
                        .animation(
                            .easeOut(duration: 0.3).delay(Double(index) * 0.06),
                            value: itemsAppeared
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
    }

    /// 空状态视图 - 根据情况显示不同内容
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            if items.isEmpty {
                // 背包完全是空的
                Image(systemName: "bag")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.textMuted)

                Text("背包空空如也")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("去探索收集物资吧")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textMuted)
            } else if !searchText.isEmpty {
                // 搜索没有结果
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.textMuted)

                Text("没有找到相关物品")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("尝试其他关键词")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textMuted)
            } else {
                // 筛选后没有结果
                Image(systemName: "tray")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.textMuted)

                Text("该分类没有物品")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("尝试选择其他分类")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 80)
    }
}

// MARK: - 共用组件

private struct FilterButton: View {
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
                Capsule().fill(isSelected ? color : ApocalypseTheme.cardBackground)
            )
            .overlay(
                Capsule().strokeBorder(
                    isSelected ? Color.clear : ApocalypseTheme.textMuted.opacity(0.3),
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct POIRowCard: View {
    let poi: POI

    private var typeColor: Color {
        switch poi.type {
        case .hospital: return .red
        case .supermarket: return .green
        case .factory: return .gray
        case .pharmacy: return .purple
        case .gasStation: return .orange
        default: return .gray
        }
    }

    private var typeIcon: String {
        switch poi.type {
        case .hospital: return "cross.case.fill"
        case .supermarket: return "cart.fill"
        case .factory: return "building.2.fill"
        case .pharmacy: return "pills.fill"
        case .gasStation: return "fuelpump.fill"
        default: return "mappin.circle.fill"
        }
    }

    var body: some View {
        ApocalypseCard(padding: 14) {
            HStack(spacing: 14) {
                Image(systemName: typeIcon)
                    .font(.title2)
                    .foregroundColor(typeColor)
                    .frame(width: 48, height: 48)
                    .background(typeColor.opacity(0.15))
                    .cornerRadius(10)

                VStack(alignment: .leading, spacing: 4) {
                    Text(poi.name)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text(poi.type.displayName)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
    }
}

private struct BackpackItemCard: View {
    let item: BackpackItem
    var onUse: ((BackpackItem) -> Void)? = nil

    /// 分类颜色（支持 AI 物品）
    private var categoryColor: Color {
        if let category = item.displayCategory {
            switch category {
            case .water: return .cyan
            case .food: return .orange
            case .medical: return .red
            case .material: return .brown
            case .tool: return .gray
            case .weapon: return .purple
            case .misc: return .gray
            }
        }
        return .gray
    }

    /// 分类图标（支持 AI 物品）
    private var categoryIcon: String {
        if item.isAIGenerated {
            return aiCategoryIcon(item.aiCategory ?? "杂项")
        }
        return item.definition?.category.iconName ?? "questionmark.circle"
    }

    /// AI 分类图标映射
    private func aiCategoryIcon(_ category: String) -> String {
        switch category {
        case "医疗": return "cross.case.fill"
        case "食物": return "fork.knife"
        case "工具": return "wrench.and.screwdriver.fill"
        case "武器": return "bolt.fill"
        case "材料": return "cube.fill"
        default: return "shippingbox.fill"
        }
    }

    /// 稀有度颜色
    private var rarityColor: Color {
        switch item.displayRarity {
        case .common: return .gray
        case .uncommon: return .green
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        }
    }

    var body: some View {
        ApocalypseCard(padding: 12) {
            HStack(spacing: 12) {
                // 物品图标
                Image(systemName: categoryIcon)
                    .font(.title3)
                    .foregroundColor(categoryColor)
                    .frame(width: 40, height: 40)
                    .background(categoryColor.opacity(0.15))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    // 物品名称 + 标签
                    HStack(spacing: 6) {
                        Text(item.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        // 稀有度标签（非普通时显示）
                        if item.displayRarity != .common {
                            Text(item.displayRarity.displayName)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(rarityColor))
                        }

                        // AI 标签
                        if item.isAIGenerated {
                            Text("AI")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(ApocalypseTheme.primary)
                                .cornerRadius(4)
                        }
                    }

                    // 数量和重量
                    HStack(spacing: 8) {
                        Text("x\(item.quantity)")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        Text(String(format: "%.1fkg", item.totalWeight))
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }

                    // AI 故事（如果有）
                    if let story = item.aiStory, !story.isEmpty {
                        Text(story)
                            .font(.caption2)
                            .foregroundColor(ApocalypseTheme.textMuted)
                            .lineLimit(2)
                            .padding(.top, 2)
                    }
                }

                Spacer()

                Button {
                    onUse?(item)
                } label: {
                    Text("使用")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(ApocalypseTheme.primary))
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ResourcesTabView()
}
