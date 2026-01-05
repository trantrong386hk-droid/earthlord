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

    // MARK: - 发布属性（速度检测相关）

    /// 速度警告信息
    @Published var speedWarning: String?

    /// 是否超速
    @Published var isOverSpeed: Bool = false

    // MARK: - 私有属性

    /// CoreLocation 定位管理器
    private let locationManager = CLLocationManager()

    /// 当前位置（供 Timer 使用）
    private var currentLocation: CLLocation?

    /// 路径采点定时器
    private var pathUpdateTimer: Timer?

    /// 上次位置时间戳（用于速度计算）
    private var lastLocationTimestamp: Date?

    /// 上次位置（用于速度计算）
    private var lastRecordedLocation: CLLocation?

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
            return
        }

        guard !isTracking else {
            print("📍 [路径追踪] 已在追踪中")
            return
        }

        print("📍 [路径追踪] 开始追踪...")

        // 清除之前的路径
        clearPath()

        // 设置追踪状态
        isTracking = true
        isPathClosed = false

        // 清除速度检测状态
        speedWarning = nil
        isOverSpeed = false
        lastLocationTimestamp = nil
        lastRecordedLocation = nil

        // 确保定位已开启
        if !isLocating {
            startUpdatingLocation()
        }

        // 如果已有当前位置，立即记录第一个点
        if let location = currentLocation {
            addPathPoint(location.coordinate)
        }

        // 启动定时器，每2秒检查一次
        pathUpdateTimer = Timer.scheduledTimer(withTimeInterval: trackingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordPathPoint()
            }
        }
    }

    /// 停止路径追踪
    func stopPathTracking() {
        guard isTracking else {
            print("📍 [路径追踪] 未在追踪中")
            return
        }

        print("📍 [路径追踪] 停止追踪，共记录 \(pathCoordinates.count) 个点")

        // 停止定时器
        pathUpdateTimer?.invalidate()
        pathUpdateTimer = nil

        // 设置追踪状态
        isTracking = false

        // 检查路径是否闭合（起点和终点距离小于20米）
        checkPathClosure()
    }

    /// 清除路径
    func clearPath() {
        print("📍 [路径追踪] 清除路径")
        pathCoordinates.removeAll()
        pathUpdateVersion += 1
        isPathClosed = false
    }

    // MARK: - 私有方法（路径追踪）

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
        pathCoordinates.append(coordinate)
        pathUpdateVersion += 1
        print("📍 [路径追踪] 记录点 #\(pathCoordinates.count): \(coordinate.latitude), \(coordinate.longitude)")
    }

    /// 检查路径是否闭合
    private func checkPathClosure() {
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
        } else {
            print("📍 [闭环检测] 距离起点: \(String(format: "%.1f", distance))米，需要 ≤\(closureDistanceThreshold)米")
        }
    }

    // MARK: - 私有方法（速度检测）

    /// 验证移动速度
    /// - Parameter newLocation: 新位置
    /// - Returns: true 表示速度正常，false 表示超速
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

        print("🚗 [速度检测] 速度: \(String(format: "%.1f", speedKmh)) km/h")

        // 更新记录
        lastRecordedLocation = newLocation
        lastLocationTimestamp = Date()

        // 检查是否超过停止阈值
        if speedKmh > stopSpeedThreshold {
            speedWarning = "速度过快（\(String(format: "%.0f", speedKmh)) km/h），已停止追踪"
            isOverSpeed = true
            print("🚗 [速度检测] ⛔ 严重超速！自动停止追踪")
            stopPathTracking()
            return false
        }

        // 检查是否超过警告阈值
        if speedKmh > warningSpeedThreshold {
            speedWarning = "移动速度过快（\(String(format: "%.0f", speedKmh)) km/h），请步行"
            isOverSpeed = true
            print("🚗 [速度检测] ⚠️ 速度警告")
            return false
        }

        // 速度正常，清除警告
        if isOverSpeed {
            speedWarning = nil
            isOverSpeed = false
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
