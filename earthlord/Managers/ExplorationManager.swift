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

    // MARK: - 私有属性

    /// 速度检测定时器
    private var speedCheckTimer: Timer?

    /// 超速开始时间
    private var speedViolationStartTime: Date?

    /// 倒计时定时器
    private var countdownTimer: Timer?

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

    // MARK: - 计算属性

    /// 当前行走距离（来自 LocationManager）
    var currentDistance: Double {
        locationManager.totalDistance
    }

    /// 当前时长（来自 LocationManager）
    var currentDuration: TimeInterval {
        locationManager.trackingDuration
    }

    /// 格式化当前距离
    var formattedDistance: String {
        locationManager.formattedDistance
    }

    /// 格式化当前时长
    var formattedDuration: String {
        locationManager.formattedDuration
    }

    /// 当前预估奖励等级
    var estimatedTier: RewardTier {
        RewardTier.from(distance: currentDistance)
    }

    // MARK: - 初始化

    private init() {
        print("🔍 [ExplorationManager] 初始化")
        setupSpeedObserver()
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

        // ⚠️ 重要：先确保之前的追踪已停止，避免 isTracking 状态冲突
        // 如果 isTracking 已经是 true，startPathTracking() 会直接返回，不创建定时器
        print("🔍 [探索] 当前 isTracking 状态: \(locationManager.isTracking)")
        if locationManager.isTracking {
            print("🔍 [探索] ⚠️ 检测到遗留的追踪状态，先停止...")
            locationManager.stopPathTracking()
        }

        // 启动位置追踪（复用 LocationManager）
        print("🔍 [探索] 准备启动位置追踪...")
        print("🔍 [探索] 定位授权状态: \(locationManager.isAuthorized)")
        print("🔍 [探索] 当前位置是否可用: \(locationManager.userLocation != nil)")

        locationManager.startPathTracking()

        print("🔍 [探索] 位置追踪已启动，isTracking = \(locationManager.isTracking)")
        print("🔍 [探索] 速度限制: \(maxSpeedLimit) km/h")
        print("🔍 [探索] 超速容忍时间: \(speedViolationTimeout) 秒")
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

        // ⚠️ 重要：先获取探索数据（在停止追踪之前！）
        // 因为 stopPathTracking() 会清空 totalDistance 等数据
        let distance = locationManager.totalDistance
        let duration = locationManager.trackingDuration
        let path = Array(locationManager.pathCoordinates)  // 复制一份，避免被清空

        // 然后停止位置追踪（这会清空数据）
        locationManager.stopPathTracking()

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

        // 停止位置追踪
        locationManager.stopPathTracking()

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

        // 停止定时器
        stopCountdownTimer()

        // 清理 LocationManager 的路径数据
        locationManager.clearPath()
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
