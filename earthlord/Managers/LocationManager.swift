//
//  LocationManager.swift
//  earthlord
//
//  GPS 定位管理器
//  负责请求定位权限、获取用户位置
//

import Foundation
import CoreLocation
import Combine
import UIKit

// MARK: - 定位管理器
/// 管理 GPS 定位功能
@MainActor
class LocationManager: NSObject, ObservableObject {

    // MARK: - 单例
    static let shared = LocationManager()

    // MARK: - 发布属性

    /// 用户当前位置
    @Published var userLocation: CLLocationCoordinate2D?

    /// 授权状态
    @Published var authorizationStatus: CLAuthorizationStatus

    /// 错误信息
    @Published var locationError: String?

    /// 是否正在定位
    @Published var isLocating: Bool = false

    // MARK: - 私有属性

    /// CoreLocation 定位管理器
    private let locationManager = CLLocationManager()

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

    // MARK: - 初始化

    override init() {
        // 获取当前授权状态
        self.authorizationStatus = locationManager.authorizationStatus

        super.init()

        // 配置定位管理器
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest  // 最高精度
        locationManager.distanceFilter = 10  // 移动10米才更新

        print("📍 [定位管理器] 初始化完成，当前授权状态: \(authorizationStatusDescription)")
    }

    // MARK: - 公开方法

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

    // MARK: - 私有方法

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
            self.userLocation = location.coordinate
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
