//
//  BackpackView.swift
//  earthlord
//
//  背包管理页面
//  显示玩家携带的物品，支持搜索、筛选、使用和存储
//

import SwiftUI

struct BackpackView: View {

    // MARK: - 状态

    /// 搜索文本
    @State private var searchText: String = ""

    /// 当前选中的筛选分类（nil 表示全部）
    @State private var selectedCategory: ItemCategory? = nil

    /// 背包物品列表
    @State private var items: [BackpackItem] = MockBackpackData.items

    // MARK: - 常量

    /// 背包最大容量
    private let maxCapacity: Double = 100.0

    /// 当前使用容量（模拟数据）
    private var currentCapacity: Double {
        items.reduce(0) { $0 + $1.totalWeight }
    }

    /// 容量使用百分比
    private var capacityPercentage: Double {
        min(currentCapacity / maxCapacity, 1.0)
    }

    // MARK: - 计算属性

    /// 根据搜索和筛选条件过滤后的物品列表
    private var filteredItems: [BackpackItem] {
        var result = items

        // 按分类筛选
        if let category = selectedCategory {
            result = result.filter { $0.definition?.category == category }
        }

        // 按搜索文本筛选
        if !searchText.isEmpty {
            result = result.filter { item in
                item.definition?.name.localizedCaseInsensitiveContains(searchText) ?? false
            }
        }

        return result
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 容量状态卡
                capacityCard
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // 搜索框
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                // 分类筛选
                categoryFilter
                    .padding(.top, 12)

                // 物品列表
                itemList
                    .padding(.top, 12)
            }
        }
        .navigationTitle("背包")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 容量状态卡

    private var capacityCard: some View {
        ApocalypseCard(padding: 16) {
            VStack(spacing: 12) {
                // 标题行
                HStack {
                    Image(systemName: "bag.fill")
                        .font(.title3)
                        .foregroundColor(ApocalypseTheme.primary)

                    Text("背包容量")
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Spacer()

                    // 容量数值
                    Text(String(format: "%.0f / %.0f", currentCapacity, maxCapacity))
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(capacityColor)
                }

                // 进度条
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // 背景
                        RoundedRectangle(cornerRadius: 6)
                            .fill(ApocalypseTheme.textMuted.opacity(0.3))

                        // 填充
                        RoundedRectangle(cornerRadius: 6)
                            .fill(capacityColor)
                            .frame(width: geometry.size.width * capacityPercentage)
                    }
                }
                .frame(height: 12)

                // 警告文字（超过90%时显示）
                if capacityPercentage > 0.9 {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.danger)

                        Text("背包快满了！")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(ApocalypseTheme.danger)

                        Spacer()
                    }
                }
            }
        }
    }

    /// 容量进度条颜色
    private var capacityColor: Color {
        if capacityPercentage > 0.9 {
            return ApocalypseTheme.danger
        } else if capacityPercentage > 0.7 {
            return ApocalypseTheme.warning
        } else {
            return ApocalypseTheme.success
        }
    }

    // MARK: - 搜索框

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.body)
                .foregroundColor(ApocalypseTheme.textMuted)

            TextField("搜索物品...", text: $searchText)
                .font(.body)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .autocorrectionDisabled()

            // 清除按钮
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(ApocalypseTheme.textMuted.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - 分类筛选

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // 全部按钮
                CategoryChip(
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
                ForEach(categoryOptions, id: \.category) { option in
                    CategoryChip(
                        title: option.title,
                        icon: option.icon,
                        color: option.color,
                        isSelected: selectedCategory == option.category
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = option.category
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    /// 分类选项配置
    private var categoryOptions: [(category: ItemCategory, title: String, icon: String, color: Color)] {
        [
            (.food, "食物", "fork.knife", .orange),
            (.water, "水", "drop.fill", .cyan),
            (.material, "材料", "cube.fill", .brown),
            (.tool, "工具", "wrench.and.screwdriver.fill", .gray),
            (.medical, "医疗", "cross.case.fill", .red)
        ]
    }

    // MARK: - 物品列表

    private var itemList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if filteredItems.isEmpty {
                    // 空状态
                    emptyStateView
                } else {
                    ForEach(filteredItems) { item in
                        BackpackItemRow(item: item) { action in
                            handleItemAction(item: item, action: action)
                        }
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
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("没有找到物品")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            if !searchText.isEmpty || selectedCategory != nil {
                Text("尝试清除搜索条件或选择其他分类")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
            } else {
                Text("去探索废墟收集物资吧")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - 方法

    /// 处理物品操作
    private func handleItemAction(item: BackpackItem, action: ItemAction) {
        switch action {
        case .use:
            print("使用物品: \(item.definition?.name ?? "未知") x\(item.quantity)")
        case .store:
            print("存储物品: \(item.definition?.name ?? "未知") x\(item.quantity)")
        }
    }
}

// MARK: - 物品操作类型

private enum ItemAction {
    case use
    case store
}

// MARK: - 分类按钮组件

private struct CategoryChip: View {
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

// MARK: - 物品行组件

private struct BackpackItemRow: View {
    let item: BackpackItem
    let onAction: (ItemAction) -> Void

    /// 获取物品定义
    private var definition: ItemDefinition? {
        item.definition
    }

    /// 分类图标
    private var categoryIcon: String {
        definition?.category.iconName ?? "questionmark.circle"
    }

    /// 分类颜色
    private var categoryColor: Color {
        switch definition?.category {
        case .water: return .cyan
        case .food: return .orange
        case .medical: return .red
        case .material: return .brown
        case .tool: return .gray
        case .weapon: return .purple
        case .misc: return .gray
        case .none: return .gray
        }
    }

    /// 稀有度颜色
    private var rarityColor: Color {
        switch definition?.rarity {
        case .common: return .gray
        case .uncommon: return .green
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        case .none: return .gray
        }
    }

    var body: some View {
        ApocalypseCard(padding: 12) {
            HStack(spacing: 12) {
                // 左侧：圆形图标
                Image(systemName: categoryIcon)
                    .font(.title3)
                    .foregroundColor(categoryColor)
                    .frame(width: 44, height: 44)
                    .background(categoryColor.opacity(0.15))
                    .clipShape(Circle())

                // 中间：物品信息
                VStack(alignment: .leading, spacing: 6) {
                    // 第一行：名称 + 稀有度标签
                    HStack(spacing: 8) {
                        Text(definition?.name ?? "未知物品")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        // 稀有度标签
                        if let rarity = definition?.rarity, rarity != .common {
                            Text(rarity.displayName)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule().fill(rarityColor)
                                )
                        }
                    }

                    // 第二行：数量、重量、品质
                    HStack(spacing: 12) {
                        // 数量
                        HStack(spacing: 3) {
                            Image(systemName: "number")
                                .font(.system(size: 10))
                            Text("x\(item.quantity)")
                                .font(.caption)
                        }
                        .foregroundColor(ApocalypseTheme.textSecondary)

                        // 重量
                        HStack(spacing: 3) {
                            Image(systemName: "scalemass")
                                .font(.system(size: 10))
                            Text(String(format: "%.1fkg", item.totalWeight))
                                .font(.caption)
                        }
                        .foregroundColor(ApocalypseTheme.textSecondary)

                        // 品质（如果有）
                        if let quality = item.quality {
                            HStack(spacing: 3) {
                                Image(systemName: qualityIcon(quality))
                                    .font(.system(size: 10))
                                Text(quality.displayName)
                                    .font(.caption)
                            }
                            .foregroundColor(qualityColor(quality))
                        }
                    }
                }

                Spacer()

                // 右侧：操作按钮
                VStack(spacing: 6) {
                    // 使用按钮
                    Button {
                        onAction(.use)
                    } label: {
                        Text("使用")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(ApocalypseTheme.primary)
                            )
                    }

                    // 存储按钮
                    Button {
                        onAction(.store)
                    } label: {
                        Text("存储")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .strokeBorder(ApocalypseTheme.textMuted.opacity(0.5), lineWidth: 1)
                            )
                    }
                }
            }
        }
    }

    /// 品质图标
    private func qualityIcon(_ quality: ItemQuality) -> String {
        switch quality {
        case .damaged: return "exclamationmark.triangle"
        case .worn: return "minus.circle"
        case .normal: return "checkmark.circle"
        case .pristine: return "star.circle"
        }
    }

    /// 品质颜色
    private func qualityColor(_ quality: ItemQuality) -> Color {
        switch quality {
        case .damaged: return ApocalypseTheme.danger
        case .worn: return ApocalypseTheme.warning
        case .normal: return ApocalypseTheme.textSecondary
        case .pristine: return ApocalypseTheme.success
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BackpackView()
    }
}
