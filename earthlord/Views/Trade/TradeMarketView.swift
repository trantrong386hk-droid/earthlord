//
//  TradeMarketView.swift
//  earthlord
//
//  交易市场
//  浏览其他玩家的挂单，接受交易
//

import SwiftUI

struct TradeMarketView: View {

    // MARK: - 属性

    @ObservedObject private var tradeManager = TradeManager.shared
    @ObservedObject private var inventoryManager = InventoryManager.shared

    // MARK: - 状态

    @State private var selectedOffer: TradeOffer?
    @State private var isAccepting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccessAlert = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 标题统计
            headerView
                .padding(.horizontal, 16)
                .padding(.top, 12)

            // 挂单列表
            if tradeManager.isLoading {
                loadingView
            } else if tradeManager.availableOffers.isEmpty {
                emptyStateView
            } else {
                offerList
            }
        }
        .sheet(item: $selectedOffer) { offer in
            AcceptTradeSheet(
                offer: offer,
                isAccepting: isAccepting
            ) {
                acceptOffer(offer)
            }
        }
        .alert("交易失败", isPresented: $showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("交易成功", isPresented: $showSuccessAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text("物品已交换，可在交易历史中查看详情")
        }
    }

    // MARK: - 标题统计

    private var headerView: some View {
        HStack {
            Text("可用交易")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("(\(tradeManager.availableOffers.count)个)")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()
        }
    }

    // MARK: - 加载中

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
            Text("加载中...")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textMuted)
            Spacer()
        }
    }

    // MARK: - 空状态

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "cart")
                .font(.system(size: 48))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("暂无可用的交易挂单")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("等待其他玩家发布交易")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textMuted)

            Spacer()
        }
    }

    // MARK: - 挂单列表

    private var offerList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(tradeManager.availableOffers) { offer in
                    MarketOfferCard(
                        offer: offer,
                        inventoryManager: inventoryManager
                    ) {
                        selectedOffer = offer
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 100)
        }
        .refreshable {
            await tradeManager.loadAvailableOffers()
        }
    }

    // MARK: - 方法

    private func acceptOffer(_ offer: TradeOffer) {
        isAccepting = true

        Task {
            do {
                try await tradeManager.acceptOffer(offerId: offer.id)
                await MainActor.run {
                    isAccepting = false
                    selectedOffer = nil
                    showSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    isAccepting = false
                    selectedOffer = nil
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - 市场挂单卡片

private struct MarketOfferCard: View {
    let offer: TradeOffer
    let inventoryManager: InventoryManager
    let onAccept: () -> Void

    /// 检查是否有足够的物品
    private var hasEnoughItems: Bool {
        for item in offer.requestingItems {
            if inventoryManager.getItemQuantity(name: item.name) < item.quantity {
                return false
            }
        }
        return true
    }

    var body: some View {
        ApocalypseCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                // 头部：发布者 + 时间
                HStack {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(ApocalypseTheme.primary)

                    Text(offer.ownerUsername ?? "匿名玩家")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Spacer()

                    Text(offer.formattedExpiresIn)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }

                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                // 他出的物品（你将获得）
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(ApocalypseTheme.success)
                            .font(.caption)
                        Text("你将获得:")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.success)
                    }

                    ForEach(offer.offeringItems) { item in
                        TradeItemRow(item: item)
                    }
                }

                // 他要的物品（你需要付出）
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(ApocalypseTheme.warning)
                            .font(.caption)
                        Text("你需要付出:")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.warning)
                    }

                    ForEach(offer.requestingItems) { item in
                        MarketItemRow(
                            item: item,
                            currentQuantity: inventoryManager.getItemQuantity(name: item.name)
                        )
                    }
                }

                // 留言
                if let message = offer.message, !message.isEmpty {
                    Text("「\(message)」")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .italic()
                }

                // 接受按钮
                Button(action: onAccept) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("接受交易")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(hasEnoughItems ? ApocalypseTheme.success : ApocalypseTheme.textMuted)
                    )
                }
                .disabled(!hasEnoughItems)
                .padding(.top, 4)

                // 库存不足提示
                if !hasEnoughItems {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(ApocalypseTheme.warning)
                            .font(.caption)
                        Text("库存不足，无法接受此交易")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.warning)
                    }
                }
            }
        }
    }
}

// MARK: - 市场物品行（带库存检查）

private struct MarketItemRow: View {
    let item: TradeItem
    let currentQuantity: Int

    private var hasEnough: Bool {
        currentQuantity >= item.quantity
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(hasEnough ? ApocalypseTheme.primary.opacity(0.3) : ApocalypseTheme.danger.opacity(0.3))
                .frame(width: 6, height: 6)

            Text(item.name)
                .font(.subheadline)
                .foregroundColor(hasEnough ? ApocalypseTheme.textPrimary : ApocalypseTheme.danger)

            Text("x\(item.quantity)")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(hasEnough ? ApocalypseTheme.textSecondary : ApocalypseTheme.danger)

            Spacer()

            // 库存显示
            Text("库存: \(currentQuantity)")
                .font(.caption)
                .foregroundColor(hasEnough ? ApocalypseTheme.textMuted : ApocalypseTheme.danger)
        }
    }
}

// MARK: - 接受交易确认弹窗

private struct AcceptTradeSheet: View {
    let offer: TradeOffer
    let isAccepting: Bool
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var inventoryManager = InventoryManager.shared

    /// 检查是否有足够的物品
    private var hasEnoughItems: Bool {
        for item in offer.requestingItems {
            if inventoryManager.getItemQuantity(name: item.name) < item.quantity {
                return false
            }
        }
        return true
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    // 你将付出
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundColor(ApocalypseTheme.warning)
                            Text("你将付出:")
                                .font(.headline)
                                .foregroundColor(ApocalypseTheme.textPrimary)
                        }

                        ForEach(offer.requestingItems) { item in
                            ConfirmItemRow(
                                item: item,
                                currentQuantity: inventoryManager.getItemQuantity(name: item.name),
                                isGiving: true
                            )
                        }
                    }
                    .padding(16)
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(12)

                    // 交换图标
                    Image(systemName: "arrow.up.arrow.down.circle.fill")
                        .font(.title)
                        .foregroundColor(ApocalypseTheme.primary)

                    // 你将获得
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundColor(ApocalypseTheme.success)
                            Text("你将获得:")
                                .font(.headline)
                                .foregroundColor(ApocalypseTheme.textPrimary)
                        }

                        ForEach(offer.offeringItems) { item in
                            ConfirmItemRow(
                                item: item,
                                currentQuantity: nil,
                                isGiving: false
                            )
                        }
                    }
                    .padding(16)
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(12)

                    // 库存检查状态
                    HStack {
                        if hasEnoughItems {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(ApocalypseTheme.success)
                            Text("物品充足")
                                .font(.subheadline)
                                .foregroundColor(ApocalypseTheme.success)
                        } else {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(ApocalypseTheme.danger)
                            Text("物品不足")
                                .font(.subheadline)
                                .foregroundColor(ApocalypseTheme.danger)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 4)

                    Spacer()

                    // 按钮组
                    HStack(spacing: 12) {
                        Button {
                            dismiss()
                        } label: {
                            Text("取消")
                                .font(.headline)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(ApocalypseTheme.textMuted.opacity(0.5), lineWidth: 1)
                                )
                        }

                        Button {
                            onConfirm()
                        } label: {
                            HStack {
                                if isAccepting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                Text(isAccepting ? "交易中..." : "确认交易")
                                    .fontWeight(.semibold)
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(hasEnoughItems && !isAccepting ? ApocalypseTheme.success : ApocalypseTheme.textMuted)
                            )
                        }
                        .disabled(!hasEnoughItems || isAccepting)
                    }
                }
                .padding(16)
            }
            .navigationTitle("确认交易")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - 确认物品行

private struct ConfirmItemRow: View {
    let item: TradeItem
    let currentQuantity: Int?
    let isGiving: Bool

    private var hasEnough: Bool {
        guard let current = currentQuantity else { return true }
        return current >= item.quantity
    }

    var body: some View {
        HStack {
            Text(item.name)
                .font(.subheadline)
                .foregroundColor(hasEnough ? ApocalypseTheme.textPrimary : ApocalypseTheme.danger)

            Text("x\(item.quantity)")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(hasEnough ? ApocalypseTheme.textSecondary : ApocalypseTheme.danger)

            Spacer()

            if let current = currentQuantity {
                Text("(\(current))")
                    .font(.caption)
                    .foregroundColor(hasEnough ? ApocalypseTheme.textMuted : ApocalypseTheme.danger)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        ApocalypseTheme.background
            .ignoresSafeArea()

        TradeMarketView()
    }
}
