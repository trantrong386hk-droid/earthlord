//
//  TerritoryManager.swift
//  earthlord
//
//  领地管理器
//  负责领地的上传、加载、删除等操作
//

import Foundation
import CoreLocation
import Combine
import Supabase

// MARK: - TerritoryManager

@MainActor
class TerritoryManager: ObservableObject {

    // MARK: - 单例

    static let shared = TerritoryManager()

    // MARK: - 发布属性

    /// 所有领地列表
    @Published var territories: [Territory] = []

    /// 当前用户的领地
    @Published var myTerritories: [Territory] = []

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - 私有属性

    // 注意：使用全局的 supabase 客户端（定义在 SupabaseTestView.swift）
    // 这样可以共享认证会话

    // MARK: - 初始化

    private init() {
        print("🏴 [TerritoryManager] 初始化")
    }

    // MARK: - 公开方法

    /// 上传领地到 Supabase
    /// - Parameters:
    ///   - coordinates: 路径坐标数组
    ///   - area: 面积（平方米）
    ///   - startedAt: 开始时间
    ///   - completedAt: 完成时间
    /// - Returns: 上传的领地对象
    func uploadTerritory(
        coordinates: [CLLocationCoordinate2D],
        area: Double,
        startedAt: Date?,
        completedAt: Date?
    ) async throws -> Territory {
        print("🏴 [TerritoryManager] 开始上传领地，点数: \(coordinates.count)")

        // 1. 获取当前用户 ID
        guard let userId = try? await supabase.auth.session.user.id else {
            throw TerritoryError.notAuthenticated
        }

        // 2. 转换坐标为 path 格式
        let path = coordinates.map { coord in
            ["lat": coord.latitude, "lon": coord.longitude]
        }

        // 3. 计算边界框
        let bbox = calculateBoundingBox(coordinates: coordinates)

        // 4. 生成 WKT 多边形字符串
        let wkt = coordinatesToWKT(coordinates: coordinates)

        // 5. 构建上传数据
        let upload = TerritoryUpload(
            ownerId: userId,
            name: nil,  // 可选，暂不设置
            path: path,
            polygon: wkt,
            areaSqm: area,
            pointCount: coordinates.count,
            bboxMinLat: bbox.minLat,
            bboxMaxLat: bbox.maxLat,
            bboxMinLon: bbox.minLon,
            bboxMaxLon: bbox.maxLon,
            startedAt: startedAt,
            completedAt: completedAt
        )

        // 6. 上传到 Supabase
        let response: Territory = try await supabase
            .from("territories")
            .insert(upload)
            .select()
            .single()
            .execute()
            .value

        print("🏴 [TerritoryManager] 上传成功，ID: \(response.id)")
        TerritoryLogger.shared.log("领地上传成功，ID: \(response.id)", type: .success)

        // 7. 更新本地列表
        myTerritories.append(response)
        territories.append(response)

        return response
    }

    /// 加载所有领地
    func loadAllTerritories() async throws {
        print("🏴 [TerritoryManager] 加载所有领地")
        isLoading = true
        errorMessage = nil

        do {
            let response: [Territory] = try await supabase
                .from("territories")
                .select()
                .eq("is_active", value: true)
                .execute()
                .value

            territories = response
            print("🏴 [TerritoryManager] 加载完成，共 \(response.count) 个领地")
        } catch {
            errorMessage = error.localizedDescription
            print("🏴 [TerritoryManager] 加载失败: \(error)")
            throw error
        }

        isLoading = false
    }

    /// 加载当前用户的领地
    func loadMyTerritories() async throws {
        print("🏴 [TerritoryManager] 加载我的领地")

        guard let userId = try? await supabase.auth.session.user.id else {
            throw TerritoryError.notAuthenticated
        }

        let response: [Territory] = try await supabase
            .from("territories")
            .select()
            .eq("owner_id", value: userId.uuidString)
            .eq("is_active", value: true)
            .order("created_at", ascending: false)
            .execute()
            .value

        myTerritories = response
        print("🏴 [TerritoryManager] 加载完成，共 \(response.count) 个我的领地")
    }

    /// 删除领地（软删除）
    func deleteTerritory(id: UUID) async throws {
        print("🏴 [TerritoryManager] 删除领地: \(id)")

        try await supabase
            .from("territories")
            .update(["is_active": false])
            .eq("id", value: id.uuidString)
            .execute()

        // 从本地列表移除
        territories.removeAll { $0.id == id }
        myTerritories.removeAll { $0.id == id }

        print("🏴 [TerritoryManager] 删除成功")
        TerritoryLogger.shared.log("领地已删除: \(id)", type: .info)
    }

    // MARK: - 私有方法

    /// 将坐标数组转换为 WKT POLYGON 格式
    /// - 注意：WKT 格式是 "经度 纬度"（longitude latitude）
    func coordinatesToWKT(coordinates: [CLLocationCoordinate2D]) -> String {
        guard coordinates.count >= 3 else {
            return "POLYGON EMPTY"
        }

        // 确保多边形闭合
        var coords = coordinates
        if let first = coords.first, let last = coords.last {
            if first.latitude != last.latitude || first.longitude != last.longitude {
                coords.append(first)
            }
        }

        // WKT 格式：经度在前，纬度在后
        let pointStrings = coords.map { coord in
            "\(coord.longitude) \(coord.latitude)"
        }

        return "POLYGON((\(pointStrings.joined(separator: ", "))))"
    }

    /// 计算边界框
    private func calculateBoundingBox(coordinates: [CLLocationCoordinate2D]) -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        guard !coordinates.isEmpty else {
            return (0, 0, 0, 0)
        }

        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        return (minLat, maxLat, minLon, maxLon)
    }

    // MARK: - 碰撞检测算法

    /// 射线法判断点是否在多边形内
    /// - Parameters:
    ///   - point: 待检测的点
    ///   - polygon: 多边形顶点数组
    /// - Returns: 点是否在多边形内部
    func isPointInPolygon(point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
        guard polygon.count >= 3 else { return false }

        var inside = false
        let x = point.longitude
        let y = point.latitude

        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let xi = polygon[i].longitude
            let yi = polygon[i].latitude
            let xj = polygon[j].longitude
            let yj = polygon[j].latitude

            // 射线法：从点向右发射射线，计算与多边形边的交点数
            let intersect = ((yi > y) != (yj > y)) &&
                           (x < (xj - xi) * (y - yi) / (yj - yi) + xi)

            if intersect {
                inside.toggle()
            }
            j = i
        }

        return inside
    }

    /// 检查起始点是否在他人领地内
    /// - Parameters:
    ///   - location: 起始点坐标
    ///   - currentUserId: 当前用户 ID
    /// - Returns: 碰撞检测结果
    func checkPointCollision(location: CLLocationCoordinate2D, currentUserId: String) -> CollisionResult {
        // 筛选他人领地
        let otherTerritories = territories.filter { territory in
            territory.ownerId.uuidString.lowercased() != currentUserId.lowercased()
        }

        guard !otherTerritories.isEmpty else {
            return .safe
        }

        for territory in otherTerritories {
            let polygon = territory.toCoordinates()
            guard polygon.count >= 3 else { continue }

            if isPointInPolygon(point: location, polygon: polygon) {
                TerritoryLogger.shared.log("起点碰撞：位于他人领地内", type: .error)
                return CollisionResult.violation(
                    type: .pointInTerritory,
                    message: "不能在他人领地内开始圈地！"
                )
            }
        }

        return .safe
    }

    /// 判断两条线段是否相交（CCW 算法）
    /// - Parameters:
    ///   - p1, p2: 第一条线段的两个端点
    ///   - p3, p4: 第二条线段的两个端点
    /// - Returns: 两条线段是否相交
    private func segmentsIntersect(
        p1: CLLocationCoordinate2D, p2: CLLocationCoordinate2D,
        p3: CLLocationCoordinate2D, p4: CLLocationCoordinate2D
    ) -> Bool {
        /// CCW 辅助函数：判断三点是否逆时针排列
        func ccw(_ A: CLLocationCoordinate2D, _ B: CLLocationCoordinate2D, _ C: CLLocationCoordinate2D) -> Bool {
            return (C.latitude - A.latitude) * (B.longitude - A.longitude) >
                   (B.latitude - A.latitude) * (C.longitude - A.longitude)
        }

        return ccw(p1, p3, p4) != ccw(p2, p3, p4) && ccw(p1, p2, p3) != ccw(p1, p2, p4)
    }

    /// 检查路径是否穿越他人领地边界
    /// - Parameters:
    ///   - path: 路径坐标数组
    ///   - currentUserId: 当前用户 ID
    /// - Returns: 碰撞检测结果
    func checkPathCrossTerritory(path: [CLLocationCoordinate2D], currentUserId: String) -> CollisionResult {
        guard path.count >= 2 else { return .safe }

        // 筛选他人领地
        let otherTerritories = territories.filter { territory in
            territory.ownerId.uuidString.lowercased() != currentUserId.lowercased()
        }

        guard !otherTerritories.isEmpty else { return .safe }

        // 检查路径的每一段
        for i in 0..<(path.count - 1) {
            let pathStart = path[i]
            let pathEnd = path[i + 1]

            for territory in otherTerritories {
                let polygon = territory.toCoordinates()
                guard polygon.count >= 3 else { continue }

                // 检查与领地每条边的相交
                for j in 0..<polygon.count {
                    let boundaryStart = polygon[j]
                    let boundaryEnd = polygon[(j + 1) % polygon.count]

                    if segmentsIntersect(p1: pathStart, p2: pathEnd, p3: boundaryStart, p4: boundaryEnd) {
                        TerritoryLogger.shared.log("路径碰撞：轨迹穿越他人领地边界", type: .error)
                        return CollisionResult.violation(
                            type: .pathCrossTerritory,
                            message: "轨迹不能穿越他人领地！"
                        )
                    }
                }

                // 检查路径终点是否在领地内
                if isPointInPolygon(point: pathEnd, polygon: polygon) {
                    TerritoryLogger.shared.log("路径碰撞：轨迹点进入他人领地", type: .error)
                    return CollisionResult.violation(
                        type: .pointInTerritory,
                        message: "轨迹不能进入他人领地！"
                    )
                }
            }
        }

        return .safe
    }

    /// 计算当前位置到他人领地的最近距离
    /// - Parameters:
    ///   - location: 当前位置
    ///   - currentUserId: 当前用户 ID
    /// - Returns: 最近距离（米），如果没有他人领地则返回无穷大
    func calculateMinDistanceToTerritories(location: CLLocationCoordinate2D, currentUserId: String) -> Double {
        // 筛选他人领地
        let otherTerritories = territories.filter { territory in
            territory.ownerId.uuidString.lowercased() != currentUserId.lowercased()
        }

        guard !otherTerritories.isEmpty else { return Double.infinity }

        var minDistance = Double.infinity
        let currentLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)

        for territory in otherTerritories {
            let polygon = territory.toCoordinates()

            // 计算到每个顶点的距离
            for vertex in polygon {
                let vertexLocation = CLLocation(latitude: vertex.latitude, longitude: vertex.longitude)
                let distance = currentLocation.distance(from: vertexLocation)
                minDistance = min(minDistance, distance)
            }

            // 也可以计算到每条边的距离（更精确，但计算量更大）
            // 这里简化为只计算顶点距离
        }

        return minDistance
    }

    /// 综合碰撞检测（主方法）
    /// - Parameters:
    ///   - path: 当前路径坐标数组
    ///   - currentUserId: 当前用户 ID
    /// - Returns: 碰撞检测结果（包含预警级别）
    func checkPathCollisionComprehensive(path: [CLLocationCoordinate2D], currentUserId: String) -> CollisionResult {
        guard path.count >= 1 else { return .safe }

        // 1. 如果只有起点，检查起点是否在他人领地内
        if path.count == 1 {
            return checkPointCollision(location: path[0], currentUserId: currentUserId)
        }

        // 2. 检查路径是否穿越他人领地
        let crossResult = checkPathCrossTerritory(path: path, currentUserId: currentUserId)
        if crossResult.hasCollision {
            return crossResult
        }

        // 3. 计算到最近领地的距离
        guard let lastPoint = path.last else { return .safe }
        let minDistance = calculateMinDistanceToTerritories(location: lastPoint, currentUserId: currentUserId)

        // 4. 根据距离确定预警级别和消息
        let warningLevel: WarningLevel
        let message: String?

        if minDistance > 100 {
            warningLevel = .safe
            message = nil
        } else if minDistance > 50 {
            warningLevel = .caution
            message = "注意：距离他人领地 \(Int(minDistance))m"
        } else if minDistance > 25 {
            warningLevel = .warning
            message = "警告：正在靠近他人领地（\(Int(minDistance))m）"
        } else {
            warningLevel = .danger
            message = "危险：即将进入他人领地！（\(Int(minDistance))m）"
        }

        // 5. 记录预警日志
        if warningLevel != .safe {
            TerritoryLogger.shared.log("距离预警：\(warningLevel.description)，距离 \(Int(minDistance))m", type: .warning)
        }

        return CollisionResult.warning(level: warningLevel, distance: minDistance, message: message ?? "")
    }
}

// MARK: - 错误类型

enum TerritoryError: LocalizedError {
    case notAuthenticated
    case uploadFailed(String)
    case loadFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "用户未登录"
        case .uploadFailed(let message):
            return "上传失败: \(message)"
        case .loadFailed(let message):
            return "加载失败: \(message)"
        }
    }
}
