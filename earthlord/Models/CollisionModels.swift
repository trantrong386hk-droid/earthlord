//
//  CollisionModels.swift
//  earthlord
//
//  碰撞检测数据模型
//  定义预警级别、碰撞类型和检测结果
//

import Foundation

// MARK: - 预警级别

/// 距离他人领地的预警级别
enum WarningLevel: Int, Comparable {
    case safe = 0       // 安全（>100m）
    case caution = 1    // 注意（50-100m）- 黄色横幅
    case warning = 2    // 警告（25-50m）- 橙色横幅
    case danger = 3     // 危险（<25m）- 红色横幅
    case violation = 4  // 违规（已碰撞）- 红色横幅 + 停止圈地

    var description: String {
        switch self {
        case .safe: return "安全"
        case .caution: return "注意"
        case .warning: return "警告"
        case .danger: return "危险"
        case .violation: return "违规"
        }
    }

    /// 对应的颜色名称（用于 UI 显示）
    var colorName: String {
        switch self {
        case .safe: return "green"
        case .caution: return "yellow"
        case .warning: return "orange"
        case .danger: return "red"
        case .violation: return "red"
        }
    }

    // MARK: - Comparable

    static func < (lhs: WarningLevel, rhs: WarningLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

// MARK: - 碰撞类型

/// 碰撞/违规的具体类型
enum CollisionType {
    case pointInTerritory       // 点在他人领地内
    case pathCrossTerritory     // 路径穿越他人领地边界
    case selfIntersection       // 自相交（Day 17 已有）

    var description: String {
        switch self {
        case .pointInTerritory:
            return "位于他人领地内"
        case .pathCrossTerritory:
            return "穿越他人领地边界"
        case .selfIntersection:
            return "轨迹自相交"
        }
    }
}

// MARK: - 碰撞检测结果

/// 碰撞检测的综合结果
struct CollisionResult {

    /// 是否发生碰撞/违规
    let hasCollision: Bool

    /// 碰撞类型（如果有碰撞）
    let collisionType: CollisionType?

    /// 提示消息（用于 UI 显示）
    let message: String?

    /// 距离最近领地的距离（米）
    let closestDistance: Double?

    /// 当前预警级别
    let warningLevel: WarningLevel

    // MARK: - 便捷构造器

    /// 安全状态（无碰撞、无警告）
    static var safe: CollisionResult {
        CollisionResult(
            hasCollision: false,
            collisionType: nil,
            message: nil,
            closestDistance: nil,
            warningLevel: .safe
        )
    }

    /// 创建违规结果
    static func violation(type: CollisionType, message: String) -> CollisionResult {
        CollisionResult(
            hasCollision: true,
            collisionType: type,
            message: message,
            closestDistance: 0,
            warningLevel: .violation
        )
    }

    /// 创建预警结果（无碰撞，但有距离警告）
    static func warning(level: WarningLevel, distance: Double, message: String) -> CollisionResult {
        CollisionResult(
            hasCollision: false,
            collisionType: nil,
            message: message,
            closestDistance: distance,
            warningLevel: level
        )
    }
}
