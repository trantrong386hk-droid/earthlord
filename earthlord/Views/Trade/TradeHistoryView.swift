//
//  TradeHistoryView.swift
//  earthlord
//
//  交易历史
//  查看已完成的交易，进行评价
//

import SwiftUI

struct TradeHistoryView: View {

    // MARK: - 属性

    @ObservedObject private var tradeManager = TradeManager.shared

    // MARK: - 状态

    @State private var selectedHistory: TradeHistory?
    @State private var currentUserId: UUID?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 历史列表
            if tradeManager.isLoading {
                loadingView
            } else if tradeManager.tradeHistory.isEmpty {
                emptyStateView
            } else {
                historyList
            }
        }
        .sheet(item: $selectedHistory) { history in
            if let userId = currentUserId {
                RatingSheetView(history: history, userId: userId) { rating, comment in
                    await submitRating(historyId: history.id, rating: rating, comment: comment)
                }
            }
        }
        .task {
            currentUserId = await tradeManager.getCurrentUserId()
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

            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("还没有交易记录")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("完成交易后将在这里显示")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textMuted)

            Spacer()
        }
    }

    // MARK: - 历史列表

    private var historyList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(tradeManager.tradeHistory) { history in
                    if let userId = currentUserId {
                        TradeHistoryCard(history: history, userId: userId) {
                            selectedHistory = history
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 100)
        }
        .refreshable {
            await tradeManager.loadHistory()
        }
    }

    // MARK: - 方法

    private func submitRating(historyId: UUID, rating: Int, comment: String?) async {
        do {
            try await tradeManager.rateTrade(historyId: historyId, rating: rating, comment: comment)
            selectedHistory = nil
            await tradeManager.loadHistory()
        } catch {
            print("评价失败: \(error)")
        }
    }
}

// MARK: - 交易历史卡片

private struct TradeHistoryCard: View {
    let history: TradeHistory
    let userId: UUID
    let onRate: () -> Void

    /// 用户角色
    private var role: TradeRole? {
        history.role(for: userId)
    }

    /// 交易对方用户名
    private var partnerUsername: String {
        if history.sellerId == userId {
            return history.buyerUsername ?? "匿名玩家"
        } else {
            return history.sellerUsername ?? "匿名玩家"
        }
    }

    /// 用户给出的物品
    private var givenItems: [TradeItem] {
        if history.sellerId == userId {
            return history.itemsExchanged.offered
        } else {
            return history.itemsExchanged.requested
        }
    }

    /// 用户获得的物品
    private var receivedItems: [TradeItem] {
        if history.sellerId == userId {
            return history.itemsExchanged.requested
        } else {
            return history.itemsExchanged.offered
        }
    }

    /// 用户的评价
    private var myRating: Int? {
        if history.sellerId == userId {
            return history.sellerRating
        } else {
            return history.buyerRating
        }
    }

    /// 用户的评论
    private var myComment: String? {
        if history.sellerId == userId {
            return history.sellerComment
        } else {
            return history.buyerComment
        }
    }

    /// 对方的评价
    private var partnerRating: Int? {
        if history.sellerId == userId {
            return history.buyerRating
        } else {
            return history.sellerRating
        }
    }

    /// 对方的评论
    private var partnerComment: String? {
        if history.sellerId == userId {
            return history.buyerComment
        } else {
            return history.sellerComment
        }
    }

    /// 是否可以评价
    private var canRate: Bool {
        history.canRate(as: userId)
    }

    var body: some View {
        ApocalypseCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                // 头部：交易对方 + 时间
                HStack {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(ApocalypseTheme.primary)

                    Text("与 @\(partnerUsername) 的交易")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Spacer()

                    Text(history.formattedCompletedAt)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }

                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                // 你给出的物品（仅当有物品时显示）
                if !givenItems.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("你给出:")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.warning)

                        ForEach(givenItems) { item in
                            TradeItemRow(item: item)
                        }
                    }
                }

                // 你获得的物品（仅当有物品时显示）
                if !receivedItems.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("你获得:")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.success)

                        ForEach(receivedItems) { item in
                            TradeItemRow(item: item)
                        }
                    }
                }

                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                // 评价区域
                VStack(alignment: .leading, spacing: 8) {
                    // 我的评价
                    if let rating = myRating {
                        HStack {
                            Text("你的评价:")
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textMuted)

                            StarRatingDisplay(rating: rating)

                            if let comment = myComment, !comment.isEmpty {
                                Text("「\(comment)」")
                                    .font(.caption)
                                    .foregroundColor(ApocalypseTheme.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                    }

                    // 对方的评价
                    if let rating = partnerRating {
                        HStack {
                            Text("对方评价:")
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textMuted)

                            StarRatingDisplay(rating: rating)

                            if let comment = partnerComment, !comment.isEmpty {
                                Text("「\(comment)」")
                                    .font(.caption)
                                    .foregroundColor(ApocalypseTheme.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                    }

                    // 去评价按钮
                    if canRate {
                        Button(action: onRate) {
                            HStack {
                                Image(systemName: "star.fill")
                                Text("去评价")
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(ApocalypseTheme.warning)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(ApocalypseTheme.warning.opacity(0.5), lineWidth: 1)
                            )
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
    }
}

// MARK: - 星级显示

private struct StarRatingDisplay: View {
    let rating: Int
    let maxRating: Int = 5

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...maxRating, id: \.self) { index in
                Image(systemName: index <= rating ? "star.fill" : "star")
                    .font(.system(size: 12))
                    .foregroundColor(index <= rating ? ApocalypseTheme.warning : ApocalypseTheme.textMuted)
            }
        }
    }
}

// MARK: - 评价弹窗

private struct RatingSheetView: View {
    let history: TradeHistory
    let userId: UUID
    let onSubmit: (Int, String?) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var rating: Int = 5
    @State private var comment: String = ""
    @State private var isSubmitting = false

    /// 交易对方用户名
    private var partnerUsername: String {
        if history.sellerId == userId {
            return history.buyerUsername ?? "匿名玩家"
        } else {
            return history.sellerUsername ?? "匿名玩家"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // 提示文字
                    Text("请评价与 @\(partnerUsername) 的交易")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .padding(.top, 12)

                    // 星级评分
                    StarRatingInput(rating: $rating)

                    // 评语输入
                    VStack(alignment: .leading, spacing: 8) {
                        Text("评语（可选）")
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        TextField("写点什么...", text: $comment, axis: .vertical)
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                            .padding(12)
                            .background(ApocalypseTheme.cardBackground)
                            .cornerRadius(8)
                            .lineLimit(3...5)
                    }
                    .padding(.horizontal, 16)

                    Spacer()

                    // 提交按钮
                    Button {
                        isSubmitting = true
                        Task {
                            await onSubmit(rating, comment.isEmpty ? nil : comment)
                            isSubmitting = false
                        }
                    } label: {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text(isSubmitting ? "提交中..." : "提交评价")
                                .fontWeight(.semibold)
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isSubmitting ? ApocalypseTheme.textMuted : ApocalypseTheme.primary)
                        )
                    }
                    .disabled(isSubmitting)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle("评价交易")
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

// MARK: - 星级输入

private struct StarRatingInput: View {
    @Binding var rating: Int
    let maxRating: Int = 5

    var body: some View {
        HStack(spacing: 12) {
            ForEach(1...maxRating, id: \.self) { index in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        rating = index
                    }
                } label: {
                    Image(systemName: index <= rating ? "star.fill" : "star")
                        .font(.system(size: 36))
                        .foregroundColor(index <= rating ? ApocalypseTheme.warning : ApocalypseTheme.textMuted)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        ApocalypseTheme.background
            .ignoresSafeArea()

        TradeHistoryView()
    }
}
