//
//  InventoryManager.swift
//  earthlord
//
//  背包管理器
//  负责玩家背包物品的增删改查和 Supabase 同步
//

import Foundation
import Combine
import Supabase

// MARK: - InventoryManager

@MainActor
class InventoryManager: ObservableObject {

    // MARK: - 单例
    static let shared = InventoryManager()

    // MARK: - 发布属性

    /// 背包物品列表
    @Published var items: [BackpackItem] = []

    /// 数据库物品定义缓存（UUID -> 物品信息）
    @Published var itemDefinitionsCache: [UUID: DBItemDefinition] = [:]

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - 计算属性

    /// 背包总重量
    var totalWeight: Double {
        items.reduce(0) { $0 + $1.totalWeight }
    }

    /// 背包总体积
    var totalVolume: Double {
        items.reduce(0) { $0 + $1.totalVolume }
    }

    /// 背包容量上限（kg）
    let weightCapacity: Double = 30.0

    /// 背包体积上限（L）
    let volumeCapacity: Double = 25.0

    // MARK: - 初始化

    private init() {
        print("🎒 [InventoryManager] 初始化")
    }

    // MARK: - 公开方法

    /// 加载数据库物品定义缓存
    func loadItemDefinitions() async {
        do {
            let response: [DBItemDefinition] = try await supabase
                .from("items")
                .select()
                .execute()
                .value

            itemDefinitionsCache = Dictionary(uniqueKeysWithValues: response.map { ($0.id, $0) })
            print("🎒 [背包] 加载了 \(itemDefinitionsCache.count) 个物品定义")
        } catch {
            print("🎒 [背包] 加载物品定义失败: \(error)")
        }
    }

    /// 加载用户背包
    func loadInventory() async {
        // 如果已经在加载中，跳过
        guard !isLoading else {
            print("🎒 [背包] 已在加载中，跳过")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // 确保物品定义已加载
            if itemDefinitionsCache.isEmpty {
                await loadItemDefinitions()
            }

            guard let userId = try? await supabase.auth.session.user.id else {
                throw InventoryError.notAuthenticated
            }

            let response: [DBUserItem] = try await supabase
                .from("user_items")
                .select("id, user_id, item_id, quantity, acquired_at, acquired_from, is_ai_generated, ai_name, ai_category, ai_rarity, ai_story")
                .eq("user_id", value: userId.uuidString)
                .order("acquired_at", ascending: false)
                .execute()
                .value

            print("🎒 [背包] 从数据库加载了 \(response.count) 条记录")

            // 转换为 BackpackItem
            let newItems = response.compactMap { dbItem -> BackpackItem? in
                // AI 生成物品
                if dbItem.isAIGenerated == true {
                    return BackpackItem(
                        id: dbItem.id,
                        definitionId: "ai_generated",
                        quantity: dbItem.quantity,
                        quality: nil,
                        isAIGenerated: true,
                        aiName: dbItem.aiName,
                        aiCategory: dbItem.aiCategory,
                        aiRarity: dbItem.aiRarity,
                        aiStory: dbItem.aiStory
                    )
                }

                // 普通物品：查找数据库物品定义
                guard let dbDef = itemDefinitionsCache[dbItem.itemId] else {
                    return nil
                }

                // 映射到本地 definitionId（通过名称匹配）
                let localDefId = mapToLocalDefinitionId(dbName: dbDef.name)

                return BackpackItem(
                    id: dbItem.id,
                    definitionId: localDefId,
                    quantity: dbItem.quantity,
                    quality: nil,  // 数据库暂不支持品质
                    isAIGenerated: false,
                    aiName: nil,
                    aiCategory: nil,
                    aiRarity: nil,
                    aiStory: nil
                )
            }

            // 更新 items
            items = newItems
            print("🎒 [背包] ✅ 加载完成，共 \(items.count) 种物品")

            // 验证第一个 AI 物品
            if let firstAI = items.first(where: { $0.isAIGenerated }) {
                print("🎒 [背包] 🔍 验证首个AI物品: aiName=\(firstAI.aiName ?? "nil")")
            }

        } catch {
            errorMessage = error.localizedDescription
            print("🎒 [背包] ❌ 加载失败: \(error)")
        }

        isLoading = false
    }

    /// 添加物品（从探索获得）
    /// - Parameters:
    ///   - loot: 掉落物品数组
    ///   - sourceType: 来源类型
    ///   - sourceId: 来源ID
    func addItems(_ loot: [ExplorationLoot], sourceType: String, sourceId: UUID) async throws {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw InventoryError.notAuthenticated
        }

        // 确保物品定义已加载
        if itemDefinitionsCache.isEmpty {
            await loadItemDefinitions()
        }

        // 1. 先查询用户现有物品
        let existingItems: [DBUserItem] = try await supabase
            .from("user_items")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        // 构建现有物品映射（itemId -> 现有记录）
        var existingMap: [UUID: DBUserItem] = [:]
        for item in existingItems {
            existingMap[item.itemId] = item
        }

        // 2. 处理每个新物品
        for item in loot {
            // 🆕 检查是否为 AI 生成物品
            if item.isAIGenerated {
                // AI 物品：每个都是独特的，不能叠加，使用占位符 UUID
                let placeholderUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
                let upload = DBUserItemUpload(
                    userId: userId,
                    itemId: placeholderUUID,
                    quantity: item.quantity,
                    acquiredFrom: sourceType,
                    isAIGenerated: true,
                    aiName: item.aiName,
                    aiCategory: item.aiCategory,
                    aiRarity: item.aiRarity,
                    aiStory: item.aiStory
                )
                try await supabase
                    .from("user_items")
                    .insert(upload)
                    .execute()
                print("🎒 [背包] 插入 AI 物品: \(item.aiName ?? "未知") x\(item.quantity)")
            } else {
                // 普通物品：按原逻辑处理
                guard let dbItemId = findDBItemId(localId: item.itemId) else {
                    print("🎒 [背包] 未找到数据库物品: \(item.itemId)")
                    continue
                }

                if let existing = existingMap[dbItemId] {
                    // 物品已存在，更新数量
                    let newQuantity = existing.quantity + item.quantity
                    let updateData = DBUserItemUpdate(quantity: newQuantity)
                    try await supabase
                        .from("user_items")
                        .update(updateData)
                        .eq("id", value: existing.id.uuidString)
                        .execute()
                    print("🎒 [背包] 更新物品数量: +\(item.quantity) -> \(newQuantity)")
                } else {
                    // 物品不存在，插入新记录
                    let upload = DBUserItemUpload(
                        userId: userId,
                        itemId: dbItemId,
                        quantity: item.quantity,
                        acquiredFrom: sourceType,
                        isAIGenerated: false,
                        aiName: nil,
                        aiCategory: nil,
                        aiRarity: nil,
                        aiStory: nil
                    )
                    try await supabase
                        .from("user_items")
                        .insert(upload)
                        .execute()
                    print("🎒 [背包] 插入新物品: \(item.itemId) x\(item.quantity)")
                }
            }
        }

        print("🎒 [背包] 添加物品完成")

        // 重新加载背包
        await loadInventory()
    }

    /// 使用物品
    /// - Parameters:
    ///   - itemId: 物品实例ID
    ///   - quantity: 使用数量
    func useItem(itemId: UUID, quantity: Int = 1) async throws {
        guard let index = items.firstIndex(where: { $0.id == itemId }) else {
            throw InventoryError.itemNotFound
        }

        let item = items[index]

        if item.quantity <= quantity {
            // 删除物品
            try await supabase
                .from("user_items")
                .delete()
                .eq("id", value: itemId.uuidString)
                .execute()

            items.remove(at: index)
        } else {
            // 减少数量
            let newQuantity = item.quantity - quantity
            let updateData = DBUserItemUpdate(quantity: newQuantity)
            try await supabase
                .from("user_items")
                .update(updateData)
                .eq("id", value: itemId.uuidString)
                .execute()

            items[index].quantity = newQuantity
        }

        print("🎒 [背包] 使用物品完成")
    }

    /// 按分类筛选物品
    func filter(by category: ItemCategory?) -> [BackpackItem] {
        guard let category = category else {
            return items
        }
        return items.filter { $0.definition?.category == category }
    }

    /// 搜索物品
    func search(keyword: String) -> [BackpackItem] {
        guard !keyword.isEmpty else {
            return items
        }
        return items.filter { item in
            item.definition?.name.localizedCaseInsensitiveContains(keyword) ?? false
        }
    }

    // MARK: - 私有方法

    /// 根据数据库物品名称映射到本地定义 ID
    private func mapToLocalDefinitionId(dbName: String) -> String {
        // 名称映射表（数据库名称 -> 本地 ID）
        let nameMapping: [String: String] = [
            "瓶装水": "water_bottle",
            "矿泉水": "water_bottle",
            "净化水": "water_purified",
            "罐头食品": "canned_food",
            "压缩饼干": "energy_bar",
            "新鲜水果": "canned_food",  // 暂映射到罐头
            "急救包": "first_aid_kit",
            "抗生素": "medicine",
            "肾上腺素": "medicine",
            "木材": "wood",
            "石头": "stone",
            "金属板": "scrap_metal",
            "电子元件": "electronic_parts",
            "稀有矿石": "scrap_metal"
        ]

        return nameMapping[dbName] ?? "canned_food"  // 默认返回罐头
    }

    /// 根据本地物品 ID 查找数据库物品 UUID
    private func findDBItemId(localId: String) -> UUID? {
        // 本地 ID -> 数据库名称
        let localToName: [String: String] = [
            "water_bottle": "瓶装水",
            "water_purified": "净化水",
            "canned_food": "罐头食品",
            "energy_bar": "压缩饼干",
            "bandage": "急救包",
            "medicine": "抗生素",
            "first_aid_kit": "急救包",
            "wood": "木材",
            "stone": "石头",
            "scrap_metal": "金属板",
            "electronic_parts": "电子元件",
            "flashlight": "急救包",  // 暂无对应，用急救包代替
            "rope": "木材",
            "lockpick": "电子元件"
        ]

        guard let dbName = localToName[localId] else {
            print("🎒 [背包] 未找到本地ID对应的数据库名称: \(localId)")
            return nil
        }

        // 从缓存中查找
        return itemDefinitionsCache.values.first { $0.name == dbName }?.id
    }

    // MARK: - 测试方法

    /// 添加测试用建筑材料（用于测试建造系统）
    /// 添加木材、石头、金属板、电子元件各 100 个
    func addTestBuildingMaterials() async throws {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw InventoryError.notAuthenticated
        }

        // 确保物品定义已加载
        if itemDefinitionsCache.isEmpty {
            await loadItemDefinitions()
        }

        // 建筑材料列表
        let materials = ["木材", "石头", "金属板", "电子元件"]

        for materialName in materials {
            // 查找数据库物品 ID
            guard let dbItem = itemDefinitionsCache.values.first(where: { $0.name == materialName }) else {
                print("🎒 [测试] 未找到物品: \(materialName)，跳过")
                continue
            }

            // 检查是否已有该物品
            let existingItems: [DBUserItem] = try await supabase
                .from("user_items")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("item_id", value: dbItem.id.uuidString)
                .execute()
                .value

            if let existing = existingItems.first {
                // 更新数量
                let newQuantity = existing.quantity + 100
                let updateData = DBUserItemUpdate(quantity: newQuantity)
                try await supabase
                    .from("user_items")
                    .update(updateData)
                    .eq("id", value: existing.id.uuidString)
                    .execute()
                print("🎒 [测试] 更新 \(materialName): +100 -> \(newQuantity)")
            } else {
                // 插入新记录
                let upload = DBUserItemUpload(
                    userId: userId,
                    itemId: dbItem.id,
                    quantity: 100,
                    acquiredFrom: "test",
                    isAIGenerated: false,
                    aiName: nil,
                    aiCategory: nil,
                    aiRarity: nil,
                    aiStory: nil
                )
                try await supabase
                    .from("user_items")
                    .insert(upload)
                    .execute()
                print("🎒 [测试] 添加 \(materialName): 100")
            }
        }

        print("🎒 [测试] ✅ 建筑材料添加完成")

        // 重新加载背包
        await loadInventory()
    }
}

// MARK: - 数据库模型

/// 数据库物品定义
struct DBItemDefinition: Codable {
    let id: UUID
    let name: String
    let category: String
    let rarity: String?
    let stackable: Bool?
    let maxStack: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, category, rarity, stackable
        case maxStack = "max_stack"
    }
}

/// 数据库用户物品
struct DBUserItem: Codable {
    let id: UUID
    let userId: UUID
    let itemId: UUID
    let quantity: Int
    let acquiredAt: Date?
    let acquiredFrom: String?

    // AI 生成物品字段
    let isAIGenerated: Bool?
    let aiName: String?
    let aiCategory: String?
    let aiRarity: String?
    let aiStory: String?

    enum CodingKeys: String, CodingKey {
        case id, quantity
        case userId = "user_id"
        case itemId = "item_id"
        case acquiredAt = "acquired_at"
        case acquiredFrom = "acquired_from"
        case isAIGenerated = "is_ai_generated"
        case aiName = "ai_name"
        case aiCategory = "ai_category"
        case aiRarity = "ai_rarity"
        case aiStory = "ai_story"
    }
}

/// 数据库用户物品上传
struct DBUserItemUpload: Codable {
    let userId: UUID
    let itemId: UUID
    let quantity: Int
    let acquiredFrom: String?

    // AI 生成物品字段
    let isAIGenerated: Bool?
    let aiName: String?
    let aiCategory: String?
    let aiRarity: String?
    let aiStory: String?

    enum CodingKeys: String, CodingKey {
        case quantity
        case userId = "user_id"
        case itemId = "item_id"
        case acquiredFrom = "acquired_from"
        case isAIGenerated = "is_ai_generated"
        case aiName = "ai_name"
        case aiCategory = "ai_category"
        case aiRarity = "ai_rarity"
        case aiStory = "ai_story"
    }
}

/// 数据库用户物品更新
struct DBUserItemUpdate: Codable {
    let quantity: Int
}

// MARK: - 错误类型

enum InventoryError: LocalizedError {
    case notAuthenticated
    case itemNotFound
    case insufficientQuantity
    case capacityExceeded

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "用户未登录"
        case .itemNotFound:
            return "物品不存在"
        case .insufficientQuantity:
            return "物品数量不足"
        case .capacityExceeded:
            return "背包容量不足"
        }
    }
}
