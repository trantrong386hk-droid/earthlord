//
//  LocationManager.swift
//  earthlord
//
//  GPS 定位管理器
//  负责请求定位权限、获取用户位置、路径追踪
//

import Foundation
import CoreLocation
import Combine
import UIKit

// MARK: - 定位管理器
/// 管理 GPS 定位功能和路径追踪
@MainActor
class LocationManager: NSObject, ObservableObject {

    // MARK: - 单例
    static let shared = LocationManager()

    // MARK: - 发布属性（定位相关）

    /// 用户当前位置
    @Published var userLocation: CLLocationCoordinate2D?

    /// 授权状态
    @Published var authorizationStatus: CLAuthorizationStatus

    /// 错误信息
    @Published var locationError: String?

    /// 是否正在定位
    @Published var isLocating: Bool = false

    // MARK: - 发布属性（路径追踪相关）

    /// 是否正在追踪路径
    @Published var isTracking: Bool = false

    /// 路径坐标数组（存储原始 WGS-84 坐标）
    @Published var pathCoordinates: [CLLocationCoordinate2D] = []

    /// 路径更新版本号（用于触发 SwiftUI 更新）
    @Published var pathUpdateVersion: Int = 0

    /// 路径是否闭合（用于圈地判断）
    @Published var isPathClosed: Bool = false

    // MARK: - 发布属性（统计相关）

    /// 追踪时长（秒）
    @Published var trackingDuration: TimeInterval = 0

    /// 累计距离（米）
    @Published var totalDistance: Double = 0

    // MARK: - 发布属性（速度检测相关）

    /// 速度警告信息
    @Published var speedWarning: String?

    /// 是否超速
    @Published var isOverSpeed: Bool = false

    // MARK: - 发布属性（验证相关）

    /// 领地验证是否通过
    @Published var territoryValidationPassed: Bool = false

    /// 领地验证错误信息
    @Published var territoryValidationError: String? = nil

    /// 计算出的领地面积（平方米）
    @Published var calculatedArea: Double = 0

    // MARK: - 发布属性（实时状态）

    /// 距离起点的实时距离（米）
    @Published var distanceToStart: Double = 0

    /// 是否存在自相交（实时检测）
    @Published var hasSelfIntersection: Bool = false

    /// 当前速度（km/h）
    @Published var currentSpeed: Double = 0

    // MARK: - 私有属性

    /// CoreLocation 定位管理器
    private let locationManager = CLLocationManager()

    /// 当前位置（供 Timer 使用）
    private var currentLocation: CLLocation?

    /// 路径采点定时器
    private var pathUpdateTimer: Timer?

    /// 时长更新定时器
    private var durationTimer: Timer?

    /// 追踪开始时间
    private var trackingStartTime: Date?

    /// 上次位置时间戳（用于速度计算）
    private var lastLocationTimestamp: Date?

    /// 上次位置（用于速度计算）
    private var lastRecordedLocation: CLLocation?

    /// 是否已记录闭环成功（防止重复记录）
    private var hasLoggedClosure: Bool = false

    /// 连续超速次数（用于区分GPS漂移和真正超速）
    private var consecutiveOverSpeedCount: Int = 0

    // MARK: - 常量

    /// 最小采点距离（米）
    private let minDistanceForNewPoint: Double = 10.0

    /// 采点时间间隔（秒）
    private let trackingInterval: TimeInterval = 2.0

    /// 闭环距离阈值（米）
    private let closureDistanceThreshold: Double = 30.0

    /// 最少路径点数（闭环检测需要）
    private let minimumPathPoints: Int = 10

    /// 警告速度阈值（km/h）
    private let warningSpeedThreshold: Double = 15.0

    /// 停止追踪速度阈值（km/h）
    private let stopSpeedThreshold: Double = 30.0

    /// GPS漂移判定阈值（km/h）- 超过此值视为GPS漂移而非真实移动
    private let gpsDriftThreshold: Double = 50.0

    /// 触发警告所需的连续超速次数
    private let warningConsecutiveCount: Int = 2

    /// 触发停止所需的连续超速次数
    private let stopConsecutiveCount: Int = 2

    // MARK: - 验证常量

    /// 最小行走距离（米）
    private let minimumTotalDistance: Double = 50.0

    /// 最小领地面积（平方米）
    private let minimumEnclosedArea: Double = 100.0

    // MARK: - 计算属性

    /// 是否已授权定位
    var isAuthorized: Bool {
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        default:
            return false
        }
    }

    /// 是否被拒绝定位
    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    /// 是否未决定（首次使用）
    var isNotDetermined: Bool {
        authorizationStatus == .notDetermined
    }

    /// 路径点数量
    var pathPointCount: Int {
        pathCoordinates.count
    }

    // MARK: - 初始化

    override init() {
        // 获取当前授权状态
        self.authorizationStatus = locationManager.authorizationStatus

        super.init()

        // 配置定位管理器
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest  // 最高精度
        locationManager.distanceFilter = 5  // 移动5米才更新（追踪时需要更精确）

        print("📍 [定位管理器] 初始化完成，当前授权状态: \(authorizationStatusDescription)")
    }

    // MARK: - 公开方法（定位相关）

    /// 请求定位权限
    func requestPermission() {
        print("📍 [定位管理器] 请求定位权限...")
        locationManager.requestWhenInUseAuthorization()
    }

    /// 开始定位
    func startUpdatingLocation() {
        guard isAuthorized else {
            print("📍 [定位管理器] 未授权，无法开始定位")
            if isNotDetermined {
                requestPermission()
            }
            return
        }

        print("📍 [定位管理器] 开始定位...")
        isLocating = true
        locationError = nil
        locationManager.startUpdatingLocation()
    }

    /// 停止定位
    func stopUpdatingLocation() {
        print("📍 [定位管理器] 停止定位")
        isLocating = false
        locationManager.stopUpdatingLocation()
    }

    /// 请求一次性位置更新
    func requestLocation() {
        guard isAuthorized else {
            print("📍 [定位管理器] 未授权，无法请求位置")
            if isNotDetermined {
                requestPermission()
            }
            return
        }

        print("📍 [定位管理器] 请求单次位置...")
        locationError = nil
        locationManager.requestLocation()
    }

    /// 打开系统设置
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - 公开方法（路径追踪相关）

    /// 开始路径追踪
    func startPathTracking() {
        guard isAuthorized else {
            print("📍 [路径追踪] 未授权，无法开始追踪")
            TerritoryLogger.shared.log("开始追踪失败：未授权定位", type: .error)
            return
        }

        guard !isTracking else {
            print("📍 [路径追踪] 已在追踪中")
            return
        }

        print("📍 [路径追踪] 开始追踪...")
        TerritoryLogger.shared.log("开始路径追踪", type: .info)

        // 清除之前的路径
        clearPath()

        // 设置追踪状态
        isTracking = true
        isPathClosed = false
        hasLoggedClosure = false  // 重置闭环日志标记

        // 重置验证状态
        territoryValidationPassed = false
        territoryValidationError = nil
        calculatedArea = 0

        // 重置实时状态
        distanceToStart = 0
        hasSelfIntersection = false
        currentSpeed = 0

        // 重置统计数据
        trackingDuration = 0
        totalDistance = 0
        trackingStartTime = Date()

        // 清除速度检测状态
        speedWarning = nil
        isOverSpeed = false
        lastLocationTimestamp = nil
        lastRecordedLocation = nil
        consecutiveOverSpeedCount = 0

        // 确保定位已开启
        if !isLocating {
            startUpdatingLocation()
        }

        // 如果已有当前位置，立即记录第一个点
        if let location = currentLocation {
            addPathPoint(location.coordinate)
        }

        // 启动路径采点定时器，每2秒检查一次
        pathUpdateTimer = Timer.scheduledTimer(withTimeInterval: trackingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordPathPoint()
            }
        }

        // 启动时长更新定时器，每秒更新
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateTrackingDuration()
            }
        }
    }

    /// 停止路径追踪
    /// - Parameter keepValidationState: 是否保留验证状态（上传前需要保留）
    func stopPathTracking(keepValidationState: Bool = false) {
        guard isTracking else {
            print("📍 [路径追踪] 未在追踪中")
            return
        }

        print("📍 [路径追踪] 停止追踪，共记录 \(pathCoordinates.count) 个点")
        TerritoryLogger.shared.log("停止路径追踪，共 \(pathCoordinates.count) 个点，距离 \(String(format: "%.0f", totalDistance)) 米", type: .info)

        // 停止定时器
        pathUpdateTimer?.invalidate()
        pathUpdateTimer = nil
        durationTimer?.invalidate()
        durationTimer = nil

        // 设置追踪状态
        isTracking = false

        // 检查路径是否闭合（起点和终点距离小于20米）
        checkPathClosure()

        // 如果不保留验证状态，则重置所有状态
        if !keepValidationState {
            resetAllState()
        }
    }

    /// 重置所有状态（上传成功后调用）
    func resetAllState() {
        print("📍 [路径追踪] 重置所有状态")
        TerritoryLogger.shared.log("重置圈地状态", type: .info)

        // 清除路径
        pathCoordinates.removeAll()
        pathUpdateVersion += 1

        // 重置追踪状态
        isTracking = false
        isPathClosed = false
        hasLoggedClosure = false

        // 重置统计数据
        trackingDuration = 0
        totalDistance = 0

        // 重置验证状态
        territoryValidationPassed = false
        territoryValidationError = nil
        calculatedArea = 0

        // 重置实时状态
        distanceToStart = 0
        hasSelfIntersection = false
        currentSpeed = 0

        // 重置速度检测状态
        speedWarning = nil
        isOverSpeed = false
        consecutiveOverSpeedCount = 0
    }

    /// 清除路径
    func clearPath() {
        print("📍 [路径追踪] 清除路径")
        pathCoordinates.removeAll()
        pathUpdateVersion += 1
        isPathClosed = false
        trackingDuration = 0
        totalDistance = 0
        distanceToStart = 0
        hasSelfIntersection = false
    }

    /// 格式化时长为 mm:ss 格式
    var formattedDuration: String {
        let minutes = Int(trackingDuration) / 60
        let seconds = Int(trackingDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// 格式化距离（米）
    var formattedDistance: String {
        if totalDistance >= 1000 {
            return String(format: "%.1f 公里", totalDistance / 1000)
        } else {
            return String(format: "%.0f 米", totalDistance)
        }
    }

    // MARK: - 私有方法（路径追踪）

    /// 更新追踪时长
    private func updateTrackingDuration() {
        guard let startTime = trackingStartTime else { return }
        trackingDuration = Date().timeIntervalSince(startTime)
    }

    /// 定时器回调：判断是否记录新点
    private func recordPathPoint() {
        guard isTracking else { return }
        guard let location = currentLocation else {
            print("📍 [路径追踪] 当前位置不可用")
            return
        }

        // 速度检测（超速时不记录该点）
        if !validateMovementSpeed(newLocation: location) {
            return
        }

        let coordinate = location.coordinate

        // 检查是否需要记录新点
        if shouldRecordPoint(coordinate) {
            addPathPoint(coordinate)

            // 记录新坐标后检查闭环
            checkPathClosure()
        }
    }

    /// 判断是否应该记录该点
    private func shouldRecordPoint(_ coordinate: CLLocationCoordinate2D) -> Bool {
        // 如果是第一个点，直接记录
        guard let lastCoordinate = pathCoordinates.last else {
            return true
        }

        // 计算与上一个点的距离
        let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
        let newLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let distance = newLocation.distance(from: lastLocation)

        // 距离超过阈值才记录
        return distance >= minDistanceForNewPoint
    }

    /// 添加路径点
    private func addPathPoint(_ coordinate: CLLocationCoordinate2D) {
        // 计算与上一个点的距离并累加
        if let lastCoordinate = pathCoordinates.last {
            let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
            let newLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let distance = newLocation.distance(from: lastLocation)
            totalDistance += distance
        }

        pathCoordinates.append(coordinate)
        pathUpdateVersion += 1
        print("📍 [路径追踪] 记录点 #\(pathCoordinates.count): \(coordinate.latitude), \(coordinate.longitude)")
        TerritoryLogger.shared.log("记录点 #\(pathCoordinates.count): (\(String(format: "%.6f", coordinate.latitude)), \(String(format: "%.6f", coordinate.longitude)))", type: .info)

        // ⭐ 更新实时状态
        updateRealtimeStatus()
    }

    /// 更新实时状态（距离起点、自交检测）
    private func updateRealtimeStatus() {
        // 1. 计算距离起点的距离
        if let first = pathCoordinates.first, let last = pathCoordinates.last, pathCoordinates.count >= 2 {
            let firstLocation = CLLocation(latitude: first.latitude, longitude: first.longitude)
            let lastLocation = CLLocation(latitude: last.latitude, longitude: last.longitude)
            distanceToStart = lastLocation.distance(from: firstLocation)
        } else {
            distanceToStart = 0
        }

        // 2. 实时自交检测（只在点数足够时检测，避免性能问题）
        if pathCoordinates.count >= 4 {
            hasSelfIntersection = checkRealtimeSelfIntersection()
        } else {
            hasSelfIntersection = false
        }
    }

    /// 实时自交检测（轻量版，只检测最新线段）
    private func checkRealtimeSelfIntersection() -> Bool {
        guard pathCoordinates.count >= 4 else { return false }

        let pathSnapshot = Array(pathCoordinates)
        let lastIndex = pathSnapshot.count - 1

        // 只检测最新添加的线段是否与之前的线段相交
        let p3 = pathSnapshot[lastIndex - 1]
        let p4 = pathSnapshot[lastIndex]

        // 跳过相邻线段和首尾几条线段
        let skipTailCount = 3  // 跳过最后3条线段（避免与自己相邻的比较）

        for i in 0..<(lastIndex - skipTailCount) {
            let p1 = pathSnapshot[i]
            let p2 = pathSnapshot[i + 1]

            if segmentsIntersect(p1: p1, p2: p2, p3: p3, p4: p4) {
                TerritoryLogger.shared.log("实时自交: 线段\(i)-\(i+1) 与最新线段相交", type: .warning)
                return true
            }
        }
        return false
    }

    /// 检查路径是否闭合
    private func checkPathClosure() {
        // 已闭合则不再检测
        guard !isPathClosed else { return }

        // 检查点数是否足够
        guard pathCoordinates.count >= minimumPathPoints else {
            print("📍 [闭环检测] 点数不足：\(pathCoordinates.count)/\(minimumPathPoints)")
            return
        }

        guard let first = pathCoordinates.first, let last = pathCoordinates.last else {
            print("📍 [闭环检测] 无法获取起点或终点")
            return
        }

        let firstLocation = CLLocation(latitude: first.latitude, longitude: first.longitude)
        let lastLocation = CLLocation(latitude: last.latitude, longitude: last.longitude)
        let distance = lastLocation.distance(from: firstLocation)

        // 起点和终点距离小于阈值视为闭合
        if distance <= closureDistanceThreshold {
            isPathClosed = true
            pathUpdateVersion += 1  // 触发轨迹变色
            print("📍 [闭环检测] ✅ 闭环成功！起终点距离: \(String(format: "%.1f", distance))米")

            // 只记录一次闭环成功日志
            if !hasLoggedClosure {
                hasLoggedClosure = true
                TerritoryLogger.shared.log("闭环成功！距离起点 \(String(format: "%.1f", distance))米", type: .success)

                // ⭐ 闭环成功后自动触发领地验证
                let validationResult = validateTerritory()
                territoryValidationPassed = validationResult.isValid
                territoryValidationError = validationResult.errorMessage
            }
        } else {
            print("📍 [闭环检测] 距离起点: \(String(format: "%.1f", distance))米，需要 ≤\(closureDistanceThreshold)米")
        }
    }

    // MARK: - 距离与面积计算

    /// 计算路径总距离
    /// - Returns: 总距离（米）
    private func calculateTotalPathDistance() -> Double {
        guard pathCoordinates.count >= 2 else { return 0 }

        var distance: Double = 0
        for i in 0..<(pathCoordinates.count - 1) {
            let current = CLLocation(latitude: pathCoordinates[i].latitude,
                                     longitude: pathCoordinates[i].longitude)
            let next = CLLocation(latitude: pathCoordinates[i + 1].latitude,
                                  longitude: pathCoordinates[i + 1].longitude)
            distance += next.distance(from: current)
        }
        return distance
    }

    /// 使用鞋带公式计算多边形面积（考虑地球曲率）
    /// - Returns: 面积（平方米）
    private func calculatePolygonArea() -> Double {
        guard pathCoordinates.count >= 3 else { return 0 }

        let earthRadius: Double = 6371000  // 地球半径（米）
        var area: Double = 0

        for i in 0..<pathCoordinates.count {
            let current = pathCoordinates[i]
            let next = pathCoordinates[(i + 1) % pathCoordinates.count]  // 循环取点

            // 经纬度转弧度
            let lat1 = current.latitude * .pi / 180
            let lon1 = current.longitude * .pi / 180
            let lat2 = next.latitude * .pi / 180
            let lon2 = next.longitude * .pi / 180

            // 鞋带公式（球面修正）
            area += (lon2 - lon1) * (2 + sin(lat1) + sin(lat2))
        }

        area = abs(area * earthRadius * earthRadius / 2.0)
        return area
    }

    // MARK: - 自相交检测（CCW 算法）

    /// 判断两线段是否相交（使用 CCW 算法）
    /// - Parameters:
    ///   - p1: 线段1起点
    ///   - p2: 线段1终点
    ///   - p3: 线段2起点
    ///   - p4: 线段2终点
    /// - Returns: true 表示相交
    private func segmentsIntersect(p1: CLLocationCoordinate2D,
                                   p2: CLLocationCoordinate2D,
                                   p3: CLLocationCoordinate2D,
                                   p4: CLLocationCoordinate2D) -> Bool {
        /// CCW 辅助函数：判断三点是否逆时针排列
        /// - 坐标映射：longitude = X轴，latitude = Y轴
        /// - 叉积 = (Cy - Ay) × (Bx - Ax) - (By - Ay) × (Cx - Ax)
        /// - 叉积 > 0 则为逆时针
        func ccw(_ a: CLLocationCoordinate2D,
                 _ b: CLLocationCoordinate2D,
                 _ c: CLLocationCoordinate2D) -> Bool {
            let crossProduct = (c.latitude - a.latitude) * (b.longitude - a.longitude) -
                               (b.latitude - a.latitude) * (c.longitude - a.longitude)
            return crossProduct > 0
        }

        // 判断逻辑：
        // ccw(p1, p3, p4) ≠ ccw(p2, p3, p4) 且
        // ccw(p1, p2, p3) ≠ ccw(p1, p2, p4)
        return ccw(p1, p3, p4) != ccw(p2, p3, p4) &&
               ccw(p1, p2, p3) != ccw(p1, p2, p4)
    }

    /// 检测路径是否自相交
    /// - Returns: true 表示存在自相交
    func hasPathSelfIntersection() -> Bool {
        // ✅ 防御性检查：至少需要4个点才可能自交
        guard pathCoordinates.count >= 4 else { return false }

        // ✅ 创建路径快照的深拷贝，避免并发修改问题
        let pathSnapshot = Array(pathCoordinates)

        // ✅ 再次检查快照是否有效
        guard pathSnapshot.count >= 4 else { return false }

        let segmentCount = pathSnapshot.count - 1

        // ✅ 防御性检查：确保有足够的线段
        guard segmentCount >= 2 else { return false }

        // ✅ 闭环时需要跳过的首尾线段数量（防止正常圈地被误判）
        let skipHeadCount = 2
        let skipTailCount = 2

        for i in 0..<segmentCount {
            // ✅ 循环内索引检查
            guard i < pathSnapshot.count - 1 else { break }

            let p1 = pathSnapshot[i]
            let p2 = pathSnapshot[i + 1]

            let startJ = i + 2
            guard startJ < segmentCount else { continue }

            for j in startJ..<segmentCount {
                // ✅ 循环内索引检查
                guard j < pathSnapshot.count - 1 else { break }

                // ✅ 跳过首尾附近线段的比较（防止正常闭环被误判为自交）
                let isHeadSegment = i < skipHeadCount
                let isTailSegment = j >= segmentCount - skipTailCount
                if isHeadSegment && isTailSegment {
                    continue
                }

                let p3 = pathSnapshot[j]
                let p4 = pathSnapshot[j + 1]

                if segmentsIntersect(p1: p1, p2: p2, p3: p3, p4: p4) {
                    TerritoryLogger.shared.log("自交检测: 线段\(i)-\(i+1) 与 线段\(j)-\(j+1) 相交", type: .error)
                    return true
                }
            }
        }

        TerritoryLogger.shared.log("自交检测: 无交叉 ✓", type: .info)
        return false
    }

    // MARK: - 综合验证

    /// 综合验证领地是否有效
    /// - Returns: (是否有效, 错误信息)
    func validateTerritory() -> (isValid: Bool, errorMessage: String?) {
        TerritoryLogger.shared.log("开始领地验证", type: .info)

        // 1. 点数检查
        let pointCount = pathCoordinates.count
        if pointCount < minimumPathPoints {
            let error = "点数不足: \(pointCount)个 (需≥\(minimumPathPoints)个)"
            TerritoryLogger.shared.log("点数检查: \(error)", type: .error)
            TerritoryLogger.shared.log("领地验证失败！\(error)", type: .error)
            return (false, error)
        }
        TerritoryLogger.shared.log("点数检查: \(pointCount)个点 ✓", type: .info)

        // 2. 距离检查
        let distance = calculateTotalPathDistance()
        if distance < minimumTotalDistance {
            let error = "距离不足: \(String(format: "%.0f", distance))m (需≥\(Int(minimumTotalDistance))m)"
            TerritoryLogger.shared.log("距离检查: \(error)", type: .error)
            TerritoryLogger.shared.log("领地验证失败！\(error)", type: .error)
            return (false, error)
        }
        TerritoryLogger.shared.log("距离检查: \(String(format: "%.0f", distance))m ✓", type: .info)

        // 3. 自交检测
        if hasPathSelfIntersection() {
            let error = "轨迹自相交，请勿画8字形"
            TerritoryLogger.shared.log("领地验证失败！\(error)", type: .error)
            return (false, error)
        }

        // 4. 面积检查
        let area = calculatePolygonArea()
        calculatedArea = area  // 保存计算结果
        if area < minimumEnclosedArea {
            let error = "面积不足: \(String(format: "%.0f", area))m² (需≥\(Int(minimumEnclosedArea))m²)"
            TerritoryLogger.shared.log("面积检查: \(error)", type: .error)
            TerritoryLogger.shared.log("领地验证失败！\(error)", type: .error)
            return (false, error)
        }
        TerritoryLogger.shared.log("面积检查: \(String(format: "%.0f", area))m² ✓", type: .info)

        // 全部通过
        TerritoryLogger.shared.log("领地验证通过！面积: \(String(format: "%.0f", area))m²", type: .success)
        return (true, nil)
    }

    // MARK: - 私有方法（速度检测）

    /// 验证移动速度
    /// - Parameter newLocation: 新位置
    /// - Returns: true 表示速度正常，false 表示超速或GPS漂移
    private func validateMovementSpeed(newLocation: CLLocation) -> Bool {
        // 第一个点，记录时间戳并返回正常
        guard let lastLocation = lastRecordedLocation,
              let lastTimestamp = lastLocationTimestamp else {
            lastRecordedLocation = newLocation
            lastLocationTimestamp = Date()
            return true
        }

        // 计算距离（米）
        let distance = newLocation.distance(from: lastLocation)

        // 计算时间差（秒）
        let timeInterval = Date().timeIntervalSince(lastTimestamp)
        guard timeInterval > 0 else { return true }

        // 计算速度（km/h）
        let speedMps = distance / timeInterval  // 米/秒
        let speedKmh = speedMps * 3.6           // 转换为 km/h

        // 更新实时速度（排除 GPS 漂移）
        if speedKmh <= gpsDriftThreshold {
            currentSpeed = speedKmh
        }

        print("🚗 [速度检测] 速度: \(String(format: "%.1f", speedKmh)) km/h，连续超速: \(consecutiveOverSpeedCount)")

        // 更新记录
        lastRecordedLocation = newLocation
        lastLocationTimestamp = Date()

        // 1. GPS漂移检测：速度超过 50 km/h 视为GPS漂移，忽略该点
        if speedKmh > gpsDriftThreshold {
            print("🚗 [速度检测] 🛰️ GPS漂移（\(String(format: "%.0f", speedKmh)) km/h），忽略该点")
            TerritoryLogger.shared.log("GPS漂移检测：\(String(format: "%.0f", speedKmh)) km/h，已忽略", type: .warning)
            // 不增加连续超速计数，因为这是GPS问题
            return false
        }

        // 2. 严重超速检测（> 30 km/h）
        if speedKmh > stopSpeedThreshold {
            consecutiveOverSpeedCount += 1
            print("🚗 [速度检测] ⚠️ 严重超速 \(consecutiveOverSpeedCount)/\(stopConsecutiveCount)")

            if consecutiveOverSpeedCount >= stopConsecutiveCount {
                speedWarning = "速度过快（\(String(format: "%.0f", speedKmh)) km/h），已停止追踪"
                isOverSpeed = true
                print("🚗 [速度检测] ⛔ 连续严重超速！自动停止追踪")
                TerritoryLogger.shared.log("连续严重超速 \(String(format: "%.0f", speedKmh)) km/h，自动停止追踪", type: .error)
                stopPathTracking()
            }
            return false
        }

        // 3. 一般超速检测（> 15 km/h）
        if speedKmh > warningSpeedThreshold {
            consecutiveOverSpeedCount += 1
            print("🚗 [速度检测] ⚠️ 超速 \(consecutiveOverSpeedCount)/\(warningConsecutiveCount)")

            if consecutiveOverSpeedCount >= warningConsecutiveCount {
                speedWarning = "移动速度过快（\(String(format: "%.0f", speedKmh)) km/h），请步行"
                isOverSpeed = true
                print("🚗 [速度检测] ⚠️ 连续超速警告")
                TerritoryLogger.shared.log("连续超速警告 \(String(format: "%.0f", speedKmh)) km/h，请步行", type: .warning)
            }
            return false
        }

        // 4. 速度正常，重置计数器和警告
        consecutiveOverSpeedCount = 0
        if isOverSpeed {
            speedWarning = nil
            isOverSpeed = false
            print("🚗 [速度检测] ✅ 速度恢复正常")
        }

        return true
    }

    /// 授权状态描述
    private var authorizationStatusDescription: String {
        switch authorizationStatus {
        case .notDetermined:
            return "未决定"
        case .restricted:
            return "受限"
        case .denied:
            return "已拒绝"
        case .authorizedAlways:
            return "始终允许"
        case .authorizedWhenInUse:
            return "使用时允许"
        @unknown default:
            return "未知"
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {

    /// 授权状态变化
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus

        Task { @MainActor in
            self.authorizationStatus = status
            print("📍 [定位管理器] 授权状态变化: \(self.authorizationStatusDescription)")

            // 如果已授权，自动开始定位
            if self.isAuthorized {
                self.startUpdatingLocation()
            }
        }
    }

    /// 位置更新
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        Task { @MainActor in
            // 更新用户位置
            self.userLocation = location.coordinate

            // ⭐ 关键：保存当前位置供 Timer 使用
            self.currentLocation = location

            print("📍 [定位管理器] 位置更新: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        }
    }

    /// 定位失败
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.locationError = error.localizedDescription
            print("📍 [定位管理器] 定位失败: \(error.localizedDescription)")
        }
    }
}
