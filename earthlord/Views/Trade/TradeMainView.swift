//
//  TradeMainView.swift
//  earthlord
//
//  交易主页面
//  作为交易系统入口，提供 Tab 切换
//

import SwiftUI

// MARK: - 交易 Tab 类型

enum TradeTab: Int, CaseIterable {
    case market = 0     // 交易市场
    case myOffers = 1   // 我的挂单
    case history = 2    // 交易历史

    var title: String {
        switch self {
        case .market: return "交易市场"
        case .myOffers: return "我的挂单"
        case .history: return "交易历史"
        }
    }

    var icon: String {
        switch self {
        case .market: return "cart.fill"
        case .myOffers: return "doc.text.fill"
        case .history: return "clock.fill"
        }
    }
}

// MARK: - TradeMainView

struct TradeMainView: View {

    // MARK: - 状态

    @State private var selectedTab: TradeTab = .market
    @ObservedObject private var tradeManager = TradeManager.shared

    /// 列表项入场动画
    @State private var itemsAppeared: Bool = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 分段选择器
            tabPicker
                .padding(.horizontal, 16)
                .padding(.top, 12)

            // 内容区域
            tabContent
        }
        .task {
            // 加载所有交易数据
            await tradeManager.refreshAll()
        }
        .onAppear {
            // 入场动画
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.3)) {
                    itemsAppeared = true
                }
            }
        }
        .onChange(of: selectedTab) { _, _ in
            // 切换 Tab 时重置动画
            itemsAppeared = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.easeOut(duration: 0.3)) {
                    itemsAppeared = true
                }
            }
        }
    }

    // MARK: - 分段选择器

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(TradeTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.caption)

                        Text(tab.title)
                            .font(.subheadline)
                            .fontWeight(selectedTab == tab ? .semibold : .regular)
                    }
                    .foregroundColor(selectedTab == tab ? .white : ApocalypseTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        selectedTab == tab
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

    // MARK: - 内容区域

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .market:
            TradeMarketView()
                .opacity(itemsAppeared ? 1 : 0)
                .offset(y: itemsAppeared ? 0 : 20)

        case .myOffers:
            MyOffersView()
                .opacity(itemsAppeared ? 1 : 0)
                .offset(y: itemsAppeared ? 0 : 20)

        case .history:
            TradeHistoryView()
                .opacity(itemsAppeared ? 1 : 0)
                .offset(y: itemsAppeared ? 0 : 20)
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        ApocalypseTheme.background
            .ignoresSafeArea()

        TradeMainView()
    }
}
