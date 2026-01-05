//
//  CoordinateConverter.swift
//  earthlord
//
//  坐标转换工具
//  WGS-84 (GPS标准) → GCJ-02 (中国加密坐标)
//  解决中国地图 GPS 偏移问题
//

import Foundation
import CoreLocation

// MARK: - 坐标转换器
/// 处理 WGS-84 与 GCJ-02 坐标系之间的转换
/// - WGS-84: GPS 硬件返回的国际标准坐标
/// - GCJ-02: 中国法规要求的加密坐标（火星坐标）
/// - 如果不转换，轨迹会偏移 100-500 米！
struct CoordinateConverter {

    // MARK: - 常量

    /// 长半轴（赤道半径）
    private static let a: Double = 6378245.0

    /// 扁率
    private static let ee: Double = 0.00669342162296594323

    /// 圆周率
    private static let pi: Double = Double.pi

    // MARK: - 公开方法

    /// WGS-84 转 GCJ-02
    /// - Parameter wgs: WGS-84 坐标（GPS 原始坐标）
    /// - Returns: GCJ-02 坐标（中国地图坐标）
    static func wgs84ToGcj02(_ wgs: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        // 判断是否在中国境内
        if isOutOfChina(lat: wgs.latitude, lng: wgs.longitude) {
            // 不在中国境内，无需转换
            return wgs
        }

        // 计算偏移量
        var dLat = transformLat(x: wgs.longitude - 105.0, y: wgs.latitude - 35.0)
        var dLng = transformLng(x: wgs.longitude - 105.0, y: wgs.latitude - 35.0)

        let radLat = wgs.latitude / 180.0 * pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)

        dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * pi)
        dLng = (dLng * 180.0) / (a / sqrtMagic * cos(radLat) * pi)

        let gcjLat = wgs.latitude + dLat
        let gcjLng = wgs.longitude + dLng

        return CLLocationCoordinate2D(latitude: gcjLat, longitude: gcjLng)
    }

    /// GCJ-02 转 WGS-84（近似算法）
    /// - Parameter gcj: GCJ-02 坐标
    /// - Returns: WGS-84 坐标（近似值）
    static func gcj02ToWgs84(_ gcj: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        // 判断是否在中国境内
        if isOutOfChina(lat: gcj.latitude, lng: gcj.longitude) {
            return gcj
        }

        // 使用逆向计算
        let wgs = wgs84ToGcj02(gcj)
        let dLat = wgs.latitude - gcj.latitude
        let dLng = wgs.longitude - gcj.longitude

        return CLLocationCoordinate2D(
            latitude: gcj.latitude - dLat,
            longitude: gcj.longitude - dLng
        )
    }

    /// 批量转换坐标数组
    /// - Parameter coordinates: WGS-84 坐标数组
    /// - Returns: GCJ-02 坐标数组
    static func convertPath(_ coordinates: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        return coordinates.map { wgs84ToGcj02($0) }
    }

    // MARK: - 私有方法

    /// 判断坐标是否在中国境外
    private static func isOutOfChina(lat: Double, lng: Double) -> Bool {
        // 中国大致范围：纬度 3.86 ~ 53.55，经度 73.66 ~ 135.05
        if lng < 72.004 || lng > 137.8347 {
            return true
        }
        if lat < 0.8293 || lat > 55.8271 {
            return true
        }
        return false
    }

    /// 纬度转换
    private static func transformLat(x: Double, y: Double) -> Double {
        var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0
        ret += (20.0 * sin(y * pi) + 40.0 * sin(y / 3.0 * pi)) * 2.0 / 3.0
        ret += (160.0 * sin(y / 12.0 * pi) + 320.0 * sin(y * pi / 30.0)) * 2.0 / 3.0
        return ret
    }

    /// 经度转换
    private static func transformLng(x: Double, y: Double) -> Double {
        var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0
        ret += (20.0 * sin(x * pi) + 40.0 * sin(x / 3.0 * pi)) * 2.0 / 3.0
        ret += (150.0 * sin(x / 12.0 * pi) + 300.0 * sin(x / 30.0 * pi)) * 2.0 / 3.0
        return ret
    }
}
