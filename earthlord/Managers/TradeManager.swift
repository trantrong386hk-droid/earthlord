//
//  TradeManager.swift
//  earthlord
//
//  交易管理器
//  负责玩家之间的异步挂单交易系统：发布交易 → 等待接受 → 物品交换
//

import Foundation
import Combine
import Supabase

// MARK: - TradeManager

@MainActor
class TradeManager: ObservableObject {

    // MARK: - 单例
    static let shared = TradeManager()

    // MARK: - 发布属性

    /// 我发布的挂单
    @Published var myOffers: [TradeOffer] = []

    /// 可接受的挂单（其他玩家发布的活跃挂单）
    @Published var availableOffers: [TradeOffer] = []

    /// 交易历史
    @Published var tradeHistory: [TradeHistory] = []

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - 私有属性

    /// 当前用户 ID 缓存
    private var currentUserId: UUID?

    // MARK: - 初始化

    private init() {
        print("🤝 [TradeManager] 初始化")
    }

    // MARK: - 公开方法

    /// 创建交易挂单
    /// - Parameters:
    ///   - offeringItems: 提供的物品列表
    ///   - requestingItems: 请求的物品列表
    ///   - expiresInHours: 过期时间（小时），默认 24 小时
    ///   - message: 可选的交易留言
    /// - Returns: 创建成功的挂单
    @discardableResult
    func createOffer(
        offeringItems: [TradeItem],
        requestingItems: [TradeItem],
        expiresInHours: Int = 24,
        message: String? = nil
    ) async throws -> TradeOffer {
        print("🤝 [交易] 开始创建挂单...")

        // 1. 验证用户登录
        guard let userId = try? await supabase.auth.session.user.id else {
            throw TradeError.notAuthenticated
        }
        currentUserId = userId

        // 获取用户邮箱作为用户名
        let username = AuthManager.shared.userEmail

        // 2. 验证物品列表不为空
        guard !offeringItems.isEmpty && !requestingItems.isEmpty else {
            throw TradeError.invalidItems
        }

        // 3. 验证并扣除物品（锁定物品）
        // 先验证所有物品是否足够
        for item in offeringItems {
            let hasEnough = await InventoryManager.shared.hasEnoughItem(name: item.name, quantity: item.quantity)
            if !hasEnough {
                throw TradeError.insufficientItems("\(item.name) 数量不足")
            }
        }

        // 扣除物品（记录已扣除的物品，以便失败时回滚）
        var deductedItems: [TradeItem] = []
        do {
            for item in offeringItems {
                try await InventoryManager.shared.removeItemByName(name: item.name, quantity: item.quantity)
                deductedItems.append(item)
            }
        } catch {
            // 扣除失败，回滚已扣除的物品
            print("🤝 [交易] ❌ 扣除物品失败，回滚已扣除的物品: \(error)")
            for item in deductedItems {
                try? await InventoryManager.shared.addItemByName(name: item.name, quantity: item.quantity)
            }
            throw TradeError.insufficientItems("扣除物品失败")
        }

        print("🤝 [交易] 物品已锁定")

        // 4. 计算过期时间
        let expiresAt = Date().addingTimeInterval(Double(expiresInHours) * 3600)

        // 5. 创建挂单记录
        let upload = TradeOfferUpload(
            ownerId: userId,
            ownerUsername: username,
            offeringItems: offeringItems,
            requestingItems: requestingItems,
            status: "active",
            message: message,
            expiresAt: expiresAt
        )

        do {
            let offer: TradeOffer = try await supabase
                .from("trade_offers")
                .insert(upload)
                .select()
                .single()
                .execute()
                .value

            // 更新本地列表
            myOffers.insert(offer, at: 0)

            // 发送通知
            NotificationCenter.default.post(name: .tradeOfferCreated, object: offer)

            print("🤝 [交易] ✅ 挂单创建成功: \(offer.id)")
            return offer

        } catch {
            // 创建失败，退还物品
            print("🤝 [交易] ❌ 挂单创建失败，退还物品: \(error)")
            for item in offeringItems {
                try? await InventoryManager.shared.addItemByName(name: item.name, quantity: item.quantity)
            }
            throw TradeError.serverError(error.localizedDescription)
        }
    }

    /// 取消交易挂单
    /// - Parameter offerId: 挂单 ID
    func cancelOffer(offerId: UUID) async throws {
        print("🤝 [交易] 取消挂单: \(offerId)")

        // 1. 验证用户登录
        guard let userId = try? await supabase.auth.session.user.id else {
            throw TradeError.notAuthenticated
        }

        // 2. 查找挂单
        guard let offer = myOffers.first(where: { $0.id == offerId }) else {
            // 从服务器查询
            let offers: [TradeOffer] = try await supabase
                .from("trade_offers")
                .select()
                .eq("id", value: offerId.uuidString)
                .execute()
                .value

            guard let serverOffer = offers.first else {
                throw TradeError.offerNotFound
            }

            // 验证是否是自己的挂单
            guard serverOffer.ownerId == userId else {
                throw TradeError.offerNotFound
            }

            // 验证状态
            guard serverOffer.status == .active else {
                throw TradeError.offerNotActive
            }

            // 执行取消
            try await performCancelOffer(offer: serverOffer)
            return
        }

        // 验证是否是自己的挂单
        guard offer.ownerId == userId else {
            throw TradeError.offerNotFound
        }

        // 验证状态
        guard offer.status == .active else {
            throw TradeError.offerNotActive
        }

        try await performCancelOffer(offer: offer)
    }

    /// 执行取消挂单操作
    private func performCancelOffer(offer: TradeOffer) async throws {
        // 1. 更新数据库状态
        let update = TradeOfferUpdate(
            status: "cancelled",
            completedAt: nil,
            completedByUserId: nil,
            completedByUsername: nil
        )

        try await supabase
            .from("trade_offers")
            .update(update)
            .eq("id", value: offer.id.uuidString)
            .execute()

        // 2. 退还物品
        for item in offer.offeringItems {
            try await InventoryManager.shared.addItemByName(name: item.name, quantity: item.quantity)
        }

        // 3. 更新本地列表
        if let index = myOffers.firstIndex(where: { $0.id == offer.id }) {
            myOffers[index].status = .cancelled
        }

        // 4. 刷新背包
        await InventoryManager.shared.loadInventory()

        // 5. 发送通知
        NotificationCenter.default.post(name: .tradeOfferCancelled, object: offer)

        print("🤝 [交易] ✅ 挂单已取消，物品已退还")
    }

    /// 接受交易挂单（调用 RPC 函数确保原子性）
    /// - Parameter offerId: 挂单 ID
    func acceptOffer(offerId: UUID) async throws {
        print("🤝 [交易] 接受挂单: \(offerId)")

        // 验证用户登录
        guard (try? await supabase.auth.session.user.id) != nil else {
            throw TradeError.notAuthenticated
        }

        // 调用数据库 RPC 函数（保证原子性）
        let result: TradeRPCResult = try await supabase
            .rpc("accept_trade_offer", params: ["p_offer_id": offerId.uuidString])
            .execute()
            .value

        if !result.success {
            let errorMessage = result.error ?? "未知错误"
            print("🤝 [交易] ❌ 接受失败: \(errorMessage)")

            // 根据错误类型抛出对应异常
            if errorMessage.contains("不存在") {
                throw TradeError.offerNotFound
            } else if errorMessage.contains("过期") {
                throw TradeError.offerExpired
            } else if errorMessage.contains("失效") {
                throw TradeError.offerNotActive
            } else if errorMessage.contains("自己") {
                throw TradeError.cannotAcceptOwnOffer
            } else if errorMessage.contains("物品不足") {
                throw TradeError.insufficientItems(errorMessage)
            } else {
                throw TradeError.serverError(errorMessage)
            }
        }

        print("🤝 [交易] ✅ 交易完成")

        // 刷新数据
        await InventoryManager.shared.loadInventory()
        await loadAvailableOffers()
        await loadHistory()

        // 发送通知
        NotificationCenter.default.post(name: .tradeCompleted, object: offerId)
    }

    /// 加载我的挂单
    func loadMyOffers() async {
        print("🤝 [交易] 加载我的挂单...")

        guard let userId = try? await supabase.auth.session.user.id else {
            print("🤝 [交易] 用户未登录")
            return
        }
        currentUserId = userId

        isLoading = true
        errorMessage = nil

        do {
            let offers: [TradeOffer] = try await supabase
                .from("trade_offers")
                .select()
                .eq("owner_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            myOffers = offers

            // 处理过期挂单
            await processExpiredOffers()

            print("🤝 [交易] ✅ 加载了 \(offers.count) 个我的挂单")

        } catch {
            errorMessage = error.localizedDescription
            print("🤝 [交易] ❌ 加载我的挂单失败: \(error)")
        }

        isLoading = false
    }

    /// 加载可接受的挂单（其他玩家发布的活跃挂单）
    func loadAvailableOffers() async {
        print("🤝 [交易] 加载可用挂单...")

        guard let userId = try? await supabase.auth.session.user.id else {
            print("🤝 [交易] 用户未登录")
            return
        }
        currentUserId = userId

        isLoading = true
        errorMessage = nil

        do {
            // 查询活跃且未过期的挂单（排除自己的）
            let offers: [TradeOffer] = try await supabase
                .from("trade_offers")
                .select()
                .eq("status", value: "active")
                .neq("owner_id", value: userId.uuidString)
                .gt("expires_at", value: ISO8601DateFormatter().string(from: Date()))
                .order("created_at", ascending: false)
                .execute()
                .value

            // 过滤掉已过期的（客户端双重验证）
            availableOffers = offers.filter { !$0.isExpired }

            print("🤝 [交易] ✅ 加载了 \(availableOffers.count) 个可用挂单")

        } catch {
            errorMessage = error.localizedDescription
            print("🤝 [交易] ❌ 加载可用挂单失败: \(error)")
        }

        isLoading = false
    }

    /// 加载交易历史
    func loadHistory() async {
        print("🤝 [交易] 加载交易历史...")

        guard let userId = try? await supabase.auth.session.user.id else {
            print("🤝 [交易] 用户未登录")
            return
        }
        currentUserId = userId

        isLoading = true
        errorMessage = nil

        do {
            // 查询自己参与的交易历史
            let history: [TradeHistory] = try await supabase
                .from("trade_history")
                .select()
                .or("seller_id.eq.\(userId.uuidString),buyer_id.eq.\(userId.uuidString)")
                .order("completed_at", ascending: false)
                .limit(50)
                .execute()
                .value

            tradeHistory = history

            print("🤝 [交易] ✅ 加载了 \(history.count) 条交易历史")

        } catch {
            errorMessage = error.localizedDescription
            print("🤝 [交易] ❌ 加载交易历史失败: \(error)")
        }

        isLoading = false
    }

    /// 评价交易
    /// - Parameters:
    ///   - historyId: 交易历史 ID
    ///   - rating: 评分 1-5
    ///   - comment: 可选评论
    func rateTrade(historyId: UUID, rating: Int, comment: String? = nil) async throws {
        print("🤝 [交易] 评价交易: \(historyId), 评分: \(rating)")

        guard let userId = try? await supabase.auth.session.user.id else {
            throw TradeError.notAuthenticated
        }

        // 查找交易历史
        guard let history = tradeHistory.first(where: { $0.id == historyId }) else {
            throw TradeError.offerNotFound
        }

        // 验证评分范围
        let clampedRating = min(5, max(1, rating))

        // 确定用户角色并更新对应字段
        var update = TradeRatingUpdate()

        if history.sellerId == userId {
            // 用户是卖家
            if history.sellerRating != nil {
                throw TradeError.alreadyRated
            }
            update.sellerRating = clampedRating
            update.sellerComment = comment
        } else if history.buyerId == userId {
            // 用户是买家
            if history.buyerRating != nil {
                throw TradeError.alreadyRated
            }
            update.buyerRating = clampedRating
            update.buyerComment = comment
        } else {
            throw TradeError.offerNotFound
        }

        // 更新数据库
        try await supabase
            .from("trade_history")
            .update(update)
            .eq("id", value: historyId.uuidString)
            .execute()

        // 更新本地数据
        if let index = tradeHistory.firstIndex(where: { $0.id == historyId }) {
            if history.sellerId == userId {
                tradeHistory[index].sellerRating = clampedRating
                tradeHistory[index].sellerComment = comment
            } else {
                tradeHistory[index].buyerRating = clampedRating
                tradeHistory[index].buyerComment = comment
            }
        }

        print("🤝 [交易] ✅ 评价成功")
    }

    /// 刷新所有交易数据
    func refreshAll() async {
        await loadMyOffers()
        await loadAvailableOffers()
        await loadHistory()
    }

    // MARK: - 私有方法

    /// 处理过期挂单（退还物品）
    private func processExpiredOffers() async {
        let expiredOffers = myOffers.filter { $0.status == .active && $0.isExpired }

        for offer in expiredOffers {
            print("🤝 [交易] 处理过期挂单: \(offer.id)")

            do {
                // 更新状态为过期
                let update = TradeOfferUpdate(
                    status: "expired",
                    completedAt: nil,
                    completedByUserId: nil,
                    completedByUsername: nil
                )

                try await supabase
                    .from("trade_offers")
                    .update(update)
                    .eq("id", value: offer.id.uuidString)
                    .execute()

                // 退还物品
                for item in offer.offeringItems {
                    try await InventoryManager.shared.addItemByName(name: item.name, quantity: item.quantity)
                }

                // 更新本地状态
                if let index = myOffers.firstIndex(where: { $0.id == offer.id }) {
                    myOffers[index].status = .expired
                }

                print("🤝 [交易] ✅ 过期挂单已处理，物品已退还")

            } catch {
                print("🤝 [交易] ❌ 处理过期挂单失败: \(error)")
            }
        }

        // 如果有过期处理，刷新背包
        if !expiredOffers.isEmpty {
            await InventoryManager.shared.loadInventory()
        }
    }

    // MARK: - 辅助方法

    /// 获取当前用户 ID
    func getCurrentUserId() async -> UUID? {
        if let cached = currentUserId {
            return cached
        }
        currentUserId = try? await supabase.auth.session.user.id
        return currentUserId
    }

    /// 检查挂单是否属于当前用户
    func isMyOffer(_ offer: TradeOffer) async -> Bool {
        guard let userId = await getCurrentUserId() else { return false }
        return offer.ownerId == userId
    }

    /// 获取活跃挂单数量
    var activeOffersCount: Int {
        myOffers.filter { $0.status == .active && !$0.isExpired }.count
    }

    /// 获取今日交易次数
    var todayTradeCount: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return tradeHistory.filter { calendar.isDate($0.completedAt, inSameDayAs: today) }.count
    }
}
