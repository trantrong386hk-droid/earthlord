//
//  Territory.swift
//  earthlord
//
//  领地数据模型
//  与 Supabase territories 表对应
//

import Foundation
import CoreLocation

// MARK: - Territory 模型

struct Territory: Codable, Identifiable {

    // MARK: - 基础字段

    /// 唯一标识
    let id: UUID

    /// 所有者 ID
    let ownerId: UUID

    /// 领地名称（可选）
    var name: String?

    /// 路径坐标数组 [[lat: Double, lon: Double], ...]
    let path: [[String: Double]]

    /// 面积（平方米）
    let areaSqm: Double

    /// 坐标点数量
    let pointCount: Int?

    /// 是否激活
    let isActive: Bool?

    // MARK: - 边界框

    let bboxMinLat: Double?
    let bboxMaxLat: Double?
    let bboxMinLon: Double?
    let bboxMaxLon: Double?

    // MARK: - 时间字段

    let startedAt: Date?
    let completedAt: Date?
    let createdAt: Date?
    let updatedAt: Date?

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case name
        case path
        case areaSqm = "area_sqm"
        case pointCount = "point_count"
        case isActive = "is_active"
        case bboxMinLat = "bbox_min_lat"
        case bboxMaxLat = "bbox_max_lat"
        case bboxMinLon = "bbox_min_lon"
        case bboxMaxLon = "bbox_max_lon"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // MARK: - 便捷方法

    /// 将 path 转换为 CLLocationCoordinate2D 数组
    func toCoordinates() -> [CLLocationCoordinate2D] {
        return path.compactMap { dict in
            guard let lat = dict["lat"], let lon = dict["lon"] else {
                return nil
            }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }

    /// 获取中心点
    var centerCoordinate: CLLocationCoordinate2D? {
        guard let minLat = bboxMinLat,
              let maxLat = bboxMaxLat,
              let minLon = bboxMinLon,
              let maxLon = bboxMaxLon else {
            return nil
        }
        return CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
    }
}

// MARK: - 上传用结构体

/// 用于上传新领地的结构体（不包含服务器生成的字段）
struct TerritoryUpload: Codable {

    let ownerId: UUID
    var name: String?
    let path: [[String: Double]]
    let polygon: String  // WKT 格式
    let areaSqm: Double
    let pointCount: Int
    let bboxMinLat: Double
    let bboxMaxLat: Double
    let bboxMinLon: Double
    let bboxMaxLon: Double
    let startedAt: Date?
    let completedAt: Date?

    enum CodingKeys: String, CodingKey {
        case ownerId = "owner_id"
        case name
        case path
        case polygon
        case areaSqm = "area_sqm"
        case pointCount = "point_count"
        case bboxMinLat = "bbox_min_lat"
        case bboxMaxLat = "bbox_max_lat"
        case bboxMinLon = "bbox_min_lon"
        case bboxMaxLon = "bbox_max_lon"
        case startedAt = "started_at"
        case completedAt = "completed_at"
    }
}
