//
//  ItemPickerView.swift
//  earthlord
//
//  物品选择器弹窗组件
//  支持两种模式：选择自己库存的物品（offering）或选择所有可交易物品（requesting）
//

import SwiftUI

// MARK: - 选择器模式

enum ItemPickerMode {
    case offering    // 选择要出的物品（限制为库存）
    case requesting  // 选择想要的物品（所有物品定义）
}

// MARK: - 可选择的物品

struct PickerItem: Identifiable, Hashable {
    let id: String
    let name: String
    let category: String
    let maxQuantity: Int?  // nil 表示无限制

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: PickerItem, rhs: PickerItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - ItemPickerView

struct ItemPickerView: View {

    // MARK: - 属性

    let mode: ItemPickerMode
    let onSelect: (TradeItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var inventoryManager = InventoryManager.shared

    // MARK: - 状态

    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    @State private var selectedItem: PickerItem? = nil
    @State private var quantity: Int = 1
    @State private var showQuantityPicker = false

    // MARK: - 计算属性

    /// 可选物品列表
    private var availableItems: [PickerItem] {
        switch mode {
        case .offering:
            // 从用户库存获取，使用数据库名称以匹配交易系统
            return inventoryManager.items.compactMap { item in
                // 获取数据库名称（交易系统使用数据库名称进行匹配）
                let dbName: String
                if item.isAIGenerated {
                    dbName = item.aiName ?? item.displayName
                } else {
                    dbName = inventoryManager.getDBItemName(localDefId: item.definitionId) ?? item.displayName
                }
                return PickerItem(
                    id: item.id.uuidString,
                    name: dbName,
                    category: item.displayCategory?.rawValue ?? "misc",
                    maxQuantity: item.quantity
                )
            }
        case .requesting:
            // 从物品定义缓存获取（已是数据库名称）
            return inventoryManager.itemDefinitionsCache.values.map { def in
                PickerItem(
                    id: def.id.uuidString,
                    name: def.name,
                    category: def.category,
                    maxQuantity: nil
                )
            }
        }
    }

    /// 筛选后的物品列表
    private var filteredItems: [PickerItem] {
        var result = availableItems

        // 按分类筛选
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        // 按搜索文本筛选
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        return result
    }

    /// 分类选项
    private var categoryOptions: [String] {
        let categories = Set(availableItems.map { $0.category })
        return Array(categories).sorted()
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 搜索框
                    searchBar
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    // 分类筛选
                    categoryFilter
                        .padding(.top, 12)

                    // 物品列表
                    itemList
                        .padding(.top, 8)
                }
            }
            .navigationTitle(mode == .offering ? "选择要出的物品" : "选择想要的物品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .sheet(isPresented: $showQuantityPicker) {
                if let item = selectedItem {
                    QuantityPickerSheet(
                        item: item,
                        initialQuantity: quantity,
                        maxQuantity: item.maxQuantity
                    ) { selectedQuantity in
                        // 创建 TradeItem 并回调
                        let tradeItem = TradeItem(name: item.name, quantity: selectedQuantity)
                        onSelect(tradeItem)
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - 搜索框

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(ApocalypseTheme.textMuted)

            TextField("搜索物品...", text: $searchText)
                .foregroundColor(ApocalypseTheme.textPrimary)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
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

    // MARK: - 分类筛选

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // 全部按钮
                FilterChip(
                    title: "全部",
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }

                // 各分类按钮
                ForEach(categoryOptions, id: \.self) { category in
                    FilterChip(
                        title: categoryDisplayName(category),
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - 物品列表

    private var itemList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if filteredItems.isEmpty {
                    emptyStateView
                } else {
                    ForEach(filteredItems) { item in
                        ItemPickerRow(item: item) {
                            selectedItem = item
                            quantity = 1
                            showQuantityPicker = true
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
    }

    // MARK: - 空状态

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: mode == .offering ? "bag" : "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text(mode == .offering ? "背包中没有物品" : "没有找到物品")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            if !searchText.isEmpty || selectedCategory != nil {
                Text("尝试清除搜索条件")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - 辅助方法

    private func categoryDisplayName(_ category: String) -> String {
        switch category {
        case "food": return "食物"
        case "water": return "水"
        case "material": return "材料"
        case "tool": return "工具"
        case "medical": return "医疗"
        case "weapon": return "武器"
        default: return "其他"
        }
    }
}

// MARK: - 筛选标签组件

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : ApocalypseTheme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(isSelected ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
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

// MARK: - 物品行组件

private struct ItemPickerRow: View {
    let item: PickerItem
    let onTap: () -> Void

    private var categoryIcon: String {
        switch item.category {
        case "food": return "fork.knife"
        case "water": return "drop.fill"
        case "material": return "cube.fill"
        case "tool": return "wrench.and.screwdriver.fill"
        case "medical": return "cross.case.fill"
        case "weapon": return "bolt.fill"
        default: return "shippingbox.fill"
        }
    }

    private var categoryColor: Color {
        switch item.category {
        case "food": return .orange
        case "water": return .cyan
        case "material": return .brown
        case "tool": return .gray
        case "medical": return .red
        case "weapon": return .purple
        default: return .gray
        }
    }

    var body: some View {
        Button(action: onTap) {
            ApocalypseCard(padding: 12) {
                HStack(spacing: 12) {
                    // 图标
                    Image(systemName: categoryIcon)
                        .font(.title3)
                        .foregroundColor(categoryColor)
                        .frame(width: 40, height: 40)
                        .background(categoryColor.opacity(0.15))
                        .clipShape(Circle())

                    // 名称
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        if let maxQty = item.maxQuantity {
                            Text("库存: \(maxQty)")
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 数量选择器弹窗

private struct QuantityPickerSheet: View {
    let item: PickerItem
    let initialQuantity: Int
    let maxQuantity: Int?
    let onConfirm: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var quantity: Int

    init(item: PickerItem, initialQuantity: Int, maxQuantity: Int?, onConfirm: @escaping (Int) -> Void) {
        self.item = item
        self.initialQuantity = initialQuantity
        self.maxQuantity = maxQuantity
        self.onConfirm = onConfirm
        _quantity = State(initialValue: initialQuantity)
    }

    private var effectiveMax: Int {
        maxQuantity ?? 9999
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // 物品信息
                    VStack(spacing: 8) {
                        Text(item.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        if let max = maxQuantity {
                            Text("库存: \(max) 个")
                                .font(.subheadline)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }
                    }
                    .padding(.top, 20)

                    // 数量选择器
                    HStack(spacing: 20) {
                        // 减少按钮
                        Button {
                            if quantity > 1 {
                                quantity -= 1
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 44))
                                .foregroundColor(quantity > 1 ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                        }
                        .disabled(quantity <= 1)

                        // 数量显示
                        Text("\(quantity)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                            .frame(minWidth: 80)

                        // 增加按钮
                        Button {
                            if quantity < effectiveMax {
                                quantity += 1
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 44))
                                .foregroundColor(quantity < effectiveMax ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                        }
                        .disabled(quantity >= effectiveMax)
                    }

                    // 快捷按钮
                    if let max = maxQuantity, max > 1 {
                        HStack(spacing: 12) {
                            QuickQuantityButton(title: "1", isSelected: quantity == 1) {
                                quantity = 1
                            }
                            QuickQuantityButton(title: "10", isSelected: quantity == 10) {
                                quantity = min(10, max)
                            }
                            QuickQuantityButton(title: "50", isSelected: quantity == 50) {
                                quantity = min(50, max)
                            }
                            QuickQuantityButton(title: "全部", isSelected: quantity == max) {
                                quantity = max
                            }
                        }
                    }

                    Spacer()

                    // 确认按钮
                    Button {
                        onConfirm(quantity)
                    } label: {
                        Text("确认添加")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(ApocalypseTheme.primary)
                            )
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle("选择数量")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - 快捷数量按钮

private struct QuickQuantityButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : ApocalypseTheme.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(isSelected ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
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

// MARK: - Preview

#Preview {
    ItemPickerView(mode: .offering) { item in
        print("Selected: \(item.name) x\(item.quantity)")
    }
}
