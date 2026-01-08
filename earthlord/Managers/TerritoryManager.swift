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

    /// Supabase 客户端
    private let supabase = SupabaseClient(
        supabaseURL: URL(string: "https://umbuyozeejvgjampncuq.supabase.co")!,
        supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVtYnV5b3plZWp2Z2phbXBuY3VxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzUyMTAxMjAsImV4cCI6MjA1MDc4NjEyMH0.R51Vt-P8BgjHw2RjHLyLBxOGNrXEy3nkIvDljLjS5BU"
    )

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
