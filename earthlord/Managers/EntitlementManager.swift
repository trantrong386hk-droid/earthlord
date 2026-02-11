//
//  EntitlementManager.swift
//  earthlord
//
//  权益管理器
//  负责检查用户权益、每日限制、付费墙触发
//

import Foundation
import Combine
import Supabase

// MARK: - 付费墙触发原因

enum PaywallReason {
    case explorationLimit       // 探索次数用尽
    case territoryLimit         // 圈地次数用尽
    case poiScavengeLimit       // POI 搜刮次数用尽
    case backpackFull           // 背包满了
    case buildSpeedBoost        // 建造加速
    case explorationRewardBoost // 探索奖励加成

    var title: String {
        switch self {
        case .explorationLimit:
            return "今日探索次数已用尽".localized
        case .territoryLimit:
            return "今日圈地次数已用尽".localized
        case .poiScavengeLimit:
            return "今日搜刮次数已用尽".localized
        case .backpackFull:
            return "背包容量不足".localized
        case .buildSpeedBoost:
            return "建造等待中".localized
        case .explorationRewardBoost:
            return "获取更多奖励".localized
        }
    }

    var subtitle: String {
        switch self {
        case .explorationLimit:
            return "升级精英幸存者，享受无限探索".localized
        case .territoryLimit:
            return "升级精英幸存者，享受无限圈地".localized
        case .poiScavengeLimit:
            return "升级精英幸存者，享受无限搜刮".localized
        case .backpackFull:
            return "升级精英幸存者，背包扩容至 50kg/40L".localized
        case .buildSpeedBoost:
            return "精英幸存者建造速度 2 倍，或使用即时建造卡".localized
        case .explorationRewardBoost:
            return "精英幸存者探索奖励 +50%".localized
        }
    }
}

// MARK: - 每日动作类型

enum DailyAction {
    case exploration
    case territoryClaim
    case poiScavenge
}

// MARK: - EntitlementManager

@MainActor
class EntitlementManager: ObservableObject {

    // MARK: - 单例

    static let shared = EntitlementManager()

    // MARK: - 发布属性

    /// 是否显示付费墙
    @Published var showPaywall: Bool = false

    /// 付费墙触发原因
    @Published var paywallReason: PaywallReason?

    /// 今日探索次数
    @Published var dailyExplorationCount: Int = 0

    /// 今日圈地次数
    @Published var dailyTerritoryClaimCount: Int = 0

    /// 今日 POI 搜刮次数
    @Published var dailyPOIScavengeCount: Int = 0

    // MARK: - 常量（免费玩家限制）

    private let freeExplorationLimit = 3
    private let freeTerritoryClaimLimit = 5
    private let freePOIScavengeLimit = 10

    // MARK: - 私有属性

    private var cancellables = Set<AnyCancellable>()
    private let dailyResetKey = "entitlement_daily_reset_date"

    // MARK: - 初始化

    private init() {
        print("🔐 [EntitlementManager] 初始化")
        checkDailyReset()
        loadDailyCounts()

        // 监听订阅状态变化
        StoreKitManager.shared.$subscriptionStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    // MARK: - 订阅状态便捷属性

    /// 当前是否为订阅用户
    var isSubscribed: Bool {
        StoreKitManager.shared.subscriptionStatus.isSubscribed
    }

    // MARK: - 容量属性

    /// 背包重量上限（kg）
    var backpackWeightCapacity: Double {
        isSubscribed ? 50.0 : 30.0
    }

    /// 背包体积上限（L）
    var backpackVolumeCapacity: Double {
        isSubscribed ? 40.0 : 25.0
    }

    // MARK: - 倍率属性

    /// 建造时间倍率（0.5 = 2 倍速）
    var buildTimeMultiplier: Double {
        isSubscribed ? 0.5 : 1.0
    }

    /// 探索奖励倍率
    var explorationLootMultiplier: Double {
        var multiplier = isSubscribed ? 1.5 : 1.0

        // 检查探索增幅器（24h）
        if isExplorationBoostActive {
            multiplier *= 2.0
        }

        return multiplier
    }

    /// 通讯范围加成（0.2 = +20%）
    var communicationRangeBonus: Double {
        isSubscribed ? 0.2 : 0.0
    }

    /// 交易手续费率
    var tradeFeeRate: Double {
        isSubscribed ? 0.0 : 0.05
    }

    // MARK: - 探索增幅器

    /// 探索增幅器是否有效
    var isExplorationBoostActive: Bool {
        let purchasedAt = UserDefaults.standard.double(forKey: "exploration_boost_purchased_at")
        guard purchasedAt > 0 else { return false }
        let elapsed = Date().timeIntervalSince1970 - purchasedAt
        return elapsed < 24 * 60 * 60  // 24 小时内有效
    }

    // MARK: - 每日限制检查

    /// 是否可以探索
    func canExplore() -> Bool {
        if isSubscribed { return true }
        return dailyExplorationCount < freeExplorationLimit
    }

    /// 是否可以圈地
    func canClaimTerritory() -> Bool {
        if isSubscribed { return true }
        return dailyTerritoryClaimCount < freeTerritoryClaimLimit
    }

    /// 是否可以搜刮 POI
    func canScavengePOI() -> Bool {
        if isSubscribed { return true }
        return dailyPOIScavengeCount < freePOIScavengeLimit
    }

    /// 增加每日计数
    func incrementDailyCount(for action: DailyAction) {
        switch action {
        case .exploration:
            dailyExplorationCount += 1
            UserDefaults.standard.set(dailyExplorationCount, forKey: "daily_exploration_count")
        case .territoryClaim:
            dailyTerritoryClaimCount += 1
            UserDefaults.standard.set(dailyTerritoryClaimCount, forKey: "daily_territory_claim_count")
        case .poiScavenge:
            dailyPOIScavengeCount += 1
            UserDefaults.standard.set(dailyPOIScavengeCount, forKey: "daily_poi_scavenge_count")
        }

        // 同步到数据库
        Task { await syncDailyCountsToSupabase() }
    }

    /// 触发付费墙
    func triggerPaywall(reason: PaywallReason) {
        paywallReason = reason
        showPaywall = true
    }

    // MARK: - 剩余次数

    /// 剩余探索次数（-1 = 无限）
    var remainingExplorations: Int {
        if isSubscribed { return -1 }
        return max(0, freeExplorationLimit - dailyExplorationCount)
    }

    /// 剩余圈地次数（-1 = 无限）
    var remainingTerritoryClaims: Int {
        if isSubscribed { return -1 }
        return max(0, freeTerritoryClaimLimit - dailyTerritoryClaimCount)
    }

    /// 剩余 POI 搜刮次数（-1 = 无限）
    var remainingPOIScavenges: Int {
        if isSubscribed { return -1 }
        return max(0, freePOIScavengeLimit - dailyPOIScavengeCount)
    }

    // MARK: - 每日重置

    /// 检查是否需要重置每日计数
    private func checkDailyReset() {
        let calendar = Calendar.current
        let lastReset = UserDefaults.standard.object(forKey: dailyResetKey) as? Date ?? Date.distantPast

        if !calendar.isDateInToday(lastReset) {
            // 重置每日计数
            dailyExplorationCount = 0
            dailyTerritoryClaimCount = 0
            dailyPOIScavengeCount = 0

            UserDefaults.standard.set(0, forKey: "daily_exploration_count")
            UserDefaults.standard.set(0, forKey: "daily_territory_claim_count")
            UserDefaults.standard.set(0, forKey: "daily_poi_scavenge_count")
            UserDefaults.standard.set(Date(), forKey: dailyResetKey)

            print("🔐 [EntitlementManager] 每日计数已重置")
        }
    }

    /// 从 UserDefaults 加载每日计数
    private func loadDailyCounts() {
        dailyExplorationCount = UserDefaults.standard.integer(forKey: "daily_exploration_count")
        dailyTerritoryClaimCount = UserDefaults.standard.integer(forKey: "daily_territory_claim_count")
        dailyPOIScavengeCount = UserDefaults.standard.integer(forKey: "daily_poi_scavenge_count")
    }

    /// 同步每日计数到 Supabase
    private func syncDailyCountsToSupabase() async {
        guard let userId = try? await supabase.auth.session.user.id else { return }

        let update = DailyCountsUpdate(
            dailyExplorationCount: dailyExplorationCount,
            dailyTerritoryClaims: dailyTerritoryClaimCount,
            dailyPoiScavenges: dailyPOIScavengeCount,
            dailyResetAt: Date()
        )

        do {
            try await supabase
                .from("user_exploration_stats")
                .update(update)
                .eq("user_id", value: userId.uuidString)
                .execute()
        } catch {
            print("🔐 [EntitlementManager] ⚠️ 同步每日计数失败: \(error)")
        }
    }
}

// MARK: - 数据库模型

/// 每日计数更新
private struct DailyCountsUpdate: Codable {
    let dailyExplorationCount: Int
    let dailyTerritoryClaims: Int
    let dailyPoiScavenges: Int
    let dailyResetAt: Date

    enum CodingKeys: String, CodingKey {
        case dailyExplorationCount = "daily_exploration_count"
        case dailyTerritoryClaims = "daily_territory_claims"
        case dailyPoiScavenges = "daily_poi_scavenges"
        case dailyResetAt = "daily_reset_at"
    }
}
