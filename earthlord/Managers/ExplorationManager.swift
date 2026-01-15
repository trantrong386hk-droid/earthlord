//
//  ExplorationManager.swift
//  earthlord
//
//  探索会话管理器
//  负责探索会话的开始、结束、数据记录和结果生成
//  包含速度检测：超过30km/h警告，10秒未降速则停止探索
//

import Foundation
import CoreLocation
import Combine
import Supabase

// MARK: - 探索状态

/// 探索状态
enum ExplorationState: Equatable {
    case idle           // 空闲
    case exploring      // 探索中
    case finishing      // 结束中（生成奖励）
    case completed      // 完成（显示结果）
    case failed         // 失败（超速等原因）
}

// MARK: - 探索失败原因

/// 探索失败原因
enum ExplorationFailureReason: Equatable {
    case speedViolation     // 持续超速
    case cancelled          // 用户取消
    case locationError      // 定位错误
}

// MARK: - ExplorationManager

@MainActor
class ExplorationManager: ObservableObject {

    // MARK: - 单例
    static let shared = ExplorationManager()

    // MARK: - 依赖
    private let locationManager = LocationManager.shared
    private let rewardGenerator = RewardGenerator.shared
    private let inventoryManager = InventoryManager.shared
    private let poiSearchManager = POISearchManager.shared

    // MARK: - 发布属性

    /// 探索状态
    @Published var state: ExplorationState = .idle

    /// 探索开始时间
    @Published var startTime: Date?

    /// 当前探索结果（结束后填充）
    @Published var currentResult: ExplorationResult?

    /// 累计统计数据
    @Published var stats: ExplorationStats?

    /// 错误信息
    @Published var errorMessage: String?

    /// 是否正在加载
    @Published var isLoading: Bool = false

    // MARK: - 速度检测属性

    /// 速度警告信息
    @Published var speedWarning: String?

    /// 是否超速
    @Published var isOverSpeed: Bool = false

    /// 超速剩余时间（秒）
    @Published var speedViolationCountdown: Int = 0

    /// 当前速度（km/h）
    @Published var currentSpeed: Double = 0

    /// 探索失败原因
    @Published var failureReason: ExplorationFailureReason?

    // MARK: - POI 搜刮属性

    /// 附近 POI 列表
    @Published var nearbyPOIs: [POI] = []

    /// 已搜刮的 POI ID 集合
    @Published var scavengedPOIIds: Set<UUID> = []

    /// 当前接近的 POI（触发搜刮弹窗）
    @Published var currentPOI: POI? = nil

    /// 是否显示 POI 搜刮提示弹窗
    @Published var showPOIPopup: Bool = false

    /// 是否显示搜刮结果页面
    @Published var showScavengeResult: Bool = false

    /// 搜刮获得的物品
    @Published var scavengeLoot: [ExplorationLoot] = []

    // MARK: - 独立追踪属性（不依赖 LocationManager 的 pathTracking）

    /// 探索行走距离（米）- 独立追踪
    @Published var explorationDistance: Double = 0

    /// 探索时长（秒）- 独立追踪
    @Published var explorationDuration: TimeInterval = 0

    // MARK: - 私有属性

    /// 速度检测定时器
    private var speedCheckTimer: Timer?

    /// 超速开始时间
    private var speedViolationStartTime: Date?

    /// 倒计时定时器
    private var countdownTimer: Timer?

    /// 探索时长更新定时器
    private var durationTimer: Timer?

    /// 上次记录的位置（用于计算距离）
    private var lastExplorationLocation: CLLocation?

    /// 订阅集合
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 常量

    /// 最大允许速度（km/h）
    private let maxSpeedLimit: Double = 30.0

    /// 超速容忍时间（秒）
    private let speedViolationTimeout: TimeInterval = 10.0

    /// 速度检测间隔（秒）
    private let speedCheckInterval: TimeInterval = 1.0

    /// GPS 漂移阈值（km/h）- 超过此值视为 GPS 漂移，不计入超速
    private let gpsDriftThreshold: Double = 50.0

    /// POI 触发距离（米）
    private let poiTriggerDistance: Double = 50.0

    // MARK: - 计算属性

    /// 当前行走距离（独立追踪）
    var currentDistance: Double {
        explorationDistance
    }

    /// 当前时长（独立追踪）
    var currentDuration: TimeInterval {
        explorationDuration
    }

    /// 格式化当前距离
    var formattedDistance: String {
        if explorationDistance >= 1000 {
            return String(format: "%.1f 公里", explorationDistance / 1000)
        } else {
            return String(format: "%.0f 米", explorationDistance)
        }
    }

    /// 格式化当前时长
    var formattedDuration: String {
        let minutes = Int(explorationDuration) / 60
        let seconds = Int(explorationDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// 当前预估奖励等级
    var estimatedTier: RewardTier {
        RewardTier.from(distance: currentDistance)
    }

    // MARK: - 初始化

    private init() {
        print("🔍 [ExplorationManager] 初始化")
        setupSpeedObserver()
        setupPOIObserver()
        setupLocationObserver()
    }

    // MARK: - 速度监控

    /// 设置速度观察者
    private func setupSpeedObserver() {
        // 监听 LocationManager 的速度变化
        locationManager.$currentSpeed
            .receive(on: DispatchQueue.main)
            .sink { [weak self] speed in
                self?.handleSpeedUpdate(speed)
            }
            .store(in: &cancellables)

        print("🔍 [探索] 速度监控已设置")
    }

    /// 设置 POI 围栏观察者
    private func setupPOIObserver() {
        // 监听 LocationManager 的 enteredPOIId 变化
        locationManager.$enteredPOIId
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }  // 只处理非 nil 值
            .sink { [weak self] poiId in
                self?.didEnterPOIRegion(poiId: poiId)
            }
            .store(in: &cancellables)

        print("🔍 [探索] POI 围栏监控已设置")
    }

    /// 设置位置观察者（用于独立计算距离）
    private func setupLocationObserver() {
        // 监听 LocationManager 的位置变化
        locationManager.$userLocation
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }  // 只处理非 nil 值
            .sink { [weak self] coordinate in
                self?.handleLocationUpdate(coordinate)
            }
            .store(in: &cancellables)

        print("🔍 [探索] 位置监控已设置（独立距离计算）")
    }

    /// 处理位置更新（计算距离 + POI 检测）
    private func handleLocationUpdate(_ coordinate: CLLocationCoordinate2D) {
        // 只在探索中时处理
        guard state == .exploring else { return }

        let newLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        // 如果有上次位置，计算距离
        if let lastLocation = lastExplorationLocation {
            let distance = newLocation.distance(from: lastLocation)

            // 过滤 GPS 漂移（距离过大或速度过快）
            let timeDiff = newLocation.timestamp.timeIntervalSince(lastLocation.timestamp)
            let speed = timeDiff > 0 ? (distance / timeDiff) * 3.6 : 0  // km/h

            // 只有合理的移动才计入距离（排除 GPS 漂移）
            if distance >= 3 && distance <= 100 && speed < gpsDriftThreshold {
                explorationDistance += distance
                print("🔍 [探索] 距离更新: +\(String(format: "%.1f", distance))m，总计: \(String(format: "%.0f", explorationDistance))m")
            }
        }

        // 更新上次位置
        lastExplorationLocation = newLocation

        // ⭐ 方案B：基于距离的 POI 检测（比围栏更可靠）
        checkPOIProximity(userLocation: newLocation)
    }

    /// 检测是否接近 POI（距离检测方式）
    private func checkPOIProximity(userLocation: CLLocation) {
        // 如果正在显示弹窗，不检测
        guard !showPOIPopup && !showScavengeResult else { return }

        // 遍历所有 POI，检查距离
        for poi in nearbyPOIs {
            // 跳过已搜刮的 POI
            guard !scavengedPOIIds.contains(poi.id) else { continue }

            // ⚠️ 重要：POI 坐标是 WGS-84，用户位置也是 WGS-84（CLLocation 原始值）
            // 但在中国，CLLocationManager 返回的实际上是 GCJ-02
            // 所以需要将 POI 的 WGS-84 转换为 GCJ-02 来比较
            let poiGCJ = CoordinateConverter.wgs84ToGcj02(poi.coordinate)
            let poiLocation = CLLocation(latitude: poiGCJ.latitude, longitude: poiGCJ.longitude)

            let distance = userLocation.distance(from: poiLocation)

            // 在触发距离内
            if distance <= poiTriggerDistance {
                print("🏪 [POI] ✅ 距离检测触发: \(poi.name)，距离 \(String(format: "%.1f", distance))m")

                // 设置当前 POI 并显示弹窗
                currentPOI = poi
                showPOIPopup = true

                // 只触发一个 POI，避免同时弹出多个
                break
            }
        }
    }

    /// 处理速度更新
    private func handleSpeedUpdate(_ speed: Double) {
        // 只在探索中时检测速度
        guard state == .exploring else { return }

        // 更新当前速度
        currentSpeed = speed

        // 忽略 GPS 漂移
        if speed > gpsDriftThreshold {
            print("🔍 [探索] 🛰️ GPS 漂移检测: \(String(format: "%.1f", speed)) km/h，忽略")
            return
        }

        // 检测是否超速
        if speed > maxSpeedLimit {
            handleOverSpeed(speed: speed)
        } else {
            handleNormalSpeed()
        }
    }

    /// 处理超速情况
    private func handleOverSpeed(speed: Double) {
        print("🔍 [探索] ⚠️ 超速检测: \(String(format: "%.1f", speed)) km/h > \(maxSpeedLimit) km/h")

        if speedViolationStartTime == nil {
            // 首次超速，记录开始时间
            speedViolationStartTime = Date()
            speedViolationCountdown = Int(speedViolationTimeout)
            speedWarning = "速度超过 \(Int(maxSpeedLimit)) km/h，请减速！"
            isOverSpeed = true

            print("🔍 [探索] ⏱️ 开始超速倒计时: \(speedViolationTimeout) 秒")

            // 启动倒计时定时器
            startCountdownTimer()
        }

        // 更新警告信息
        speedWarning = "速度 \(String(format: "%.0f", speed)) km/h，请在 \(speedViolationCountdown) 秒内减速！"
    }

    /// 处理正常速度
    private func handleNormalSpeed() {
        if isOverSpeed {
            print("🔍 [探索] ✅ 速度恢复正常: \(String(format: "%.1f", currentSpeed)) km/h")

            // 清除超速状态
            speedViolationStartTime = nil
            speedViolationCountdown = 0
            speedWarning = nil
            isOverSpeed = false

            // 停止倒计时
            stopCountdownTimer()
        }
    }

    /// 启动倒计时定时器
    private func startCountdownTimer() {
        stopCountdownTimer()

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateCountdown()
            }
        }
    }

    /// 停止倒计时定时器
    private func stopCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    /// 更新倒计时
    private func updateCountdown() {
        guard state == .exploring, isOverSpeed else {
            stopCountdownTimer()
            return
        }

        speedViolationCountdown -= 1
        print("🔍 [探索] ⏱️ 超速倒计时: \(speedViolationCountdown) 秒")

        // 更新警告信息
        speedWarning = "速度 \(String(format: "%.0f", currentSpeed)) km/h，请在 \(speedViolationCountdown) 秒内减速！"

        if speedViolationCountdown <= 0 {
            // 超时，停止探索
            print("🔍 [探索] ⛔ 超速超时，强制停止探索")
            failExploration(reason: .speedViolation)
        }
    }

    // MARK: - 公开方法

    /// 开始探索
    func startExploration() {
        guard state == .idle || state == .failed else {
            print("🔍 [探索] 当前状态不允许开始: \(state)")
            return
        }

        print("🔍 [探索] ========== 开始探索 ==========")
        print("🔍 [探索] 时间: \(Date())")

        // 重置状态
        currentResult = nil
        errorMessage = nil
        failureReason = nil
        startTime = Date()
        state = .exploring

        // 重置速度检测状态
        speedWarning = nil
        isOverSpeed = false
        speedViolationStartTime = nil
        speedViolationCountdown = 0
        currentSpeed = 0

        // 重置独立追踪状态
        explorationDistance = 0
        explorationDuration = 0
        lastExplorationLocation = nil

        // 确保位置更新已启动（不使用 startPathTracking，避免影响圈地功能）
        print("🔍 [探索] 定位授权状态: \(locationManager.isAuthorized)")
        print("🔍 [探索] 当前位置是否可用: \(locationManager.userLocation != nil)")

        if !locationManager.isLocating {
            locationManager.startUpdatingLocation()
        }

        // 启动时长计时器
        startDurationTimer()

        print("🔍 [探索] 探索已启动（独立追踪模式）")
        print("🔍 [探索] 速度限制: \(maxSpeedLimit) km/h")
        print("🔍 [探索] 超速容忍时间: \(speedViolationTimeout) 秒")

        // 搜索附近 POI
        Task {
            await loadNearbyPOIs()
        }
    }

    /// 启动时长计时器
    private func startDurationTimer() {
        stopDurationTimer()

        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateDuration()
            }
        }
    }

    /// 停止时长计时器
    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }

    /// 更新时长
    private func updateDuration() {
        guard state == .exploring, let start = startTime else { return }
        explorationDuration = Date().timeIntervalSince(start)
    }

    /// 结束探索
    func stopExploration() async {
        guard state == .exploring else {
            print("🔍 [探索] 当前状态不允许结束: \(state)")
            return
        }

        print("🔍 [探索] ========== 结束探索 ==========")
        state = .finishing
        isLoading = true

        // 停止速度监控
        stopCountdownTimer()
        speedWarning = nil
        isOverSpeed = false

        // 停止时长计时器
        stopDurationTimer()

        // 获取探索数据（使用独立追踪的值）
        let distance = explorationDistance
        let duration = explorationDuration

        // 探索不需要记录路径，传空数组
        let path: [CLLocationCoordinate2D] = []

        // 判断奖励等级
        let tier = RewardTier.from(distance: distance)

        print("🔍 [探索] 统计数据:")
        print("🔍 [探索]   - 距离: \(String(format: "%.0f", distance)) 米")
        print("🔍 [探索]   - 时长: \(String(format: "%.0f", duration)) 秒")
        print("🔍 [探索]   - 路径点数: \(path.count)")
        print("🔍 [探索]   - 奖励等级: \(tier.rawValue)")

        // 生成奖励
        let loot = rewardGenerator.generateLoot(tier: tier)
        print("🔍 [探索]   - 获得物品: \(loot.count) 件")

        // 构建探索结果
        let result = ExplorationResult(
            id: UUID(),
            startTime: startTime ?? Date(),
            endTime: Date(),
            distanceWalked: distance,
            loot: loot
        )

        // 保存到数据库
        do {
            try await saveExplorationSession(result: result, tier: tier, path: path)
            print("🔍 [探索] ✅ 探索会话已保存到数据库")

            // 保存物品到背包
            if !loot.isEmpty {
                try await inventoryManager.addItems(loot, sourceType: "exploration", sourceId: result.id)
                print("🔍 [探索] ✅ 物品已添加到背包")
            }

            // 更新累计统计
            try await updateStats(distance: distance, duration: duration, tier: tier, itemCount: loot.count)
            print("🔍 [探索] ✅ 累计统计已更新")

            // 加载最新统计
            await loadStats()

            currentResult = result
            state = .completed

            print("🔍 [探索] ========== 探索完成 ==========")

        } catch {
            errorMessage = "保存探索记录失败: \(error.localizedDescription)"
            print("🔍 [探索] ❌ 保存失败: \(error)")
            // 即使保存失败，也显示结果
            currentResult = result
            state = .completed
        }

        // 清除 POI 状态
        clearPOIs()

        isLoading = false
    }

    /// 探索失败
    func failExploration(reason: ExplorationFailureReason) {
        guard state == .exploring else {
            print("🔍 [探索] 当前状态不允许失败: \(state)")
            return
        }

        print("🔍 [探索] ========== 探索失败 ==========")
        print("🔍 [探索] 失败原因: \(reason)")

        // 停止速度监控
        stopCountdownTimer()

        // 停止时长计时器
        stopDurationTimer()

        // 清除 POI 状态
        clearPOIs()

        // 设置失败状态
        failureReason = reason
        state = .failed

        // 设置错误信息
        switch reason {
        case .speedViolation:
            errorMessage = "探索失败：持续超速超过 \(Int(speedViolationTimeout)) 秒"
            speedWarning = "探索已终止：超速超时"
        case .cancelled:
            errorMessage = "探索已取消"
        case .locationError:
            errorMessage = "探索失败：定位错误"
        }

        print("🔍 [探索] 错误信息: \(errorMessage ?? "无")")
        print("🔍 [探索] ========== 探索失败结束 ==========")
    }

    /// 重置状态（关闭结果页后调用）
    func reset() {
        print("🔍 [探索] 重置状态")

        state = .idle
        currentResult = nil
        startTime = nil
        errorMessage = nil
        failureReason = nil

        // 重置速度检测状态
        speedWarning = nil
        isOverSpeed = false
        speedViolationStartTime = nil
        speedViolationCountdown = 0
        currentSpeed = 0

        // 重置独立追踪状态
        explorationDistance = 0
        explorationDuration = 0
        lastExplorationLocation = nil

        // 停止定时器
        stopCountdownTimer()
        stopDurationTimer()

        // 清理 POI 相关状态
        clearPOIs()
    }

    // MARK: - POI 搜刮方法

    /// 加载附近 POI（开始探索时调用）
    func loadNearbyPOIs() async {
        // 等待获取用户位置（最多等待 3 秒）
        var center: CLLocationCoordinate2D?
        let maxRetries = 6
        var retryCount = 0

        while center == nil && retryCount < maxRetries {
            center = locationManager.userLocation
            if center == nil {
                print("🏪 [POI] 等待位置... (\(retryCount + 1)/\(maxRetries))")
                try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5 秒
                retryCount += 1
            }
        }

        guard let validCenter = center else {
            print("🏪 [POI] ⚠️ 无法获取当前位置，已等待 \(maxRetries * 500)ms")
            return
        }

        print("🏪 [POI] 开始搜索附近 POI，中心点: \(validCenter.latitude), \(validCenter.longitude)")

        do {
            let pois = try await poiSearchManager.searchNearbyPOIs(center: validCenter)

            nearbyPOIs = pois
            print("🏪 [POI] ✅ 找到 \(pois.count) 个 POI，已更新 nearbyPOIs")

            // 启动地理围栏监控（作为备用）
            if !pois.isEmpty {
                locationManager.startMonitoringPOIs(pois)
                print("🏪 [POI] 地理围栏监控已启动（备用）")

                // ⭐ 立即检测一次，以便用户已在 POI 附近时也能触发
                if let userCoord = locationManager.userLocation {
                    let userLocation = CLLocation(latitude: userCoord.latitude, longitude: userCoord.longitude)
                    checkPOIProximity(userLocation: userLocation)
                    print("🏪 [POI] 已执行初始 POI 距离检测")
                }
            } else {
                print("🏪 [POI] ⚠️ 附近没有找到任何 POI")
            }
        } catch {
            print("🏪 [POI] ❌ 搜索失败: \(error.localizedDescription)")
            nearbyPOIs = []
        }
    }

    /// 处理进入 POI 范围（地理围栏回调）
    func didEnterPOIRegion(poiId: UUID) {
        // 只在探索中时处理
        guard state == .exploring else {
            print("🏪 [POI] 忽略围栏触发：当前非探索状态")
            return
        }

        // 检查是否已搜刮过
        guard !scavengedPOIIds.contains(poiId) else {
            print("🏪 [POI] 忽略围栏触发：该 POI 已搜刮")
            return
        }

        // 查找 POI
        guard let poi = nearbyPOIs.first(where: { $0.id == poiId }) else {
            print("🏪 [POI] ⚠️ 未找到 POI: \(poiId)")
            return
        }

        // 检查是否正在显示弹窗
        guard !showPOIPopup && !showScavengeResult else {
            print("🏪 [POI] 忽略围栏触发：正在显示其他弹窗")
            return
        }

        print("🏪 [POI] 进入 POI 范围: \(poi.name)")

        // 设置当前 POI 并显示弹窗
        currentPOI = poi
        showPOIPopup = true

        // 清除 LocationManager 的触发状态，允许下次触发
        locationManager.clearEnteredPOI()
    }

    /// 执行搜刮
    func scavengePOI(_ poi: POI) async {
        print("🏪 [POI] 开始搜刮: \(poi.name)")

        // 关闭提示弹窗
        showPOIPopup = false

        // 生成搜刮物品
        scavengeLoot = generateScavengeLoot(for: poi)
        print("🏪 [POI] 生成 \(scavengeLoot.count) 件物品")

        // 保存物品到背包
        if !scavengeLoot.isEmpty {
            do {
                try await inventoryManager.addItems(scavengeLoot, sourceType: "scavenge", sourceId: poi.id)
                print("🏪 [POI] ✅ 物品已添加到背包")
            } catch {
                print("🏪 [POI] ❌ 保存物品失败: \(error)")
            }
        }

        // 标记为已搜刮
        scavengedPOIIds.insert(poi.id)

        // 显示结果页面
        showScavengeResult = true
    }

    /// 关闭搜刮提示弹窗
    func dismissPOIPopup() {
        showPOIPopup = false
        currentPOI = nil
    }

    /// 关闭搜刮结果页面
    func dismissScavengeResult() {
        showScavengeResult = false
        scavengeLoot = []
        // 不清除 currentPOI，因为可能还需要显示
    }

    /// 清除 POI 相关状态
    func clearPOIs() {
        print("🏪 [POI] 清除 POI 状态")

        // 停止围栏监控
        locationManager.stopMonitoringAllPOIs()

        // 清除状态
        nearbyPOIs = []
        scavengedPOIIds = []
        currentPOI = nil
        showPOIPopup = false
        showScavengeResult = false
        scavengeLoot = []
    }

    /// 生成搜刮物品（1-3 件随机物品）
    private func generateScavengeLoot(for poi: POI) -> [ExplorationLoot] {
        // 根据 POI 类型和危险等级决定物品数量
        let baseCount = 1
        let bonusFromDanger = min(poi.dangerLevel / 2, 2)  // 危险等级越高，物品越多
        let itemCount = baseCount + bonusFromDanger

        // 根据 POI 类型确定奖励等级（危险等级影响稀有度）
        let tier: RewardTier
        switch poi.dangerLevel {
        case 1...2:
            tier = .bronze
        case 3:
            tier = .silver
        case 4:
            tier = .gold
        default:
            tier = .diamond
        }

        // 使用 RewardGenerator 生成物品
        var loot: [ExplorationLoot] = []
        for _ in 0..<itemCount {
            let singleLoot = rewardGenerator.generateLoot(tier: tier)
            if let item = singleLoot.first {
                loot.append(item)
            }
        }

        return loot
    }

    /// 加载累计统计
    func loadStats() async {
        print("🔍 [探索] 加载累计统计...")

        do {
            guard let userId = try? await supabase.auth.session.user.id else {
                print("🔍 [探索] ⚠️ 用户未登录，无法加载统计")
                return
            }

            let response: [DBExplorationStats] = try await supabase
                .from("user_exploration_stats")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            if let dbStats = response.first {
                // 转换为 ExplorationStats
                stats = ExplorationStats(
                    totalDistance: dbStats.totalDistance,
                    totalDuration: TimeInterval(dbStats.totalDuration),
                    totalLootCount: dbStats.totalItemsEarned
                )
                print("🔍 [探索] ✅ 统计加载成功: 距离 \(String(format: "%.0f", dbStats.totalDistance))m")
            } else {
                // 没有统计数据，使用默认值
                stats = ExplorationStats(
                    totalDistance: 0,
                    totalDuration: 0,
                    totalLootCount: 0
                )
                print("🔍 [探索] 无历史统计数据")
            }
        } catch {
            print("🔍 [探索] ❌ 加载统计失败: \(error)")
        }
    }

    // MARK: - 私有方法

    /// 保存探索会话到数据库
    private func saveExplorationSession(
        result: ExplorationResult,
        tier: RewardTier,
        path: [CLLocationCoordinate2D]
    ) async throws {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw ExplorationError.notAuthenticated
        }

        let pathData = path.map { ["lat": $0.latitude, "lon": $0.longitude] }

        let upload = DBExplorationSessionUpload(
            userId: userId,
            startTime: result.startTime,
            endTime: result.endTime,
            durationSeconds: Int(result.duration),
            distanceMeters: result.distanceWalked,
            rewardTier: tier.rawValue,
            itemsEarned: result.loot.count,
            path: pathData
        )

        try await supabase
            .from("exploration_sessions")
            .insert(upload)
            .execute()
    }

    /// 更新累计统计
    private func updateStats(
        distance: Double,
        duration: TimeInterval,
        tier: RewardTier,
        itemCount: Int
    ) async throws {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw ExplorationError.notAuthenticated
        }

        // 调用存储过程更新统计
        let params = UpdateStatsParams(
            pUserId: userId,
            pDistance: distance,
            pDuration: Int(duration),
            pTier: tier.rawValue,
            pItems: itemCount
        )
        try await supabase.rpc("update_exploration_stats", params: params).execute()
    }
}

// MARK: - 数据库模型

/// 探索会话上传结构
struct DBExplorationSessionUpload: Codable {
    let userId: UUID
    let startTime: Date
    let endTime: Date
    let durationSeconds: Int
    let distanceMeters: Double
    let rewardTier: String
    let itemsEarned: Int
    let path: [[String: Double]]

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case startTime = "start_time"
        case endTime = "end_time"
        case durationSeconds = "duration_seconds"
        case distanceMeters = "distance_meters"
        case rewardTier = "reward_tier"
        case itemsEarned = "items_earned"
        case path
    }
}

/// 更新统计参数
struct UpdateStatsParams: Encodable, Sendable {
    let pUserId: UUID
    let pDistance: Double
    let pDuration: Int
    let pTier: String
    let pItems: Int

    enum CodingKeys: String, CodingKey {
        case pUserId = "p_user_id"
        case pDistance = "p_distance"
        case pDuration = "p_duration"
        case pTier = "p_tier"
        case pItems = "p_items"
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pUserId, forKey: .pUserId)
        try container.encode(pDistance, forKey: .pDistance)
        try container.encode(pDuration, forKey: .pDuration)
        try container.encode(pTier, forKey: .pTier)
        try container.encode(pItems, forKey: .pItems)
    }
}

/// 数据库统计结构
struct DBExplorationStats: Codable {
    let userId: UUID
    let totalDistance: Double
    let totalDuration: Int
    let totalExplorations: Int
    let totalItemsEarned: Int
    let bronzeCount: Int
    let silverCount: Int
    let goldCount: Int
    let diamondCount: Int

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case totalDistance = "total_distance"
        case totalDuration = "total_duration"
        case totalExplorations = "total_explorations"
        case totalItemsEarned = "total_items_earned"
        case bronzeCount = "bronze_count"
        case silverCount = "silver_count"
        case goldCount = "gold_count"
        case diamondCount = "diamond_count"
    }
}

// MARK: - 错误类型

enum ExplorationError: LocalizedError {
    case notAuthenticated
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "用户未登录"
        case .saveFailed(let message):
            return "保存失败: \(message)"
        }
    }
}
