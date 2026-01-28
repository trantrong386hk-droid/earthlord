//
//  BuildingModels.swift
//  earthlord
//
//  建筑系统数据模型
//  包含建筑分类、状态、模板和玩家建筑
//

import Foundation
import SwiftUI

// MARK: - 建筑分类枚举

/// 建筑分类
enum BuildingCategory: String, Codable, CaseIterable {
    case survival = "survival"       // 生存
    case storage = "storage"         // 储存
    case production = "production"   // 生产
    case energy = "energy"           // 能源

    /// 显示名称
    var displayName: String {
        switch self {
        case .survival:
            return "生存"
        case .storage:
            return "储存"
        case .production:
            return "生产"
        case .energy:
            return "能源"
        }
    }

    /// 图标
    var icon: String {
        switch self {
        case .survival:
            return "flame.fill"
        case .storage:
            return "archivebox.fill"
        case .production:
            return "hammer.fill"
        case .energy:
            return "bolt.fill"
        }
    }
}

// MARK: - 建筑状态枚举

/// 建筑状态
enum BuildingStatus: String, Codable {
    case constructing = "constructing"  // 建造中
    case upgrading = "upgrading"        // 升级中
    case active = "active"              // 运行中

    /// 显示名称
    var displayName: String {
        switch self {
        case .constructing:
            return "建造中"
        case .upgrading:
            return "升级中"
        case .active:
            return "运行中"
        }
    }

    /// 状态颜色
    var color: Color {
        switch self {
        case .constructing:
            return .orange
        case .upgrading:
            return .blue
        case .active:
            return .green
        }
    }

    /// 是否处于进行中状态（建造或升级）
    var isInProgress: Bool {
        self == .constructing || self == .upgrading
    }
}

// MARK: - 建筑模板

/// 建筑模板（从 JSON 加载）
struct BuildingTemplate: Identifiable, Codable {
    let id: UUID
    let templateId: String
    let name: String
    let category: BuildingCategory
    let tier: Int
    let description: String
    let icon: String
    let requiredResources: [String: Int]
    let buildTimeSeconds: Int
    let maxPerTerritory: Int
    let maxLevel: Int

    enum CodingKeys: String, CodingKey {
        case id
        case templateId = "template_id"
        case name
        case category
        case tier
        case description
        case icon
        case requiredResources = "required_resources"
        case buildTimeSeconds = "build_time_seconds"
        case maxPerTerritory = "max_per_territory"
        case maxLevel = "max_level"
    }

    /// 格式化建造时间
    var formattedBuildTime: String {
        if buildTimeSeconds < 60 {
            return "\(buildTimeSeconds)秒"
        } else if buildTimeSeconds < 3600 {
            let minutes = buildTimeSeconds / 60
            let seconds = buildTimeSeconds % 60
            return seconds > 0 ? "\(minutes)分\(seconds)秒" : "\(minutes)分钟"
        } else {
            let hours = buildTimeSeconds / 3600
            let minutes = (buildTimeSeconds % 3600) / 60
            return minutes > 0 ? "\(hours)小时\(minutes)分" : "\(hours)小时"
        }
    }
}

// MARK: - 玩家建筑

/// 玩家建筑实例（对应数据库 player_buildings 表）
struct PlayerBuilding: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let territoryId: String
    let templateId: String
    let buildingName: String
    var status: BuildingStatus
    var level: Int
    let locationLat: Double?
    let locationLon: Double?
    var buildStartedAt: Date
    var buildCompletedAt: Date?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case territoryId = "territory_id"
        case templateId = "template_id"
        case buildingName = "building_name"
        case status
        case level
        case locationLat = "location_lat"
        case locationLon = "location_lon"
        case buildStartedAt = "build_started_at"
        case buildCompletedAt = "build_completed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// 计算建造剩余时间（秒）
    func remainingBuildTime(template: BuildingTemplate) -> Int {
        guard status == .constructing else { return 0 }

        let elapsed = Date().timeIntervalSince(buildStartedAt)
        let remaining = Double(template.buildTimeSeconds) - elapsed
        return max(0, Int(remaining))
    }

    /// 格式化剩余时间
    func formattedRemainingTime(template: BuildingTemplate) -> String {
        let remaining = remainingBuildTime(template: template)
        if remaining <= 0 {
            return "即将完成"
        } else if remaining < 60 {
            return "\(remaining)秒"
        } else {
            let minutes = remaining / 60
            let seconds = remaining % 60
            return "\(minutes)分\(seconds)秒"
        }
    }

    /// 是否已完成建造
    func isConstructionComplete(template: BuildingTemplate) -> Bool {
        return remainingBuildTime(template: template) <= 0
    }
}

// MARK: - 上传用结构体

/// 用于上传新建筑的结构体
struct PlayerBuildingUpload: Codable {
    let userId: UUID
    let territoryId: String
    let templateId: String
    let buildingName: String
    let status: String
    let level: Int
    let locationLat: Double?
    let locationLon: Double?
    let buildStartedAt: Date
    let buildCompletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case territoryId = "territory_id"
        case templateId = "template_id"
        case buildingName = "building_name"
        case status
        case level
        case locationLat = "location_lat"
        case locationLon = "location_lon"
        case buildStartedAt = "build_started_at"
        case buildCompletedAt = "build_completed_at"
    }
}

/// 用于更新建筑的结构体
struct PlayerBuildingUpdate: Codable {
    var status: String?
    var level: Int?
    var buildStartedAt: Date?
    var buildCompletedAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case status
        case level
        case buildStartedAt = "build_started_at"
        case buildCompletedAt = "build_completed_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - 建造错误

/// 建造系统错误类型
enum BuildingError: Error, LocalizedError {
    case insufficientResources([String: Int])
    case maxBuildingsReached(Int)
    case templateNotFound
    case invalidStatus
    case maxLevelReached
    case buildingNotFound
    case notAuthenticated
    case databaseError(String)

    var errorDescription: String? {
        switch self {
        case .insufficientResources(let missing):
            let items = missing.map { "\($0.key) 缺少 \($0.value)" }.joined(separator: ", ")
            return "资源不足：\(items)"
        case .maxBuildingsReached(let max):
            return "该建筑已达上限（最多 \(max) 个）"
        case .templateNotFound:
            return "建筑模板不存在"
        case .invalidStatus:
            return "建筑状态无效"
        case .maxLevelReached:
            return "已达最高等级"
        case .buildingNotFound:
            return "建筑不存在"
        case .notAuthenticated:
            return "用户未登录"
        case .databaseError(let message):
            return "数据库错误：\(message)"
        }
    }
}

// MARK: - 资源需求结果

/// 建造检查结果
struct BuildCheckResult {
    let canBuild: Bool
    let error: BuildingError?

    static let success = BuildCheckResult(canBuild: true, error: nil)

    static func failure(_ error: BuildingError) -> BuildCheckResult {
        return BuildCheckResult(canBuild: false, error: error)
    }
}

// MARK: - PlayerBuilding 扩展

import CoreLocation

extension PlayerBuilding {
    /// 坐标（直接使用，数据库中已是 GCJ-02 坐标）
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = locationLat, let lon = locationLon else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// 建造/升级进度（0.0 ~ 1.0）
    var buildProgress: Double {
        guard status.isInProgress,
              let completedAt = buildCompletedAt else { return status == .active ? 1.0 : 0.0 }
        let total = completedAt.timeIntervalSince(buildStartedAt)
        guard total > 0 else { return 1.0 }
        let elapsed = Date().timeIntervalSince(buildStartedAt)
        return min(1.0, max(0, elapsed / total))
    }

    /// 格式化剩余时间（建造和升级通用）
    var formattedRemainingTime: String {
        guard status.isInProgress,
              let completedAt = buildCompletedAt else { return "" }
        let remaining = completedAt.timeIntervalSince(Date())
        guard remaining > 0 else { return "即将完成" }

        let seconds = Int(remaining)
        if seconds < 60 {
            return "\(seconds)秒"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            let secs = seconds % 60
            return secs > 0 ? "\(minutes)分\(secs)秒" : "\(minutes)分钟"
        } else {
            let hours = seconds / 3600
            let minutes = (seconds % 3600) / 60
            return minutes > 0 ? "\(hours)小时\(minutes)分" : "\(hours)小时"
        }
    }
}

// MARK: - BuildingTemplate Identifiable conformance for sheet

extension BuildingTemplate: Hashable {
    static func == (lhs: BuildingTemplate, rhs: BuildingTemplate) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
