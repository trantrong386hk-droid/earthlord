//
//  POIDetailView.swift
//  earthlord
//
//  POI 详情页面
//  显示兴趣点的详细信息和操作按钮
//

import SwiftUI

struct POIDetailView: View {

    // MARK: - 属性

    /// POI 数据
    let poi: POI

    /// 是否显示探索结果弹窗
    @State private var showExplorationResult: Bool = false

    /// 动画状态
    @State private var showHero: Bool = false
    @State private var showInfo: Bool = false
    @State private var showActions: Bool = false
    @State private var searchButtonScale: CGFloat = 1.0

    /// 模拟距离（假数据）
    private let mockDistance: Double = 350

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景
            ApocalypseTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // 顶部大图区域
                    heroSection

                    // 信息区域
                    infoSection
                        .padding(.horizontal, 16)
                        .padding(.top, 20)

                    // 操作按钮区域
                    actionSection
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                        .padding(.bottom, 40)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showExplorationResult) {
            // 使用 ExplorationResultView 显示探索结果
            ExplorationResultView(
                result: MockExplorationResultData.currentResult,
                stats: MockExplorationResultData.stats
            )
        }
        .onAppear {
            // 依次触发入场动画
            withAnimation(.easeOut(duration: 0.5)) {
                showHero = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
                showInfo = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.4)) {
                showActions = true
            }
        }
    }

    // MARK: - 顶部大图区域

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            // 渐变背景
            LinearGradient(
                colors: [typeColor.opacity(0.8), typeColor.opacity(0.4), ApocalypseTheme.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 280)

            // 大图标（带入场动画）
            VStack {
                Spacer()

                Image(systemName: typeIcon)
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                    .scaleEffect(showHero ? 1.0 : 0.3)
                    .opacity(showHero ? 1.0 : 0)

                Spacer()
            }
            .frame(height: 200)

            // 底部遮罩和文字
            VStack(spacing: 4) {
                Text(poi.name)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text(poi.type.displayName)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .opacity(showHero ? 1.0 : 0)
            .offset(y: showHero ? 0 : 20)
        }
    }

    // MARK: - 信息区域

    private var infoSection: some View {
        VStack(spacing: 12) {
            // 距离
            InfoRow(
                icon: "location.fill",
                iconColor: ApocalypseTheme.info,
                title: "距离",
                value: String(format: "%.0f 米", mockDistance)
            )
            .opacity(showInfo ? 1 : 0)
            .offset(y: showInfo ? 0 : 15)
            .animation(.easeOut(duration: 0.3).delay(0), value: showInfo)

            // 物资状态
            InfoRow(
                icon: resourceIcon,
                iconColor: resourceColor,
                title: "物资状态",
                value: resourceText,
                valueColor: resourceColor
            )
            .opacity(showInfo ? 1 : 0)
            .offset(y: showInfo ? 0 : 15)
            .animation(.easeOut(duration: 0.3).delay(0.08), value: showInfo)

            // 危险等级
            InfoRow(
                icon: "exclamationmark.triangle.fill",
                iconColor: dangerColor,
                title: "危险等级",
                value: dangerText,
                valueColor: dangerColor
            )
            .opacity(showInfo ? 1 : 0)
            .offset(y: showInfo ? 0 : 15)
            .animation(.easeOut(duration: 0.3).delay(0.16), value: showInfo)

            // 来源
            InfoRow(
                icon: "doc.text.fill",
                iconColor: ApocalypseTheme.textSecondary,
                title: "来源",
                value: "地图数据"
            )
            .opacity(showInfo ? 1 : 0)
            .offset(y: showInfo ? 0 : 15)
            .animation(.easeOut(duration: 0.3).delay(0.24), value: showInfo)

            // 描述（如果有）
            if !poi.description.isEmpty {
                ApocalypseCard(padding: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "text.quote")
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textMuted)
                            Text("描述")
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textMuted)
                        }

                        Text(poi.description)
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .lineSpacing(4)
                    }
                }
                .opacity(showInfo ? 1 : 0)
                .offset(y: showInfo ? 0 : 15)
                .animation(.easeOut(duration: 0.3).delay(0.32), value: showInfo)
            }
        }
    }

    // MARK: - 操作按钮区域

    private var actionSection: some View {
        VStack(spacing: 14) {
            // 主按钮：搜寻此POI
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
                showExplorationResult = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)

                    Text(isLooted ? "已搜空" : "搜寻此POI")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    Group {
                        if isLooted {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(ApocalypseTheme.textMuted)
                        } else {
                            LinearGradient(
                                colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .cornerRadius(14)
                        }
                    }
                )
                .shadow(color: isLooted ? .clear : ApocalypseTheme.primary.opacity(0.4), radius: 10, y: 5)
            }
            .scaleEffect(searchButtonScale)
            .disabled(isLooted)
            .opacity(showActions ? 1 : 0)
            .offset(y: showActions ? 0 : 20)
            .animation(.easeOut(duration: 0.3), value: showActions)

            // 两个小按钮并排
            HStack(spacing: 12) {
                // 标记已发现
                SecondaryButton(
                    icon: "eye.fill",
                    title: "标记已发现",
                    isActive: poi.discoveryStatus != .undiscovered
                ) {
                    print("标记已发现: \(poi.name)")
                }

                // 标记无物资
                SecondaryButton(
                    icon: "xmark.circle.fill",
                    title: "标记无物资",
                    isActive: poi.resourceStatus == .looted
                ) {
                    print("标记无物资: \(poi.name)")
                }
            }
            .opacity(showActions ? 1 : 0)
            .offset(y: showActions ? 0 : 20)
            .animation(.easeOut(duration: 0.3).delay(0.1), value: showActions)
        }
    }

    // MARK: - 计算属性

    /// 是否已被搜空
    private var isLooted: Bool {
        poi.resourceStatus == .looted
    }

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

    /// 物资状态文字
    private var resourceText: String {
        switch poi.resourceStatus {
        case .unknown: return "未知"
        case .hasResources: return "有物资"
        case .looted: return "已清空"
        }
    }

    /// 物资状态图标
    private var resourceIcon: String {
        switch poi.resourceStatus {
        case .unknown: return "questionmark.circle.fill"
        case .hasResources: return "cube.box.fill"
        case .looted: return "xmark.circle.fill"
        }
    }

    /// 物资状态颜色
    private var resourceColor: Color {
        switch poi.resourceStatus {
        case .unknown: return ApocalypseTheme.textMuted
        case .hasResources: return ApocalypseTheme.success
        case .looted: return ApocalypseTheme.danger
        }
    }

    /// 危险等级文字
    private var dangerText: String {
        switch poi.dangerLevel {
        case 1: return "安全"
        case 2: return "低危"
        case 3: return "中危"
        case 4: return "高危"
        case 5: return "极危"
        default: return "未知"
        }
    }

    /// 危险等级颜色
    private var dangerColor: Color {
        switch poi.dangerLevel {
        case 1: return ApocalypseTheme.success
        case 2: return .green
        case 3: return ApocalypseTheme.warning
        case 4: return .orange
        case 5: return ApocalypseTheme.danger
        default: return ApocalypseTheme.textMuted
        }
    }
}

// MARK: - 信息行组件

private struct InfoRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    var valueColor: Color = ApocalypseTheme.textPrimary

    var body: some View {
        ApocalypseCard(padding: 14) {
            HStack {
                // 图标
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(iconColor)
                    .frame(width: 32)

                // 标题
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()

                // 值
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(valueColor)
            }
        }
    }
}

// MARK: - 次要按钮组件

private struct SecondaryButton: View {
    let icon: String
    let title: String
    let isActive: Bool
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
            .foregroundColor(isActive ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(ApocalypseTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        isActive ? ApocalypseTheme.primary.opacity(0.5) : ApocalypseTheme.textMuted.opacity(0.3),
                        lineWidth: 1
                    )
            )
        }
    }
}

// MARK: - Preview

#Preview("有物资") {
    NavigationStack {
        POIDetailView(poi: MockPOIData.pois[0]) // 废弃超市
    }
}

#Preview("已清空") {
    NavigationStack {
        POIDetailView(poi: MockPOIData.pois[1]) // 医院废墟
    }
}
