//
//  BuildingBrowserView.swift
//  earthlord
//
//  建筑浏览器
//  显示所有可建造的建筑模板，按分类筛选
//

import SwiftUI

struct BuildingBrowserView: View {

    // MARK: - 属性

    let territoryId: String
    let onSelectTemplate: (BuildingTemplate) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var buildingManager = BuildingManager.shared

    /// 当前选中的分类
    @State private var selectedCategory: BuildingCategory = .survival

    /// 选中的模板（用于显示详情）
    @State private var selectedTemplate: BuildingTemplate?

    // MARK: - 计算属性

    /// 当前分类的模板列表
    private var filteredTemplates: [BuildingTemplate] {
        buildingManager.getTemplates(for: selectedCategory)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 分类标签栏
                    categoryTabBar
                        .padding(.top, 8)

                    // 建筑网格
                    if filteredTemplates.isEmpty {
                        emptyView
                    } else {
                        buildingGrid
                    }
                }
            }
            .navigationTitle("建筑列表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
            .sheet(item: $selectedTemplate) { template in
                BuildingDetailView(
                    template: template,
                    territoryId: territoryId,
                    onStartConstruction: {
                        selectedTemplate = nil
                        dismiss()
                        // 延迟调用以避免 sheet 动画冲突
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onSelectTemplate(template)
                        }
                    }
                )
            }
        }
    }

    // MARK: - 分类标签栏

    private var categoryTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(BuildingCategory.allCases, id: \.self) { category in
                    CategoryButton(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    // MARK: - 建筑网格

    private var buildingGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                ForEach(filteredTemplates) { template in
                    BuildingCard(
                        template: template,
                        existingCount: buildingManager.getBuildingCount(
                            templateId: template.templateId,
                            territoryId: territoryId
                        )
                    ) {
                        selectedTemplate = template
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .padding(.bottom, 40)
        }
    }

    // MARK: - 空状态

    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "building.2")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("暂无可用建筑")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("该分类下暂时没有可建造的建筑")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textMuted)

            Spacer()
        }
    }
}

#Preview {
    BuildingBrowserView(
        territoryId: "test-territory"
    ) { template in
        print("Selected: \(template.name)")
    }
}
