//
//  PlayerLocationManager.swift
//  earthlord
//
//  玩家位置管理器
//  负责位置上报、在线状态管理、附近玩家查询
//  Day22: 附近玩家检测方案
//

import Foundation
import CoreLocation
import Combine
import Supabase

@MainActor
class PlayerLocationManager: ObservableObject {

    // MARK: - 单例
    static let shared = PlayerLocationManager()

    // MARK: - 依赖
    private let locationManager = LocationManager.shared

    // MARK: - 发布属性

    /// 附近玩家数量
    @Published var nearbyPlayerCount: Int = 0

    /// 是否正在上报
    @Published var isReporting: Bool = false

    /// 上次上报时间
    @Published var lastReportTime: Date?

    // MARK: - 常量

    /// 上报间隔（30秒）
    private let reportInterval: TimeInterval = 30.0

    /// 触发即时上报的最小移动距离（50米）
    private let minDistanceForReport: Double = 50.0

    /// 默认查询半径（1公里）
    private let defaultQueryRadius: Int = 1000

    // MARK: - 私有属性

    /// 定时上报定时器
    private var reportTimer: Timer?

    /// 上次上报的位置
    private var lastReportedLocation: CLLocation?

    /// 订阅集合
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 初始化

    private init() {
        print("📡 [玩家位置] 初始化")
        setupLocationObserver()
    }

    // MARK: - 位置观察

    /// 设置位置监听（用于检测移动距离）
    private func setupLocationObserver() {
        locationManager.$userLocation
            .compactMap { $0 }
            .sink { [weak self] coordinate in
                self?.checkDistanceForReport(coordinate)
            }
            .store(in: &cancellables)
    }

    // MARK: - 公开方法

    /// 开始位置上报（App 启动时调用）
    func startReporting() {
        guard !isReporting else {
            print("📡 [玩家位置] 已在上报中")
            return
        }

        isReporting = true
        print("📡 [玩家位置] 开始位置上报（每 \(Int(reportInterval)) 秒）")

        // 立即上报一次
        Task { await reportLocationNow() }

        // 启动定时器
        reportTimer = Timer.scheduledTimer(withTimeInterval: reportInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.reportLocationNow()
            }
        }
    }

    /// 停止位置上报（App 进入后台时调用）
    func stopReporting() {
        reportTimer?.invalidate()
        reportTimer = nil
        isReporting = false
        print("📡 [玩家位置] 停止位置上报")
    }

    /// 立即上报当前位置
    func reportLocationNow() async {
        guard let coordinate = locationManager.userLocation else {
            print("📡 [玩家位置] 无法获取当前位置，跳过上报")
            return
        }

        do {
            try await uploadLocation(lat: coordinate.latitude, lon: coordinate.longitude, isOnline: true)
            lastReportTime = Date()
            lastReportedLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            print("📡 [玩家位置] ✅ 位置上报成功: (\(String(format: "%.4f", coordinate.latitude)), \(String(format: "%.4f", coordinate.longitude)))")
        } catch {
            print("📡 [玩家位置] ❌ 位置上报失败: \(error)")
        }
    }

    /// 查询附近玩家数量
    /// - Parameter radius: 查询半径（米），默认 1000 米
    /// - Returns: 附近在线玩家数量（不含自己）
    func queryNearbyPlayers(radius: Int = 1000) async -> Int {
        guard let coordinate = locationManager.userLocation else {
            print("📡 [玩家位置] 无法获取位置，返回 0")
            return 0
        }

        do {
            let params = CountNearbyParams(
                pLat: coordinate.latitude,
                pLon: coordinate.longitude,
                pRadiusMeters: radius
            )

            let count: Int = try await supabase
                .rpc("count_nearby_players", params: params)
                .execute()
                .value

            nearbyPlayerCount = count
            print("📡 [玩家位置] 附近 \(radius)m 内有 \(count) 个其他玩家")
            return count
        } catch {
            print("📡 [玩家位置] ❌ 查询附近玩家失败: \(error)")
            return 0
        }
    }

    /// 标记为离线（App 进入后台时调用）
    func markOffline() async {
        guard let coordinate = locationManager.userLocation else {
            print("📡 [玩家位置] 无法获取位置，跳过离线标记")
            return
        }

        do {
            try await uploadLocation(lat: coordinate.latitude, lon: coordinate.longitude, isOnline: false)
            print("📡 [玩家位置] 已标记为离线")
        } catch {
            print("📡 [玩家位置] ❌ 标记离线失败: \(error)")
        }
    }

    // MARK: - 私有方法

    /// 检查是否需要触发即时上报（移动超过 50 米）
    private func checkDistanceForReport(_ coordinate: CLLocationCoordinate2D) {
        // 只在上报模式下检测
        guard isReporting else { return }

        // 需要有上次位置才能计算
        guard let lastLocation = lastReportedLocation else { return }

        let currentLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let distance = currentLocation.distance(from: lastLocation)

        if distance >= minDistanceForReport {
            print("📡 [玩家位置] 移动 \(Int(distance))m（≥\(Int(minDistanceForReport))m），触发即时上报")
            Task { await reportLocationNow() }
        }
    }

    /// 上报位置到服务器
    private func uploadLocation(lat: Double, lon: Double, isOnline: Bool) async throws {
        let params = UpsertLocationParams(pLat: lat, pLon: lon, pIsOnline: isOnline)
        try await supabase.rpc("upsert_player_location", params: params).execute()
    }
}

// MARK: - RPC 参数结构

/// 上报位置参数
struct UpsertLocationParams: Encodable, Sendable {
    let pLat: Double
    let pLon: Double
    let pIsOnline: Bool

    enum CodingKeys: String, CodingKey {
        case pLat = "p_lat"
        case pLon = "p_lon"
        case pIsOnline = "p_is_online"
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pLat, forKey: .pLat)
        try container.encode(pLon, forKey: .pLon)
        try container.encode(pIsOnline, forKey: .pIsOnline)
    }
}

/// 查询附近玩家参数
struct CountNearbyParams: Encodable, Sendable {
    let pLat: Double
    let pLon: Double
    let pRadiusMeters: Int

    enum CodingKeys: String, CodingKey {
        case pLat = "p_lat"
        case pLon = "p_lon"
        case pRadiusMeters = "p_radius_meters"
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pLat, forKey: .pLat)
        try container.encode(pLon, forKey: .pLon)
        try container.encode(pRadiusMeters, forKey: .pRadiusMeters)
    }
}
