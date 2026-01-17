//
//  MockExplorationData.swift
//  earthlord
//
//  探索模块测试假数据
//  用于 UI 开发和测试阶段，后续接入真实数据后可移除
//

import Foundation
import CoreLocation
import UIKit

// MARK: - ==================== 物品定义 ====================

/// 物品分类
/// 用于背包分类筛选和仓库整理
enum ItemCategory: String, CaseIterable, Codable {
    case water = "water"           // 水类
    case food = "food"             // 食物
    case medical = "medical"       // 医疗用品
    case material = "material"     // 材料
    case tool = "tool"             // 工具
    case weapon = "weapon"         // 武器
    case misc = "misc"             // 杂物

    /// 中文显示名称
    var displayName: String {
        switch self {
        case .water: return "水类"
        case .food: return "食物"
        case .medical: return "医疗"
        case .material: return "材料"
        case .tool: return "工具"
        case .weapon: return "武器"
        case .misc: return "杂物"
        }
    }

    /// 分类图标（SF Symbol）
    var iconName: String {
        switch self {
        case .water: return "drop.fill"
        case .food: return "fork.knife"
        case .medical: return "cross.case.fill"
        case .material: return "cube.fill"
        case .tool: return "wrench.and.screwdriver.fill"
        case .weapon: return "shield.fill"
        case .misc: return "archivebox.fill"
        }
    }
}

/// 物品稀有度
/// 影响物品的掉落概率和价值
enum ItemRarity: String, CaseIterable, Codable {
    case common = "common"         // 普通（白色）
    case uncommon = "uncommon"     // 优秀（绿色）
    case rare = "rare"             // 稀有（蓝色）
    case epic = "epic"             // 史诗（紫色）
    case legendary = "legendary"   // 传说（橙色）

    /// 中文显示名称
    var displayName: String {
        switch self {
        case .common: return "普通"
        case .uncommon: return "优秀"
        case .rare: return "稀有"
        case .epic: return "史诗"
        case .legendary: return "传说"
        }
    }

    /// 稀有度对应的颜色名称
    var colorName: String {
        switch self {
        case .common: return "gray"
        case .uncommon: return "green"
        case .rare: return "blue"
        case .epic: return "purple"
        case .legendary: return "orange"
        }
    }
}

/// 物品品质（消耗品专用）
/// 影响物品的使用效果，如食物的饱腹值、药品的治疗量
enum ItemQuality: String, CaseIterable, Codable {
    case damaged = "damaged"       // 损坏的（效果 50%）
    case worn = "worn"             // 磨损的（效果 75%）
    case normal = "normal"         // 正常（效果 100%）
    case pristine = "pristine"     // 完好的（效果 120%）

    /// 中文显示名称
    var displayName: String {
        switch self {
        case .damaged: return "损坏"
        case .worn: return "磨损"
        case .normal: return "正常"
        case .pristine: return "完好"
        }
    }

    /// 效果系数
    var effectMultiplier: Double {
        switch self {
        case .damaged: return 0.5
        case .worn: return 0.75
        case .normal: return 1.0
        case .pristine: return 1.2
        }
    }
}

// MARK: - 物品定义表

/// 物品定义（静态数据）
/// 描述物品的基础属性，不包含数量和品质
struct ItemDefinition: Identifiable, Codable {
    let id: String                 // 唯一标识符，如 "water_bottle"
    let name: String               // 中文名称
    let category: ItemCategory     // 物品分类
    let weight: Double             // 单位重量（kg）
    let volume: Double             // 单位体积（L）
    let rarity: ItemRarity         // 稀有度
    let description: String        // 物品描述
    let hasQuality: Bool           // 是否有品质属性（消耗品通常有）
    let isStackable: Bool          // 是否可堆叠
    let maxStack: Int              // 最大堆叠数量
}

// MARK: - ==================== 物品定义表数据 ====================

/// 物品定义表
/// 存储所有物品的基础属性，作为物品系统的数据源
struct MockItemDefinitions {

    /// 所有物品定义
    /// 按分类整理，便于查找和维护
    static let all: [ItemDefinition] = [

        // MARK: 水类
        ItemDefinition(
            id: "water_bottle",
            name: "矿泉水",
            category: .water,
            weight: 0.5,
            volume: 0.5,
            rarity: .common,
            description: "一瓶未开封的矿泉水，在末世中弥足珍贵。",
            hasQuality: true,
            isStackable: true,
            maxStack: 10
        ),
        ItemDefinition(
            id: "water_purified",
            name: "净化水",
            category: .water,
            weight: 0.5,
            volume: 0.5,
            rarity: .uncommon,
            description: "经过净化处理的饮用水，比普通水更安全。",
            hasQuality: false,
            isStackable: true,
            maxStack: 10
        ),

        // MARK: 食物
        ItemDefinition(
            id: "canned_food",
            name: "罐头食品",
            category: .food,
            weight: 0.4,
            volume: 0.3,
            rarity: .common,
            description: "保质期很长的罐头，打开后需尽快食用。",
            hasQuality: true,
            isStackable: true,
            maxStack: 10
        ),
        ItemDefinition(
            id: "energy_bar",
            name: "能量棒",
            category: .food,
            weight: 0.1,
            volume: 0.05,
            rarity: .uncommon,
            description: "高热量的压缩食品，体积小便于携带。",
            hasQuality: true,
            isStackable: true,
            maxStack: 20
        ),

        // MARK: 医疗用品
        ItemDefinition(
            id: "bandage",
            name: "绷带",
            category: .medical,
            weight: 0.1,
            volume: 0.05,
            rarity: .common,
            description: "用于包扎伤口的医用绷带。",
            hasQuality: true,
            isStackable: true,
            maxStack: 20
        ),
        ItemDefinition(
            id: "medicine",
            name: "药品",
            category: .medical,
            weight: 0.05,
            volume: 0.02,
            rarity: .rare,
            description: "治疗感染和疾病的药物，非常珍贵。",
            hasQuality: true,
            isStackable: true,
            maxStack: 10
        ),
        ItemDefinition(
            id: "first_aid_kit",
            name: "急救包",
            category: .medical,
            weight: 0.8,
            volume: 0.5,
            rarity: .rare,
            description: "包含多种医疗用品的急救包，可大幅恢复生命。",
            hasQuality: false,
            isStackable: true,
            maxStack: 5
        ),

        // MARK: 材料
        ItemDefinition(
            id: "wood",
            name: "木材",
            category: .material,
            weight: 2.0,
            volume: 1.5,
            rarity: .common,
            description: "建造和生火的基础材料。",
            hasQuality: false,
            isStackable: true,
            maxStack: 50
        ),
        ItemDefinition(
            id: "scrap_metal",
            name: "废金属",
            category: .material,
            weight: 1.5,
            volume: 0.5,
            rarity: .common,
            description: "可用于制作工具和武器的金属碎片。",
            hasQuality: false,
            isStackable: true,
            maxStack: 50
        ),
        ItemDefinition(
            id: "electronic_parts",
            name: "电子元件",
            category: .material,
            weight: 0.2,
            volume: 0.1,
            rarity: .uncommon,
            description: "从废弃设备中拆解的电子零件。",
            hasQuality: false,
            isStackable: true,
            maxStack: 30
        ),

        // MARK: 工具
        ItemDefinition(
            id: "flashlight",
            name: "手电筒",
            category: .tool,
            weight: 0.3,
            volume: 0.15,
            rarity: .uncommon,
            description: "照明工具，探索黑暗区域必备。",
            hasQuality: true,
            isStackable: false,
            maxStack: 1
        ),
        ItemDefinition(
            id: "rope",
            name: "绳子",
            category: .tool,
            weight: 0.5,
            volume: 0.3,
            rarity: .common,
            description: "多用途绳索，可用于攀爬和捆绑。",
            hasQuality: true,
            isStackable: true,
            maxStack: 5
        ),
        ItemDefinition(
            id: "lockpick",
            name: "撬锁器",
            category: .tool,
            weight: 0.05,
            volume: 0.01,
            rarity: .rare,
            description: "用于开启上锁的门和箱子。",
            hasQuality: true,
            isStackable: true,
            maxStack: 10
        )
    ]

    /// 根据 ID 查找物品定义
    static func find(by id: String) -> ItemDefinition? {
        return all.first { $0.id == id }
    }

    /// 根据分类筛选物品定义
    static func filter(by category: ItemCategory) -> [ItemDefinition] {
        return all.filter { $0.category == category }
    }
}

// MARK: - ==================== 背包物品 ====================

/// 背包物品（实例数据）
/// 表示玩家背包中的具体物品，包含数量和品质
struct BackpackItem: Identifiable, Codable {
    let id: UUID                   // 物品实例 ID（用于区分同类物品）
    let definitionId: String       // 物品定义 ID（关联 ItemDefinition）
    var quantity: Int              // 数量
    var quality: ItemQuality?      // 品质（可选，非消耗品无品质）

    /// 获取物品定义
    var definition: ItemDefinition? {
        MockItemDefinitions.find(by: definitionId)
    }

    /// 总重量（单位重量 × 数量）
    var totalWeight: Double {
        guard let def = definition else { return 0 }
        return def.weight * Double(quantity)
    }

    /// 总体积（单位体积 × 数量）
    var totalVolume: Double {
        guard let def = definition else { return 0 }
        return def.volume * Double(quantity)
    }
}

// MARK: - ==================== 背包假数据 ====================

/// 背包测试数据
/// 模拟玩家背包中的物品列表
struct MockBackpackData {

    /// 测试用背包物品列表
    /// 包含 8 种不同类型的物品，用于测试背包 UI
    static let items: [BackpackItem] = [
        // 水类：矿泉水 x3，正常品质
        BackpackItem(
            id: UUID(),
            definitionId: "water_bottle",
            quantity: 3,
            quality: .normal
        ),

        // 食物：罐头食品 x5，磨损品质
        BackpackItem(
            id: UUID(),
            definitionId: "canned_food",
            quantity: 5,
            quality: .worn
        ),

        // 食物：能量棒 x8，完好品质
        BackpackItem(
            id: UUID(),
            definitionId: "energy_bar",
            quantity: 8,
            quality: .pristine
        ),

        // 医疗：绷带 x10，正常品质
        BackpackItem(
            id: UUID(),
            definitionId: "bandage",
            quantity: 10,
            quality: .normal
        ),

        // 医疗：药品 x2，完好品质（稀有物品）
        BackpackItem(
            id: UUID(),
            definitionId: "medicine",
            quantity: 2,
            quality: .pristine
        ),

        // 材料：木材 x15，无品质
        BackpackItem(
            id: UUID(),
            definitionId: "wood",
            quantity: 15,
            quality: nil
        ),

        // 材料：废金属 x8，无品质
        BackpackItem(
            id: UUID(),
            definitionId: "scrap_metal",
            quantity: 8,
            quality: nil
        ),

        // 工具：手电筒 x1，磨损品质
        BackpackItem(
            id: UUID(),
            definitionId: "flashlight",
            quantity: 1,
            quality: .worn
        ),

        // 工具：绳子 x2，正常品质
        BackpackItem(
            id: UUID(),
            definitionId: "rope",
            quantity: 2,
            quality: .normal
        )
    ]

    /// 计算背包总重量
    static var totalWeight: Double {
        items.reduce(0) { $0 + $1.totalWeight }
    }

    /// 计算背包总体积
    static var totalVolume: Double {
        items.reduce(0) { $0 + $1.totalVolume }
    }

    /// 背包容量上限（kg）
    static let weightCapacity: Double = 30.0

    /// 背包体积上限（L）
    static let volumeCapacity: Double = 25.0
}

// MARK: - ==================== POI 兴趣点 ====================

/// POI 发现状态
enum POIDiscoveryStatus: String, Codable {
    case undiscovered = "undiscovered"   // 未发现（地图上不显示或显示为问号）
    case discovered = "discovered"        // 已发现（显示在地图上）
    case explored = "explored"            // 已探索（已搜刮过）
}

/// POI 资源状态
enum POIResourceStatus: String, Codable {
    case unknown = "unknown"              // 未知（未探索）
    case hasResources = "has_resources"   // 有物资
    case looted = "looted"                // 已被搜空
}

/// POI 类型
enum POIType: String, Codable {
    case supermarket = "supermarket"      // 超市
    case hospital = "hospital"            // 医院
    case gasStation = "gas_station"       // 加油站
    case pharmacy = "pharmacy"            // 药店
    case factory = "factory"              // 工厂
    case warehouse = "warehouse"          // 仓库
    case house = "house"                  // 民宅
    case police = "police"                // 警察局
    case military = "military"            // 军事设施
    case restaurant = "restaurant"        // 餐厅
    case cafe = "cafe"                    // 咖啡店

    /// 中文显示名称
    var displayName: String {
        switch self {
        case .supermarket: return "超市"
        case .hospital: return "医院"
        case .gasStation: return "加油站"
        case .pharmacy: return "药店"
        case .factory: return "工厂"
        case .warehouse: return "仓库"
        case .house: return "民宅"
        case .police: return "警察局"
        case .military: return "军事设施"
        case .restaurant: return "餐厅"
        case .cafe: return "咖啡店"
        }
    }

    /// POI 图标（SF Symbol）
    var iconName: String {
        switch self {
        case .supermarket: return "cart.fill"
        case .hospital: return "cross.fill"
        case .gasStation: return "fuelpump.fill"
        case .pharmacy: return "pills.fill"
        case .factory: return "building.2.fill"
        case .warehouse: return "shippingbox.fill"
        case .house: return "house.fill"
        case .police: return "shield.lefthalf.filled"
        case .military: return "star.fill"
        case .restaurant: return "fork.knife"
        case .cafe: return "cup.and.saucer.fill"
        }
    }

    /// 地图标记颜色
    var markerColor: UIColor {
        switch self {
        case .supermarket: return .systemGreen
        case .hospital: return .systemRed
        case .gasStation: return .systemOrange
        case .pharmacy: return .systemPink
        case .factory: return .systemGray
        case .warehouse: return .systemBrown
        case .house: return .systemTeal
        case .police: return .systemBlue
        case .military: return .systemPurple
        case .restaurant: return .systemYellow
        case .cafe: return .brown
        }
    }
}

/// 兴趣点（POI）
/// 地图上可探索的地点
struct POI: Identifiable, Codable, Equatable {
    let id: UUID                           // 唯一标识
    let name: String                       // 地点名称
    let type: POIType                      // POI 类型
    let coordinate: CLLocationCoordinate2D // 坐标位置
    var discoveryStatus: POIDiscoveryStatus // 发现状态
    var resourceStatus: POIResourceStatus   // 资源状态
    let dangerLevel: Int                   // 危险等级（1-5）
    let description: String                // 地点描述

    // MARK: - Codable for CLLocationCoordinate2D

    enum CodingKeys: String, CodingKey {
        case id, name, type, latitude, longitude
        case discoveryStatus, resourceStatus, dangerLevel, description
    }

    init(
        id: UUID = UUID(),
        name: String,
        type: POIType,
        coordinate: CLLocationCoordinate2D,
        discoveryStatus: POIDiscoveryStatus,
        resourceStatus: POIResourceStatus,
        dangerLevel: Int,
        description: String
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.coordinate = coordinate
        self.discoveryStatus = discoveryStatus
        self.resourceStatus = resourceStatus
        self.dangerLevel = dangerLevel
        self.description = description
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(POIType.self, forKey: .type)
        let lat = try container.decode(Double.self, forKey: .latitude)
        let lon = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        discoveryStatus = try container.decode(POIDiscoveryStatus.self, forKey: .discoveryStatus)
        resourceStatus = try container.decode(POIResourceStatus.self, forKey: .resourceStatus)
        dangerLevel = try container.decode(Int.self, forKey: .dangerLevel)
        description = try container.decode(String.self, forKey: .description)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
        try container.encode(discoveryStatus, forKey: .discoveryStatus)
        try container.encode(resourceStatus, forKey: .resourceStatus)
        try container.encode(dangerLevel, forKey: .dangerLevel)
        try container.encode(description, forKey: .description)
    }

    // MARK: - Equatable

    static func == (lhs: POI, rhs: POI) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.type == rhs.type &&
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude &&
        lhs.discoveryStatus == rhs.discoveryStatus &&
        lhs.resourceStatus == rhs.resourceStatus &&
        lhs.dangerLevel == rhs.dangerLevel &&
        lhs.description == rhs.description
    }
}

// MARK: - ==================== POI 假数据 ====================

/// POI 测试数据
/// 包含 5 个不同状态的兴趣点，用于测试地图和探索 UI
struct MockPOIData {

    /// 测试用 POI 列表
    /// 坐标设置在北京市区附近，方便模拟器测试
    static let pois: [POI] = [
        // 1. 废弃超市：已发现，有物资
        POI(
            name: "废弃超市",
            type: .supermarket,
            coordinate: CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074),
            discoveryStatus: .discovered,
            resourceStatus: .hasResources,
            dangerLevel: 2,
            description: "一家被遗弃的大型超市，货架上可能还有些食物和水。"
        ),

        // 2. 医院废墟：已发现，已被搜空
        POI(
            name: "医院废墟",
            type: .hospital,
            coordinate: CLLocationCoordinate2D(latitude: 39.9142, longitude: 116.4174),
            discoveryStatus: .discovered,
            resourceStatus: .looted,
            dangerLevel: 4,
            description: "曾经救死扶伤的医院，如今只剩断壁残垣。药品已被搜刮一空。"
        ),

        // 3. 加油站：未发现
        POI(
            name: "加油站",
            type: .gasStation,
            coordinate: CLLocationCoordinate2D(latitude: 39.8942, longitude: 116.3974),
            discoveryStatus: .undiscovered,
            resourceStatus: .unknown,
            dangerLevel: 3,
            description: "路边的加油站，可能还有燃料和便利店物资。"
        ),

        // 4. 药店废墟：已发现，有物资
        POI(
            name: "药店废墟",
            type: .pharmacy,
            coordinate: CLLocationCoordinate2D(latitude: 39.9092, longitude: 116.4024),
            discoveryStatus: .discovered,
            resourceStatus: .hasResources,
            dangerLevel: 2,
            description: "街角的药店，柜台后面可能藏着珍贵的药品。"
        ),

        // 5. 工厂废墟：未发现
        POI(
            name: "工厂废墟",
            type: .factory,
            coordinate: CLLocationCoordinate2D(latitude: 39.8892, longitude: 116.4274),
            discoveryStatus: .undiscovered,
            resourceStatus: .unknown,
            dangerLevel: 5,
            description: "郊区的废弃工厂，可能有大量金属材料和机械零件。危险等级较高。"
        )
    ]

    /// 获取已发现的 POI
    static var discoveredPOIs: [POI] {
        pois.filter { $0.discoveryStatus != .undiscovered }
    }

    /// 获取有物资的 POI
    static var resourcefulPOIs: [POI] {
        pois.filter { $0.resourceStatus == .hasResources }
    }
}

// MARK: - ==================== 探索结果 ====================

/// 探索获得的物品
struct ExplorationLoot: Identifiable, Codable {
    let id: UUID
    let itemId: String             // 物品定义 ID
    let quantity: Int              // 获得数量
    let quality: ItemQuality?      // 品质（可选）

    // MARK: - AI 生成字段

    /// 是否为 AI 生成的物品
    var isAIGenerated: Bool = false

    /// AI 生成的物品名称
    var aiName: String?

    /// AI 生成的物品分类
    var aiCategory: String?

    /// AI 生成的物品稀有度
    var aiRarity: String?

    /// AI 生成的背景故事
    var aiStory: String?

    // MARK: - 计算属性

    /// 获取物品定义（仅对非 AI 物品有效）
    var definition: ItemDefinition? {
        MockItemDefinitions.find(by: itemId)
    }

    /// 显示名称（优先使用 AI 名称）
    var displayName: String {
        if let aiName = aiName, !aiName.isEmpty {
            return aiName
        }
        return definition?.name ?? "未知物品"
    }

    /// 显示稀有度（优先使用 AI 稀有度）
    var displayRarity: ItemRarity {
        if let aiRarity = aiRarity {
            return ItemRarity(rawValue: aiRarity) ?? .common
        }
        return definition?.rarity ?? .common
    }
}

/// 探索结果统计
/// 记录单次探索的成果
struct ExplorationResult: Identifiable, Codable {
    let id: UUID                   // 探索记录 ID
    let startTime: Date            // 开始时间
    let endTime: Date              // 结束时间
    let distanceWalked: Double     // 行走距离（米）
    let loot: [ExplorationLoot]    // 获得的物品

    /// 探索时长（秒）
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    /// 格式化时长
    var formattedDuration: String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        return String(format: "%d分%02d秒", minutes, seconds)
    }

    /// 格式化距离
    var formattedDistance: String {
        if distanceWalked >= 1000 {
            return String(format: "%.2f km", distanceWalked / 1000)
        } else {
            return String(format: "%.0f m", distanceWalked)
        }
    }
}

/// 累计探索统计
/// 记录玩家的历史探索数据
struct ExplorationStats: Codable {
    var totalDistance: Double       // 累计行走距离（米）
    var totalDuration: TimeInterval // 累计探索时长（秒）
    var totalLootCount: Int         // 累计获得物品数量

    /// 格式化累计距离
    var formattedTotalDistance: String {
        if totalDistance >= 1000 {
            return String(format: "%.2f km", totalDistance / 1000)
        } else {
            return String(format: "%.0f m", totalDistance)
        }
    }

    /// 格式化累计时长
    var formattedTotalDuration: String {
        let hours = Int(totalDuration / 3600)
        let minutes = Int((totalDuration.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours > 0 {
            return String(format: "%d小时%d分", hours, minutes)
        } else {
            return String(format: "%d分钟", minutes)
        }
    }
}

// MARK: - ==================== 探索结果假数据 ====================

/// 探索结果测试数据
struct MockExplorationResultData {

    /// 本次探索获得的物品
    static let currentLoot: [ExplorationLoot] = [
        ExplorationLoot(
            id: UUID(),
            itemId: "wood",
            quantity: 5,
            quality: nil
        ),
        ExplorationLoot(
            id: UUID(),
            itemId: "water_bottle",
            quantity: 3,
            quality: .normal
        ),
        ExplorationLoot(
            id: UUID(),
            itemId: "canned_food",
            quantity: 2,
            quality: .worn
        ),
        ExplorationLoot(
            id: UUID(),
            itemId: "scrap_metal",
            quantity: 4,
            quality: nil
        )
    ]

    /// 本次探索结果示例
    /// 行走 2500 米，耗时 30 分钟
    static let currentResult: ExplorationResult = ExplorationResult(
        id: UUID(),
        startTime: Date().addingTimeInterval(-1800), // 30 分钟前
        endTime: Date(),
        distanceWalked: 2500,          // 本次 2500 米
        loot: currentLoot
    )

    /// 累计探索统计示例
    /// 累计 15 公里，10 小时
    static let stats: ExplorationStats = ExplorationStats(
        totalDistance: 15000,          // 累计 15 公里
        totalDuration: 36000,          // 累计 10 小时
        totalLootCount: 156            // 累计获得 156 件物品
    )
}
