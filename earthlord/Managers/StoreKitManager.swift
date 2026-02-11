//
//  StoreKitManager.swift
//  earthlord
//
//  StoreKit 2 内购管理器
//  负责商品加载、购买、订阅状态检查、交易监听和 Supabase 同步
//

import Foundation
import StoreKit
import Combine
import Supabase

// MARK: - 订阅状态

enum SubscriptionStatus: Equatable {
    case free
    case subscribed(expiresAt: Date)
    case expired

    var isSubscribed: Bool {
        if case .subscribed = self { return true }
        return false
    }

    var expiresAt: Date? {
        if case .subscribed(let date) = self { return date }
        return nil
    }
}

// MARK: - StoreKitManager

@MainActor
class StoreKitManager: ObservableObject {

    // MARK: - 单例

    static let shared = StoreKitManager()

    // MARK: - 发布属性

    /// 订阅状态
    @Published var subscriptionStatus: SubscriptionStatus = .free

    /// 所有可购买商品
    @Published var products: [Product] = []

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    /// 是否已完成首次加载（用于区分"正在加载"和"加载完毕但为空"）
    @Published var hasLoadedProducts: Bool = false

    /// 是否正在购买
    @Published var isPurchasing: Bool = false

    /// 购买历史记录
    @Published var purchaseHistory: [PurchaseHistoryItem] = []

    // MARK: - 私有属性

    /// 交易监听任务
    private var transactionListenerTask: Task<Void, Never>?

    /// UserDefaults 缓存键
    private let subscriptionStatusKey = "iap_subscription_status"
    private let subscriptionExpiresKey = "iap_subscription_expires"

    // MARK: - 初始化

    private init() {
        print("💰 [StoreKitManager] 初始化")

        // 从本地缓存恢复订阅状态
        loadCachedSubscriptionStatus()

        // 启动交易监听
        startTransactionListener()

        // 加载商品和检查订阅状态
        Task {
            await loadProducts()
            await checkSubscriptionStatus()
        }
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    // MARK: - 商品加载

    /// 从 App Store 加载所有商品
    func loadProducts() async {
        isLoading = true
        errorMessage = nil

        // 诊断：打印请求的商品 ID
        print("💰 [StoreKit] 请求加载商品，IDs: \(IAPProductID.allProductIDs)")

        do {
            var storeProducts = try await Product.products(for: IAPProductID.allProductIDs)

            // 若首次为空，等 2 秒后重试一次
            if storeProducts.isEmpty {
                print("💰 [StoreKit] ⚠️ 首次加载为空，2 秒后重试...")
                try await Task.sleep(nanoseconds: 2_000_000_000)
                storeProducts = try await Product.products(for: IAPProductID.allProductIDs)
            }

            products = storeProducts.sorted { p1, p2 in
                // 订阅优先，然后按价格排序
                if IAPProductID.subscriptionIDs.contains(p1.id) && !IAPProductID.subscriptionIDs.contains(p2.id) {
                    return true
                }
                if !IAPProductID.subscriptionIDs.contains(p1.id) && IAPProductID.subscriptionIDs.contains(p2.id) {
                    return false
                }
                return p1.price < p2.price
            }
            print("💰 [StoreKit] ✅ 加载了 \(products.count) 个商品")
            for product in products {
                print("💰 [StoreKit]   - \(product.id): \(product.displayName) \(product.displayPrice)")
            }

            // 诊断：若仍为空，打印环境信息
            if products.isEmpty {
                print("💰 [StoreKit] ⚠️ 重试后仍为空。诊断信息：")
                print("💰 [StoreKit]   - 请求的 IDs 数量: \(IAPProductID.allProductIDs.count)")
                print("💰 [StoreKit]   - Bundle ID: \(Bundle.main.bundleIdentifier ?? "nil")")
                #if DEBUG
                print("💰 [StoreKit]   - 环境: DEBUG（应使用 StoreKit Testing）")
                #else
                print("💰 [StoreKit]   - 环境: RELEASE（使用 App Store）")
                #endif
            }
        } catch {
            errorMessage = "加载商品失败: \(error.localizedDescription)"
            print("💰 [StoreKit] ❌ 加载商品失败: \(error)")
        }

        isLoading = false
        hasLoadedProducts = true
    }

    // MARK: - 购买

    /// 购买商品
    func purchase(_ product: Product) async -> Bool {
        isPurchasing = true
        errorMessage = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)

                // 处理交易
                await handleTransaction(transaction, productId: product.id)

                // 完成交易
                await transaction.finish()

                print("💰 [StoreKit] ✅ 购买成功: \(product.id)")
                isPurchasing = false
                return true

            case .userCancelled:
                print("💰 [StoreKit] 用户取消购买")
                isPurchasing = false
                return false

            case .pending:
                print("💰 [StoreKit] 购买待处理（需要家长审批等）")
                isPurchasing = false
                return false

            @unknown default:
                print("💰 [StoreKit] 未知购买结果")
                isPurchasing = false
                return false
            }
        } catch {
            errorMessage = "购买失败: \(error.localizedDescription)"
            print("💰 [StoreKit] ❌ 购买失败: \(error)")
            isPurchasing = false
            return false
        }
    }

    // MARK: - 订阅状态检查

    /// 检查当前订阅状态
    func checkSubscriptionStatus() async {
        // 检查月订阅
        for productId in IAPProductID.subscriptionIDs {
            if let result = await Transaction.currentEntitlement(for: productId) {
                do {
                    let transaction = try checkVerified(result)
                    if let expirationDate = transaction.expirationDate,
                       expirationDate > Date() {
                        subscriptionStatus = .subscribed(expiresAt: expirationDate)
                        cacheSubscriptionStatus()
                        print("💰 [StoreKit] ✅ 订阅有效，到期: \(expirationDate)")
                        return
                    }
                } catch {
                    print("💰 [StoreKit] ⚠️ 验证订阅交易失败: \(error)")
                }
            }
        }

        // 没有有效订阅
        if case .subscribed = subscriptionStatus {
            subscriptionStatus = .expired
        } else if subscriptionStatus != .expired {
            subscriptionStatus = .free
        }
        cacheSubscriptionStatus()
        print("💰 [StoreKit] 当前状态: \(subscriptionStatus)")
    }

    // MARK: - 恢复购买

    /// 恢复购买
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil

        do {
            try await AppStore.sync()
            await checkSubscriptionStatus()
            print("💰 [StoreKit] ✅ 恢复购买完成")
        } catch {
            errorMessage = "恢复购买失败: \(error.localizedDescription)"
            print("💰 [StoreKit] ❌ 恢复购买失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 交易监听

    /// 启动交易监听（处理在其他设备完成的购买、续订等）
    private func startTransactionListener() {
        transactionListenerTask = Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await self.handleTransaction(transaction, productId: transaction.productID)
                    await transaction.finish()
                } catch {
                    print("💰 [StoreKit] ⚠️ 交易验证失败: \(error)")
                }
            }
        }
        print("💰 [StoreKit] 交易监听已启动")
    }

    // MARK: - 交易处理

    /// 处理已验证的交易
    private func handleTransaction(_ transaction: Transaction, productId: String) async {
        if IAPProductID.subscriptionIDs.contains(productId) {
            // 订阅交易
            if let expirationDate = transaction.expirationDate,
               expirationDate > Date() {
                subscriptionStatus = .subscribed(expiresAt: expirationDate)
                cacheSubscriptionStatus()
            }
            await syncSubscriptionToSupabase(transaction: transaction)
        } else if IAPProductID.consumableIDs.contains(productId) {
            // 消耗品交易
            await syncConsumableToSupabase(transaction: transaction)
            await deliverConsumable(productId: productId)
        }
    }

    // MARK: - Supabase 同步

    /// 同步订阅到 Supabase
    private func syncSubscriptionToSupabase(transaction: Transaction) async {
        guard let userId = try? await supabase.auth.session.user.id else {
            print("💰 [Supabase] ⚠️ 未登录，跳过同步")
            return
        }

        let record = DBSubscriptionRecord(
            userId: userId,
            productId: transaction.productID,
            status: transaction.revocationDate == nil ? "active" : "revoked",
            transactionId: String(transaction.id),
            originalTransactionId: String(transaction.originalID),
            purchasedAt: transaction.purchaseDate,
            expiresAt: transaction.expirationDate ?? transaction.purchaseDate
        )

        do {
            try await supabase
                .from("user_subscriptions")
                .upsert(record, onConflict: "transaction_id")
                .execute()
            print("💰 [Supabase] ✅ 订阅记录已同步")
        } catch {
            print("💰 [Supabase] ❌ 同步订阅失败: \(error)")
        }
    }

    /// 同步消耗品购买到 Supabase
    private func syncConsumableToSupabase(transaction: Transaction) async {
        guard let userId = try? await supabase.auth.session.user.id else {
            print("💰 [Supabase] ⚠️ 未登录，跳过同步")
            return
        }

        let record = DBConsumableRecord(
            userId: userId,
            productId: transaction.productID,
            transactionId: String(transaction.id),
            purchasedAt: transaction.purchaseDate
        )

        do {
            try await supabase
                .from("consumable_purchases")
                .insert(record)
                .execute()
            print("💰 [Supabase] ✅ 消耗品购买记录已同步")
        } catch {
            print("💰 [Supabase] ❌ 同步消耗品失败: \(error)")
        }
    }

    // MARK: - 消耗品发放

    /// 发放消耗品内容到玩家背包
    private func deliverConsumable(productId: String) async {
        let inventoryManager = InventoryManager.shared

        switch productId {
        case IAPProductID.resourceBox:
            // 资源补给箱：木材x50、石头x50、金属板x30、电子元件x20
            for item in ResourceBoxContents.items {
                do {
                    try await inventoryManager.addItemByName(name: item.name, quantity: item.quantity)
                    print("💰 [发放] ✅ \(item.name) x\(item.quantity)")
                } catch {
                    print("💰 [发放] ❌ \(item.name) 发放失败: \(error)")
                }
            }

        case IAPProductID.instantBuild:
            // 即时建造卡：记录到 consumable_purchases，由 UI 层在使用时消费
            print("💰 [发放] 即时建造卡已记录，待使用时消费")

        case IAPProductID.explorationBoost:
            // 探索增幅器：记录购买时间，EntitlementManager 检查 24h 有效期
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "exploration_boost_purchased_at")
            print("💰 [发放] 探索增幅器已激活，24 小时有效")

        case IAPProductID.legendaryCrate:
            // 传奇物资箱：立即生成 3 个传奇级 AI 物品
            await deliverLegendaryCrate()

        default:
            print("💰 [发放] ⚠️ 未知商品: \(productId)")
        }
    }

    // MARK: - 传奇宝箱发放

    /// 生成传奇宝箱 AI 物品并添加到背包
    private func deliverLegendaryCrate() async {
        print("💰 [发放] 传奇物资箱：开始生成 AI 物品...")

        // 1. 调用 AI 生成传奇物品
        guard let aiItems = await AIItemGenerator.shared.generateLegendaryItems(count: 3) else {
            print("💰 [发放] ❌ 传奇物资箱 AI 物品生成失败")
            errorMessage = "传奇物资箱开启失败，请稍后重试"
            return
        }

        // 2. 转换为 ExplorationLoot
        let lootItems: [ExplorationLoot] = aiItems.map { item in
            ExplorationLoot(
                id: UUID(),
                itemId: "ai_generated",
                quantity: 1,
                quality: nil,
                isAIGenerated: true,
                aiName: item.name,
                aiCategory: item.category,
                aiRarity: item.rarity,
                aiStory: item.story
            )
        }

        // 3. 添加到背包
        do {
            try await InventoryManager.shared.addItems(lootItems, sourceType: "legendary_crate", sourceId: UUID())
            print("💰 [发放] ✅ 传奇物资箱：\(aiItems.count) 件物品已添加到背包")
        } catch {
            print("💰 [发放] ❌ 传奇物资箱物品入库失败: \(error)")
            errorMessage = "物品入库失败：\(error.localizedDescription)"
        }

        // 4. 刷新背包
        await InventoryManager.shared.loadInventory()
    }

    // MARK: - 验证辅助

    /// 验证交易
    private nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let item):
            return item
        }
    }

    // MARK: - 本地缓存

    /// 缓存订阅状态到 UserDefaults（离线容错）
    private func cacheSubscriptionStatus() {
        switch subscriptionStatus {
        case .free:
            UserDefaults.standard.set("free", forKey: subscriptionStatusKey)
            UserDefaults.standard.removeObject(forKey: subscriptionExpiresKey)
        case .subscribed(let expiresAt):
            UserDefaults.standard.set("subscribed", forKey: subscriptionStatusKey)
            UserDefaults.standard.set(expiresAt.timeIntervalSince1970, forKey: subscriptionExpiresKey)
        case .expired:
            UserDefaults.standard.set("expired", forKey: subscriptionStatusKey)
            UserDefaults.standard.removeObject(forKey: subscriptionExpiresKey)
        }
    }

    /// 从 UserDefaults 恢复订阅状态
    private func loadCachedSubscriptionStatus() {
        let status = UserDefaults.standard.string(forKey: subscriptionStatusKey) ?? "free"
        switch status {
        case "subscribed":
            let expires = UserDefaults.standard.double(forKey: subscriptionExpiresKey)
            if expires > 0 {
                let expiresAt = Date(timeIntervalSince1970: expires)
                if expiresAt > Date() {
                    subscriptionStatus = .subscribed(expiresAt: expiresAt)
                    print("💰 [缓存] 从缓存恢复订阅状态，到期: \(expiresAt)")
                } else {
                    subscriptionStatus = .expired
                    print("💰 [缓存] 缓存的订阅已过期")
                }
            }
        case "expired":
            subscriptionStatus = .expired
        default:
            subscriptionStatus = .free
        }
    }

    // MARK: - 购买历史

    /// 从 Supabase 加载购买历史记录
    func loadPurchaseHistory() async {
        guard let userId = try? await supabase.auth.session.user.id else {
            print("💰 [购买历史] ⚠️ 未登录，跳过加载")
            return
        }

        var items: [PurchaseHistoryItem] = []

        // 查询消耗品购买记录
        do {
            let consumables: [DBConsumableFetch] = try await supabase
                .from("consumable_purchases")
                .select("id, product_id, purchased_at, consumed_at")
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            for record in consumables {
                let status: PurchaseHistoryStatus
                if record.productId == IAPProductID.resourceBox || record.productId == IAPProductID.legendaryCrate {
                    status = .consumableDelivered
                } else {
                    status = record.consumedAt == nil ? .consumableAvailable : .consumableDelivered
                }
                items.append(PurchaseHistoryItem(
                    id: record.id,
                    productId: record.productId,
                    purchasedAt: record.purchasedAt,
                    status: status
                ))
            }
        } catch {
            print("💰 [购买历史] ❌ 查询消耗品失败: \(error)")
        }

        // 查询订阅记录
        do {
            let subscriptions: [DBSubscriptionFetch] = try await supabase
                .from("user_subscriptions")
                .select("id, product_id, status, purchased_at, expires_at")
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            for record in subscriptions {
                let status: PurchaseHistoryStatus
                if record.status == "active" && record.expiresAt > Date() {
                    status = .subscriptionActive(expiresAt: record.expiresAt)
                } else {
                    status = .subscriptionExpired
                }
                items.append(PurchaseHistoryItem(
                    id: record.id,
                    productId: record.productId,
                    purchasedAt: record.purchasedAt,
                    status: status
                ))
            }
        } catch {
            print("💰 [购买历史] ❌ 查询订阅失败: \(error)")
        }

        // 按购买时间降序排列
        purchaseHistory = items.sorted { $0.purchasedAt > $1.purchasedAt }
        print("💰 [购买历史] ✅ 加载了 \(purchaseHistory.count) 条记录")
    }

    // MARK: - 便捷方法

    /// 获取订阅类商品
    var subscriptionProducts: [Product] {
        products.filter { IAPProductID.subscriptionIDs.contains($0.id) }
    }

    /// 获取消耗品商品
    var consumableProducts: [Product] {
        products.filter { IAPProductID.consumableIDs.contains($0.id) }
    }

    /// 获取月订阅商品
    var monthlyProduct: Product? {
        products.first { $0.id == IAPProductID.eliteMonthly }
    }

    /// 获取年订阅商品
    var annualProduct: Product? {
        products.first { $0.id == IAPProductID.eliteAnnual }
    }
}

// MARK: - 人民币价格格式化

extension Product {
    /// 以人民币格式显示价格（¥6.00）
    var cnyPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: price as NSDecimalNumber) ?? displayPrice
    }
}

// MARK: - 数据库模型

/// 订阅记录
struct DBSubscriptionRecord: Codable {
    let userId: UUID
    let productId: String
    let status: String
    let transactionId: String
    let originalTransactionId: String
    let purchasedAt: Date
    let expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case productId = "product_id"
        case status
        case transactionId = "transaction_id"
        case originalTransactionId = "original_transaction_id"
        case purchasedAt = "purchased_at"
        case expiresAt = "expires_at"
    }
}

/// 消耗品购买记录
struct DBConsumableRecord: Codable {
    let userId: UUID
    let productId: String
    let transactionId: String
    let purchasedAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case productId = "product_id"
        case transactionId = "transaction_id"
        case purchasedAt = "purchased_at"
    }
}

// MARK: - 购买历史模型

/// 购买历史展示模型
struct PurchaseHistoryItem: Identifiable {
    let id: UUID
    let productId: String
    let purchasedAt: Date
    let status: PurchaseHistoryStatus
}

enum PurchaseHistoryStatus {
    case subscriptionActive(expiresAt: Date)
    case subscriptionExpired
    case consumableAvailable   // 未使用（如即时建造卡）
    case consumableDelivered   // 已发放（资源箱、传奇箱购买即发放）
}

/// 消耗品购买记录查询模型
struct DBConsumableFetch: Codable, Identifiable {
    let id: UUID
    let productId: String
    let purchasedAt: Date
    let consumedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case productId = "product_id"
        case purchasedAt = "purchased_at"
        case consumedAt = "consumed_at"
    }
}

/// 订阅记录查询模型
struct DBSubscriptionFetch: Codable, Identifiable {
    let id: UUID
    let productId: String
    let status: String
    let purchasedAt: Date
    let expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case productId = "product_id"
        case status
        case purchasedAt = "purchased_at"
        case expiresAt = "expires_at"
    }
}
