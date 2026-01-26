//
//  BuildingManager.swift
//  earthlord
//
//  建筑管理器
//  负责建筑模板加载、建造、升级和数据库同步
//

import Foundation
import Combine
import Supabase

// MARK: - BuildingManager

@MainActor
class BuildingManager: ObservableObject {

    // MARK: - 单例

    static let shared = BuildingManager()

    // MARK: - 发布属性

    /// 建筑模板列表
    @Published var buildingTemplates: [BuildingTemplate] = []

    /// 玩家建筑列表
    @Published var playerBuildings: [PlayerBuilding] = []

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - 私有属性

    /// 建筑计时器（用于跟踪建造进度）
    private var buildingTimers: [UUID: Timer] = [:]

    // MARK: - 初始化

    private init() {
        print("🏗️ [BuildingManager] 初始化")
        loadTemplates()
    }

    // MARK: - 模板加载

    /// 从 JSON 文件加载建筑模板
    func loadTemplates() {
        print("🏗️ [BuildingManager] 开始加载建筑模板...")

        guard let url = Bundle.main.url(forResource: "building_templates", withExtension: "json") else {
            print("🏗️ [BuildingManager] ❌ 找不到 building_templates.json 文件")
            errorMessage = "找不到建筑模板配置文件"
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()

            // 定义临时结构体来解析 JSON
            struct TemplateWrapper: Codable {
                let templates: [BuildingTemplate]
            }

            let wrapper = try decoder.decode(TemplateWrapper.self, from: data)
            buildingTemplates = wrapper.templates

            print("🏗️ [BuildingManager] ✅ 成功加载 \(buildingTemplates.count) 个建筑模板")

            // 打印模板信息
            for template in buildingTemplates {
                print("  - \(template.name) (\(template.templateId)): \(template.category.displayName)")
            }

        } catch {
            print("🏗️ [BuildingManager] ❌ 加载模板失败: \(error)")
            errorMessage = "加载建筑模板失败：\(error.localizedDescription)"
        }
    }

    // MARK: - 模板查询

    /// 获取指定 ID 的模板
    func getTemplate(for templateId: String) -> BuildingTemplate? {
        return buildingTemplates.first { $0.templateId == templateId }
    }

    /// 获取指定分类的模板
    func getTemplates(for category: BuildingCategory) -> [BuildingTemplate] {
        return buildingTemplates.filter { $0.category == category }
    }

    /// 获取指定 Tier 的模板
    func getTemplates(forTier tier: Int) -> [BuildingTemplate] {
        return buildingTemplates.filter { $0.tier == tier }
    }

    // MARK: - 建造检查

    /// 检查是否可以建造指定建筑
    /// - Parameters:
    ///   - template: 建筑模板
    ///   - territoryId: 领地ID
    /// - Returns: 检查结果
    func canBuild(template: BuildingTemplate, territoryId: String) -> BuildCheckResult {
        // 1. 获取玩家背包资源
        let playerResources = getPlayerResources()

        // 2. 检查资源是否足够
        var insufficientResources: [String: Int] = [:]
        for (resource, required) in template.requiredResources {
            let available = playerResources[resource] ?? 0
            if available < required {
                insufficientResources[resource] = required - available
            }
        }

        if !insufficientResources.isEmpty {
            return .failure(.insufficientResources(insufficientResources))
        }

        // 3. 检查数量限制
        let existingCount = playerBuildings.filter {
            $0.territoryId.lowercased() == territoryId.lowercased() && $0.templateId == template.templateId
        }.count

        if existingCount >= template.maxPerTerritory {
            return .failure(.maxBuildingsReached(template.maxPerTerritory))
        }

        return .success
    }

    /// 获取玩家背包资源（资源名称 -> 数量）
    func getPlayerResources() -> [String: Int] {
        var resources: [String: Int] = [:]

        // 从 InventoryManager 获取物品
        let inventoryManager = InventoryManager.shared
        let itemDefinitionsCache = inventoryManager.itemDefinitionsCache

        for item in inventoryManager.items {
            // 处理普通物品
            if !item.isAIGenerated {
                // 通过 definitionId 查找对应的数据库物品名称
                if let dbDef = itemDefinitionsCache.values.first(where: { dbItem in
                    // 使用名称映射（与 InventoryManager 中的逻辑保持一致）
                    let mappedId = mapDBNameToLocalId(dbItem.name)
                    return mappedId == item.definitionId
                }) {
                    let name = dbDef.name
                    resources[name, default: 0] += item.quantity
                }
            }
        }

        print("🏗️ [BuildingManager] 玩家资源: \(resources)")
        return resources
    }

    /// 将数据库物品名称映射到本地ID（与 InventoryManager 保持一致）
    private func mapDBNameToLocalId(_ dbName: String) -> String {
        let nameMapping: [String: String] = [
            "瓶装水": "water_bottle",
            "矿泉水": "water_bottle",
            "净化水": "water_purified",
            "罐头食品": "canned_food",
            "压缩饼干": "energy_bar",
            "新鲜水果": "canned_food",
            "急救包": "first_aid_kit",
            "抗生素": "medicine",
            "肾上腺素": "medicine",
            "木材": "wood",
            "石头": "stone",
            "金属板": "scrap_metal",
            "电子元件": "electronic_parts",
            "稀有矿石": "scrap_metal"
        ]
        return nameMapping[dbName] ?? "unknown"
    }

    // MARK: - 建造操作

    /// 开始建造建筑
    /// - Parameters:
    ///   - templateId: 模板ID
    ///   - territoryId: 领地ID
    ///   - location: 建筑位置（可选）
    /// - Returns: 新建的建筑
    func startConstruction(
        templateId: String,
        territoryId: String,
        location: (lat: Double, lon: Double)? = nil
    ) async throws -> PlayerBuilding {
        print("🏗️ [BuildingManager] 开始建造: \(templateId) 在领地 \(territoryId)")

        // 1. 获取模板
        guard let template = getTemplate(for: templateId) else {
            throw BuildingError.templateNotFound
        }

        // 2. 检查是否可以建造
        let checkResult = canBuild(template: template, territoryId: territoryId)
        if !checkResult.canBuild, let error = checkResult.error {
            throw error
        }

        // 3. 获取用户ID
        guard let userId = try? await supabase.auth.session.user.id else {
            throw BuildingError.notAuthenticated
        }

        // 4. 扣除资源
        try await consumeResources(template.requiredResources)

        // 5. 创建建筑记录
        let buildStartedAt = Date()
        let buildCompletedAt = buildStartedAt.addingTimeInterval(TimeInterval(template.buildTimeSeconds))
        let upload = PlayerBuildingUpload(
            userId: userId,
            territoryId: territoryId,
            templateId: templateId,
            buildingName: template.name,
            status: BuildingStatus.constructing.rawValue,
            level: 1,
            locationLat: location?.lat,
            locationLon: location?.lon,
            buildStartedAt: buildStartedAt,
            buildCompletedAt: buildCompletedAt
        )

        // 6. 上传到数据库
        let response: PlayerBuilding = try await supabase
            .from("player_buildings")
            .insert(upload)
            .select()
            .single()
            .execute()
            .value

        print("🏗️ [BuildingManager] ✅ 建筑创建成功: \(response.id)")

        // 7. 更新本地列表
        playerBuildings.append(response)

        // 8. 启动建造计时器
        startBuildingTimer(for: response, template: template)

        return response
    }

    /// 消耗资源
    private func consumeResources(_ resources: [String: Int]) async throws {
        let inventoryManager = InventoryManager.shared

        for (resourceName, amount) in resources {
            // 查找对应的背包物品
            if let item = inventoryManager.items.first(where: { backpackItem in
                // 通过数据库定义查找
                if let dbDef = inventoryManager.itemDefinitionsCache.values.first(where: { $0.name == resourceName }) {
                    let mappedId = mapDBNameToLocalId(dbDef.name)
                    return mappedId == backpackItem.definitionId
                }
                return false
            }) {
                try await inventoryManager.useItem(itemId: item.id, quantity: amount)
                print("🏗️ [BuildingManager] 消耗资源: \(resourceName) x\(amount)")
            }
        }
    }

    /// 启动建造计时器
    private func startBuildingTimer(for building: PlayerBuilding, template: BuildingTemplate) {
        let buildTime = TimeInterval(template.buildTimeSeconds)

        let timer = Timer.scheduledTimer(withTimeInterval: buildTime, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.completeConstruction(buildingId: building.id)
            }
        }

        buildingTimers[building.id] = timer
        print("🏗️ [BuildingManager] 建造计时器已启动，\(template.buildTimeSeconds)秒后完成")
    }

    /// 完成建造
    func completeConstruction(buildingId: UUID) async {
        print("🏗️ [BuildingManager] 完成建造: \(buildingId)")

        do {
            let now = Date()
            let update = PlayerBuildingUpdate(
                status: BuildingStatus.active.rawValue,
                buildCompletedAt: now,
                updatedAt: now
            )

            try await supabase
                .from("player_buildings")
                .update(update)
                .eq("id", value: buildingId.uuidString)
                .execute()

            // 更新本地状态
            if let index = playerBuildings.firstIndex(where: { $0.id == buildingId }) {
                playerBuildings[index].status = .active
                playerBuildings[index].buildCompletedAt = now
            }

            // 清理计时器
            buildingTimers[buildingId]?.invalidate()
            buildingTimers.removeValue(forKey: buildingId)

            print("🏗️ [BuildingManager] ✅ 建筑已完成: \(buildingId)")

        } catch {
            print("🏗️ [BuildingManager] ❌ 完成建造失败: \(error)")
            errorMessage = "完成建造失败：\(error.localizedDescription)"
        }
    }

    // MARK: - 升级操作

    /// 计算升级所需资源（每级增加 50%）
    func getUpgradeResources(template: BuildingTemplate, currentLevel: Int) -> [String: Int] {
        var upgradeResources: [String: Int] = [:]
        let multiplier = 1.0 + Double(currentLevel) * 0.5
        for (resource, baseAmount) in template.requiredResources {
            upgradeResources[resource] = Int(Double(baseAmount) * multiplier)
        }
        return upgradeResources
    }

    /// 计算升级时间（每级增加基础时间的 50%）
    func getUpgradeTimeSeconds(template: BuildingTemplate, currentLevel: Int) -> Int {
        let multiplier = 1.0 + Double(currentLevel) * 0.5
        return Int(Double(template.buildTimeSeconds) * multiplier)
    }

    /// 检查是否可以升级
    func canUpgrade(building: PlayerBuilding) -> BuildCheckResult {
        // 1. 获取模板
        guard let template = getTemplate(for: building.templateId) else {
            return .failure(.templateNotFound)
        }

        // 2. 检查状态
        if building.status != .active {
            return .failure(.invalidStatus)
        }

        // 3. 检查最高等级
        if building.level >= template.maxLevel {
            return .failure(.maxLevelReached)
        }

        // 4. 检查资源
        let upgradeResources = getUpgradeResources(template: template, currentLevel: building.level)
        let playerResources = getPlayerResources()
        var insufficientResources: [String: Int] = [:]
        for (resource, required) in upgradeResources {
            let available = playerResources[resource] ?? 0
            if available < required {
                insufficientResources[resource] = required - available
            }
        }

        if !insufficientResources.isEmpty {
            return .failure(.insufficientResources(insufficientResources))
        }

        return .success
    }

    /// 开始升级建筑
    func upgradeBuilding(buildingId: UUID) async throws {
        print("🏗️ [BuildingManager] 升级建筑: \(buildingId)")

        // 1. 查找建筑
        guard let index = playerBuildings.firstIndex(where: { $0.id == buildingId }) else {
            throw BuildingError.buildingNotFound
        }

        let building = playerBuildings[index]

        // 2. 获取模板
        guard let template = getTemplate(for: building.templateId) else {
            throw BuildingError.templateNotFound
        }

        // 3. 检查是否可以升级
        let checkResult = canUpgrade(building: building)
        if !checkResult.canBuild, let error = checkResult.error {
            throw error
        }

        // 4. 计算升级资源和时间
        let upgradeResources = getUpgradeResources(template: template, currentLevel: building.level)
        let upgradeTimeSeconds = getUpgradeTimeSeconds(template: template, currentLevel: building.level)

        // 5. 扣除资源
        try await consumeResources(upgradeResources)

        // 6. 更新状态为升级中
        let now = Date()
        let completedAt = now.addingTimeInterval(TimeInterval(upgradeTimeSeconds))
        let update = PlayerBuildingUpdate(
            status: BuildingStatus.upgrading.rawValue,
            buildStartedAt: now,
            buildCompletedAt: completedAt,
            updatedAt: now
        )

        try await supabase
            .from("player_buildings")
            .update(update)
            .eq("id", value: buildingId.uuidString)
            .execute()

        // 7. 更新本地状态
        playerBuildings[index].status = .upgrading
        playerBuildings[index].buildStartedAt = now
        playerBuildings[index].buildCompletedAt = completedAt

        print("🏗️ [BuildingManager] ✅ 开始升级: Lv.\(building.level) → Lv.\(building.level + 1)，需要 \(upgradeTimeSeconds) 秒")

        // 8. 启动升级计时器
        startUpgradeTimer(for: playerBuildings[index], newLevel: building.level + 1)
    }

    /// 启动升级计时器
    private func startUpgradeTimer(for building: PlayerBuilding, newLevel: Int) {
        guard let completedAt = building.buildCompletedAt else { return }
        let remaining = completedAt.timeIntervalSince(Date())
        guard remaining > 0 else {
            Task { await completeUpgrade(buildingId: building.id, newLevel: newLevel) }
            return
        }

        let timer = Timer.scheduledTimer(withTimeInterval: remaining, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.completeUpgrade(buildingId: building.id, newLevel: newLevel)
            }
        }

        buildingTimers[building.id] = timer
        print("🏗️ [BuildingManager] 升级计时器已启动，\(Int(remaining))秒后完成")
    }

    /// 完成升级
    func completeUpgrade(buildingId: UUID, newLevel: Int) async {
        print("🏗️ [BuildingManager] 完成升级: \(buildingId) → Lv.\(newLevel)")

        do {
            let now = Date()
            let update = PlayerBuildingUpdate(
                status: BuildingStatus.active.rawValue,
                level: newLevel,
                buildCompletedAt: now,
                updatedAt: now
            )

            try await supabase
                .from("player_buildings")
                .update(update)
                .eq("id", value: buildingId.uuidString)
                .execute()

            // 更新本地状态
            if let index = playerBuildings.firstIndex(where: { $0.id == buildingId }) {
                playerBuildings[index].status = .active
                playerBuildings[index].level = newLevel
                playerBuildings[index].buildCompletedAt = now
            }

            // 清理计时器
            buildingTimers[buildingId]?.invalidate()
            buildingTimers.removeValue(forKey: buildingId)

            print("🏗️ [BuildingManager] ✅ 升级完成: Lv.\(newLevel)")

            // 发送通知
            NotificationCenter.default.post(name: .buildingUpdated, object: nil)

        } catch {
            print("🏗️ [BuildingManager] ❌ 完成升级失败: \(error)")
            errorMessage = "完成升级失败：\(error.localizedDescription)"
        }
    }

    // MARK: - 数据加载

    /// 获取指定领地的建筑
    func fetchPlayerBuildings(territoryId: String) async {
        print("🏗️ [BuildingManager] 加载领地建筑: \(territoryId)")

        isLoading = true
        errorMessage = nil

        do {
            guard let userId = try? await supabase.auth.session.user.id else {
                throw BuildingError.notAuthenticated
            }

            let response: [PlayerBuilding] = try await supabase
                .from("player_buildings")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("territory_id", value: territoryId)
                .order("created_at", ascending: false)
                .execute()
                .value

            // 更新本地列表（合并或替换）
            for building in response {
                if let index = playerBuildings.firstIndex(where: { $0.id == building.id }) {
                    playerBuildings[index] = building
                } else {
                    playerBuildings.append(building)
                }
            }

            print("🏗️ [BuildingManager] ✅ 加载完成，共 \(response.count) 个建筑")

            // 为建造中/升级中的建筑启动计时器
            for building in response where building.status.isInProgress {
                if let template = getTemplate(for: building.templateId) {
                    if building.status == .constructing {
                        startBuildingTimer(for: building, template: template)
                    } else if building.status == .upgrading {
                        startUpgradeTimer(for: building, newLevel: building.level + 1)
                    }
                }
            }

        } catch {
            print("🏗️ [BuildingManager] ❌ 加载建筑失败: \(error)")
            errorMessage = "加载建筑失败：\(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 获取所有玩家建筑
    func fetchAllPlayerBuildings() async {
        print("🏗️ [BuildingManager] 加载所有玩家建筑")

        isLoading = true
        errorMessage = nil

        do {
            guard let userId = try? await supabase.auth.session.user.id else {
                throw BuildingError.notAuthenticated
            }

            let response: [PlayerBuilding] = try await supabase
                .from("player_buildings")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            playerBuildings = response
            print("🏗️ [BuildingManager] ✅ 加载完成，共 \(response.count) 个建筑")

        } catch {
            print("🏗️ [BuildingManager] ❌ 加载建筑失败: \(error)")
            errorMessage = "加载建筑失败：\(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - 辅助方法

    /// 获取指定领地的建筑数量
    func getBuildingCount(for territoryId: String) -> Int {
        return playerBuildings.filter { $0.territoryId.lowercased() == territoryId.lowercased() }.count
    }

    /// 获取指定领地中某模板的建筑数量
    func getBuildingCount(templateId: String, territoryId: String) -> Int {
        return playerBuildings.filter {
            $0.territoryId.lowercased() == territoryId.lowercased() && $0.templateId == templateId
        }.count
    }

    /// 获取指定领地的建筑列表
    func getBuildings(for territoryId: String) -> [PlayerBuilding] {
        return playerBuildings.filter { $0.territoryId.lowercased() == territoryId.lowercased() }
    }

    /// 清理所有计时器
    func cleanupTimers() {
        for (_, timer) in buildingTimers {
            timer.invalidate()
        }
        buildingTimers.removeAll()
        print("🏗️ [BuildingManager] 所有计时器已清理")
    }

    // MARK: - 拆除操作

    /// 拆除建筑
    /// - Parameter buildingId: 建筑ID
    func demolishBuilding(buildingId: UUID) async throws {
        print("🏗️ [BuildingManager] 拆除建筑: \(buildingId)")

        // 1. 查找建筑
        guard let index = playerBuildings.firstIndex(where: { $0.id == buildingId }) else {
            throw BuildingError.buildingNotFound
        }

        // 2. 获取用户ID验证
        guard let userId = try? await supabase.auth.session.user.id else {
            throw BuildingError.notAuthenticated
        }

        let building = playerBuildings[index]

        // 确保是自己的建筑
        guard building.userId == userId else {
            throw BuildingError.databaseError("无权拆除他人建筑")
        }

        // 3. 从数据库删除
        try await supabase
            .from("player_buildings")
            .delete()
            .eq("id", value: buildingId.uuidString)
            .execute()

        // 4. 清理计时器（如果有）
        buildingTimers[buildingId]?.invalidate()
        buildingTimers.removeValue(forKey: buildingId)

        // 5. 从本地列表移除
        playerBuildings.remove(at: index)

        print("🏗️ [BuildingManager] ✅ 建筑拆除成功: \(buildingId)")
    }

    /// 重命名建筑
    /// - Parameters:
    ///   - buildingId: 建筑ID
    ///   - newName: 新名称
    func renameBuilding(buildingId: UUID, newName: String) async throws {
        print("🏗️ [BuildingManager] 重命名建筑: \(buildingId) -> \(newName)")

        // 1. 查找建筑
        guard let index = playerBuildings.firstIndex(where: { $0.id == buildingId }) else {
            throw BuildingError.buildingNotFound
        }

        // 2. 更新数据库
        try await supabase
            .from("player_buildings")
            .update(["building_name": newName])
            .eq("id", value: buildingId.uuidString)
            .execute()

        // 3. 更新本地（使用新实例替换，因为 buildingName 是 let）
        let oldBuilding = playerBuildings[index]
        let newBuilding = PlayerBuilding(
            id: oldBuilding.id,
            userId: oldBuilding.userId,
            territoryId: oldBuilding.territoryId,
            templateId: oldBuilding.templateId,
            buildingName: newName,
            status: oldBuilding.status,
            level: oldBuilding.level,
            locationLat: oldBuilding.locationLat,
            locationLon: oldBuilding.locationLon,
            buildStartedAt: oldBuilding.buildStartedAt,
            buildCompletedAt: oldBuilding.buildCompletedAt,
            createdAt: oldBuilding.createdAt,
            updatedAt: Date()
        )
        playerBuildings[index] = newBuilding

        print("🏗️ [BuildingManager] ✅ 建筑重命名成功")

        // 发送通知
        NotificationCenter.default.post(name: .buildingUpdated, object: nil)
    }
}

// MARK: - 通知名称

extension Notification.Name {
    static let buildingUpdated = Notification.Name("buildingUpdated")
}
