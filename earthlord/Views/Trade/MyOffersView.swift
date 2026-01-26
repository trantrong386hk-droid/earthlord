//
//  MyOffersView.swift
//  earthlord
//
//  我的挂单列表
//  展示用户发布的所有挂单，支持取消
//

import SwiftUI

struct MyOffersView: View {

    // MARK: - 属性

    @ObservedObject private var tradeManager = TradeManager.shared

    // MARK: - 状态

    @State private var showCreateOffer = false
    @State private var showCancelConfirm = false
    @State private var offerToCancel: TradeOffer?
    @State private var isCancelling = false
    @State private var showError = false
    @State private var errorMessage = ""

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 发布新挂单按钮
            createOfferButton
                .padding(.horizontal, 16)
                .padding(.top, 12)

            // 挂单列表
            if tradeManager.isLoading {
                loadingView
            } else if tradeManager.myOffers.isEmpty {
                emptyStateView
            } else {
                offerList
            }
        }
        .sheet(isPresented: $showCreateOffer) {
            CreateOfferView()
        }
        .alert("确认取消", isPresented: $showCancelConfirm) {
            Button("取消挂单", role: .destructive) {
                if let offer = offerToCancel {
                    cancelOffer(offer)
                }
            }
            Button("返回", role: .cancel) {}
        } message: {
            Text("取消后物品将退回背包，确定要取消吗？")
        }
        .alert("操作失败", isPresented: $showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - 发布新挂单按钮

    private var createOfferButton: some View {
        Button {
            showCreateOffer = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("发布新挂单")
                    .fontWeight(.medium)
            }
            .font(.subheadline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ApocalypseTheme.primary)
            )
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

            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("还没有发布过挂单")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("点击上方按钮发布你的第一个交易")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textMuted)

            Spacer()
        }
    }

    // MARK: - 挂单列表

    private var offerList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(tradeManager.myOffers) { offer in
                    MyOfferCard(
                        offer: offer,
                        isCancelling: isCancelling && offerToCancel?.id == offer.id
                    ) {
                        offerToCancel = offer
                        showCancelConfirm = true
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 100)
        }
        .refreshable {
            await tradeManager.loadMyOffers()
        }
    }

    // MARK: - 方法

    private func cancelOffer(_ offer: TradeOffer) {
        isCancelling = true
        offerToCancel = offer

        Task {
            do {
                try await tradeManager.cancelOffer(offerId: offer.id)
                await MainActor.run {
                    isCancelling = false
                    offerToCancel = nil
                }
            } catch {
                await MainActor.run {
                    isCancelling = false
                    offerToCancel = nil
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - 我的挂单卡片

private struct MyOfferCard: View {
    let offer: TradeOffer
    let isCancelling: Bool
    let onCancel: () -> Void

    var body: some View {
        ApocalypseCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                // 头部：状态 + 时间
                HStack {
                    StatusBadge(status: offer.status)

                    Spacer()

                    if offer.status == .active {
                        Text(offer.formattedExpiresIn)
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textMuted)
                    } else {
                        Text(offer.formattedCreatedAt)
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                }

                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                // 我出的物品
                VStack(alignment: .leading, spacing: 6) {
                    Text("我出:")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)

                    ForEach(offer.offeringItems) { item in
                        TradeItemRow(item: item)
                    }
                }

                // 我要的物品
                VStack(alignment: .leading, spacing: 6) {
                    Text("我要:")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)

                    ForEach(offer.requestingItems) { item in
                        TradeItemRow(item: item)
                    }
                }

                // 留言
                if let message = offer.message, !message.isEmpty {
                    Text("「\(message)」")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .italic()
                }

                // 完成信息
                if offer.status == .completed, let username = offer.completedByUsername {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(ApocalypseTheme.success)
                        Text("被 @\(username) 接受")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.success)
                    }
                }

                // 取消按钮（仅活跃状态显示）
                if offer.status == .active && !offer.isExpired {
                    Button(action: onCancel) {
                        HStack {
                            if isCancelling {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.danger))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "xmark.circle")
                            }
                            Text(isCancelling ? "取消中..." : "取消挂单")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.danger)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(ApocalypseTheme.danger.opacity(0.5), lineWidth: 1)
                        )
                    }
                    .disabled(isCancelling)
                    .padding(.top, 4)
                }
            }
        }
    }
}

// MARK: - 状态标签

struct StatusBadge: View {
    let status: TradeStatus

    private var backgroundColor: Color {
        switch status {
        case .active:
            return ApocalypseTheme.info
        case .completed:
            return ApocalypseTheme.success
        case .cancelled:
            return ApocalypseTheme.textMuted
        case .expired:
            return ApocalypseTheme.warning
        }
    }

    private var displayText: String {
        switch status {
        case .active:
            return "等待中"
        case .completed:
            return "已完成"
        case .cancelled:
            return "已取消"
        case .expired:
            return "已过期"
        }
    }

    var body: some View {
        Text(displayText)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(backgroundColor)
            )
    }
}

// MARK: - 交易物品行

struct TradeItemRow: View {
    let item: TradeItem

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(ApocalypseTheme.primary.opacity(0.3))
                .frame(width: 6, height: 6)

            Text(item.name)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("x\(item.quantity)")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        ApocalypseTheme.background
            .ignoresSafeArea()

        MyOffersView()
    }
}
