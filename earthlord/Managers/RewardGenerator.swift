//
//  RewardGenerator.swift
//  earthlord
//
//  奖励生成器
//  根据探索距离生成随机掉落物品
//

import Foundation

// MARK: - 奖励等级

/// 奖励等级
/// 根据行走距离划分
enum RewardTier: String, Codable {
    case none = "none"          // 无奖励 (0-200m)
    case bronze = "bronze"      // 铜级 (200-500m)
    case silver = "silver"      // 银级 (500-1000m)
    case gold = "gold"          // 金级 (1000-2000m)
    case diamond = "diamond"    // 钻石级 (2000m+)

    /// 根据距离判断等级
    static func from(distance: Double) -> RewardTier {
        switch distance {
        case ..<200: return .none
        case 200..<500: return .bronze
        case 500..<1000: return .silver
        case 1000..<2000: return .gold
        default: return .diamond
        }
    }

    /// 物品掉落数量
    var itemCount: Int {
        switch self {
        case .none: return 0
        case .bronze: return 1
        case .silver: return 2
        case .gold: return 3
        case .diamond: return 5
        }
    }

    /// 中文显示名
    var displayName: String {
        switch self {
        case .none: return "无奖励"
        case .bronze: return "铜级"
        case .silver: return "银级"
        case .gold: return "金级"
        case .diamond: return "钻石级"
        }
    }

    /// 图标
    var iconName: String {
        switch self {
        case .none: return "xmark.circle"
        case .bronze: return "medal.fill"
        case .silver: return "medal.fill"
        case .gold: return "medal.fill"
        case .diamond: return "diamond.fill"
        }
    }

    /// 颜色名称
    var colorName: String {
        switch self {
        case .none: return "gray"
        case .bronze: return "brown"
        case .silver: return "gray"
        case .gold: return "yellow"
        case .diamond: return "cyan"
        }
    }
}

// MARK: - 奖励生成器

/// 奖励生成器
/// 根据等级和概率生成随机物品掉落
class RewardGenerator {

    // MARK: - 单例
    static let shared = RewardGenerator()

    // MARK: - 等级对应的稀有度概率表

    /// 铜级概率：普通90%, 优秀10%, 稀有0%, 史诗0%, 传说0%
    private let bronzeProbabilities: [ItemRarity: Double] = [
        .common: 0.90,
        .uncommon: 0.10,
        .rare: 0.00,
        .epic: 0.00,
        .legendary: 0.00
    ]

    /// 银级概率：普通70%, 优秀25%, 稀有5%, 史诗0%, 传说0%
    private let silverProbabilities: [ItemRarity: Double] = [
        .common: 0.70,
        .uncommon: 0.25,
        .rare: 0.05,
        .epic: 0.00,
        .legendary: 0.00
    ]

    /// 金级概率：普通50%, 优秀35%, 稀有15%, 史诗0%, 传说0%
    private let goldProbabilities: [ItemRarity: Double] = [
        .common: 0.50,
        .uncommon: 0.35,
        .rare: 0.15,
        .epic: 0.00,
        .legendary: 0.00
    ]

    /// 钻石级概率：普通30%, 优秀40%, 稀有25%, 史诗5%, 传说0%
    private let diamondProbabilities: [ItemRarity: Double] = [
        .common: 0.30,
        .uncommon: 0.40,
        .rare: 0.25,
        .epic: 0.05,
        .legendary: 0.00
    ]

    // MARK: - 物品池（按稀有度分类）

    /// 按稀有度分类的物品池
    private var itemPoolByRarity: [ItemRarity: [ItemDefinition]] {
        var pool: [ItemRarity: [ItemDefinition]] = [:]
        for rarity in ItemRarity.allCases {
            pool[rarity] = MockItemDefinitions.all.filter { $0.rarity == rarity }
        }
        return pool
    }

    // MARK: - 初始化

    private init() {
        print("🎁 [RewardGenerator] 初始化")
    }

    // MARK: - 公开方法

    /// 根据奖励等级生成掉落物品
    /// - Parameter tier: 奖励等级
    /// - Returns: 掉落物品数组
    func generateLoot(tier: RewardTier) -> [ExplorationLoot] {
        let itemCount = tier.itemCount
        guard itemCount > 0 else { return [] }

        var loot: [ExplorationLoot] = []
        let probabilities = getProbabilities(for: tier)

        for _ in 0..<itemCount {
            if let item = generateSingleItem(probabilities: probabilities) {
                loot.append(item)
            }
        }

        print("🎁 [RewardGenerator] 等级 \(tier.displayName)，生成 \(loot.count) 件物品")
        return loot
    }

    // MARK: - 私有方法

    /// 获取等级对应的概率表
    private func getProbabilities(for tier: RewardTier) -> [ItemRarity: Double] {
        switch tier {
        case .none: return [:]
        case .bronze: return bronzeProbabilities
        case .silver: return silverProbabilities
        case .gold: return goldProbabilities
        case .diamond: return diamondProbabilities
        }
    }

    /// 生成单个物品
    private func generateSingleItem(probabilities: [ItemRarity: Double]) -> ExplorationLoot? {
        // 根据概率选择稀有度
        let selectedRarity = selectRarity(probabilities: probabilities)

        // 从该稀有度的物品池中随机选择
        guard let pool = itemPoolByRarity[selectedRarity],
              !pool.isEmpty,
              let selectedItem = pool.randomElement() else {
            // 如果该稀有度没有物品，降级到普通
            if let commonPool = itemPoolByRarity[.common],
               let fallbackItem = commonPool.randomElement() {
                return createLoot(from: fallbackItem)
            }
            return nil
        }

        return createLoot(from: selectedItem)
    }

    /// 根据物品定义创建掉落物品
    private func createLoot(from item: ItemDefinition) -> ExplorationLoot {
        // 生成数量
        let quantity = generateQuantity(for: item)

        // 生成品质（如果物品有品质属性）
        let quality = item.hasQuality ? generateQuality() : nil

        return ExplorationLoot(
            id: UUID(),
            itemId: item.id,
            quantity: quantity,
            quality: quality
        )
    }

    /// 根据概率选择稀有度
    private func selectRarity(probabilities: [ItemRarity: Double]) -> ItemRarity {
        let random = Double.random(in: 0..<1)
        var cumulative: Double = 0

        // 按稀有度顺序累积概率
        let orderedRarities: [ItemRarity] = [.common, .uncommon, .rare, .epic, .legendary]

        for rarity in orderedRarities {
            cumulative += probabilities[rarity] ?? 0
            if random < cumulative {
                return rarity
            }
        }

        return .common // 兜底返回普通
    }

    /// 生成数量
    private func generateQuantity(for item: ItemDefinition) -> Int {
        // 稀有物品通常只有1个
        switch item.rarity {
        case .legendary, .epic:
            return 1
        case .rare:
            return Int.random(in: 1...2)
        case .uncommon:
            return Int.random(in: 1...3)
        case .common:
            // 材料类可能更多
            if item.category == .material {
                return Int.random(in: 2...5)
            }
            return Int.random(in: 1...3)
        }
    }

    /// 生成品质
    private func generateQuality() -> ItemQuality {
        let random = Double.random(in: 0..<1)

        switch random {
        case 0..<0.10:
            return .damaged
        case 0.10..<0.35:
            return .worn
        case 0.35..<0.85:
            return .normal
        default:
            return .pristine
        }
    }
}
