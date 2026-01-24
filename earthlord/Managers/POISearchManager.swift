//
//  POISearchManager.swift
//  earthlord
//
//  POI 搜索管理器
//  封装 MapKit 的 MKLocalSearch，搜索附近真实地点
//

import Foundation
import MapKit
import CoreLocation

// MARK: - POI 搜索错误

enum POISearchError: LocalizedError {
    case noLocation
    case searchFailed(String)
    case noResults

    var errorDescription: String? {
        switch self {
        case .noLocation:
            return "无法获取当前位置"
        case .searchFailed(let message):
            return "搜索失败: \(message)"
        case .noResults:
            return "附近没有找到兴趣点"
        }
    }
}

// MARK: - POISearchManager

/// POI 搜索管理器
/// 使用 MapKit 的 MKLocalSearch 搜索附近真实地点
class POISearchManager {

    // MARK: - 单例

    static let shared = POISearchManager()

    private init() {
        print("🔍 [POISearchManager] 初始化")
    }

    // MARK: - 搜索配置

    /// 搜索半径列表（逐步扩大）
    private let radiusOptions: [Double] = [1000]  // 仅 1km

    /// 每种类型最多返回的结果数
    private let maxResultsPerCategory: Int = 5

    /// 要搜索的 POI 类型（MKLocalPointsOfInterestRequest 用）
    private let searchCategories: [MKPointOfInterestCategory] = [
        .store,           // 商店/超市
        .hospital,        // 医院
        .pharmacy,        // 药店
        .gasStation,      // 加油站
        .restaurant,      // 餐厅
        .cafe             // 咖啡店
    ]

    /// 关键词搜索配置（MKLocalSearch 用，中国支持更好）
    private let keywordSearchConfigs: [(keyword: String, type: POIType)] = [
        ("超市", .supermarket),
        ("医院", .hospital),
        ("药店", .pharmacy),
        ("加油站", .gasStation),
        ("餐厅", .restaurant),
        ("咖啡", .cafe)
    ]

    // MARK: - 公开方法

    /// 搜索附近 POI（自动扩大范围 + 关键词搜索备选）
    /// - Parameter center: 搜索中心点坐标
    /// - Returns: POI 数组
    func searchNearbyPOIs(
        center: CLLocationCoordinate2D,
        radius: Double? = nil
    ) async throws -> [POI] {
        print("🔍 [POI搜索] 开始搜索，中心点: \(center.latitude), \(center.longitude)")

        // 策略1：使用 MKLocalPointsOfInterestRequest，逐步扩大范围
        for searchRadius in radiusOptions {
            print("🔍 [POI搜索] 尝试 MKLocalPointsOfInterestRequest，半径: \(Int(searchRadius))m")
            let pois = await searchWithPointsOfInterest(center: center, radius: searchRadius)
            if !pois.isEmpty {
                print("🔍 [POI搜索] ✅ 找到 \(pois.count) 个 POI（半径 \(Int(searchRadius))m）")
                return pois
            }
        }

        print("🔍 [POI搜索] ⚠️ MKLocalPointsOfInterestRequest 无结果，尝试关键词搜索")

        // 策略2：使用 MKLocalSearch 关键词搜索（中国支持更好）
        for searchRadius in [1000.0] {
            print("🔍 [POI搜索] 尝试 MKLocalSearch 关键词搜索，半径: \(Int(searchRadius))m")
            let pois = await searchWithKeywords(center: center, radius: searchRadius)
            if !pois.isEmpty {
                print("🔍 [POI搜索] ✅ 关键词搜索找到 \(pois.count) 个 POI（半径 \(Int(searchRadius))m）")
                return pois
            }
        }

        print("🔍 [POI搜索] ❌ 所有搜索方式都无结果")
        return []
    }

    // MARK: - 策略1：MKLocalPointsOfInterestRequest 搜索

    /// 使用 MKLocalPointsOfInterestRequest 搜索
    private func searchWithPointsOfInterest(
        center: CLLocationCoordinate2D,
        radius: Double
    ) async -> [POI] {
        var allPOIs: [POI] = []

        // 并行搜索多种类型
        await withTaskGroup(of: [POI].self) { group in
            for category in searchCategories {
                group.addTask {
                    do {
                        let pois = try await self.searchCategory(
                            category,
                            center: center,
                            radius: radius
                        )
                        return pois
                    } catch {
                        print("🔍 [POI搜索] \(category.rawValue) 搜索失败: \(error.localizedDescription)")
                        return []
                    }
                }
            }

            for await pois in group {
                allPOIs.append(contentsOf: pois)
            }
        }

        return removeDuplicates(from: allPOIs)
    }

    // MARK: - 策略2：MKLocalSearch 关键词搜索

    /// 使用 MKLocalSearch 关键词搜索（中国支持更好）
    private func searchWithKeywords(
        center: CLLocationCoordinate2D,
        radius: Double
    ) async -> [POI] {
        var allPOIs: [POI] = []

        // 并行搜索多个关键词
        await withTaskGroup(of: [POI].self) { group in
            for config in keywordSearchConfigs {
                group.addTask {
                    do {
                        let pois = try await self.searchKeyword(
                            config.keyword,
                            type: config.type,
                            center: center,
                            radius: radius
                        )
                        return pois
                    } catch {
                        print("🔍 [POI搜索] 关键词「\(config.keyword)」搜索失败: \(error.localizedDescription)")
                        return []
                    }
                }
            }

            for await pois in group {
                allPOIs.append(contentsOf: pois)
            }
        }

        return removeDuplicates(from: allPOIs)
    }

    /// 搜索单个关键词
    private func searchKeyword(
        _ keyword: String,
        type: POIType,
        center: CLLocationCoordinate2D,
        radius: Double
    ) async throws -> [POI] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = keyword
        request.region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: radius * 2,
            longitudinalMeters: radius * 2
        )

        let search = MKLocalSearch(request: request)
        let response = try await search.start()

        let pois = response.mapItems.prefix(maxResultsPerCategory).compactMap { mapItem -> POI? in
            guard let name = mapItem.name else { return nil }

            // MapKit 返回 GCJ-02，转换为 WGS-84 存储
            let gcjCoordinate = mapItem.placemark.coordinate
            let wgsCoordinate = CoordinateConverter.gcj02ToWgs84(gcjCoordinate)

            // 添加末世风格前缀
            let apocalypseName = generateApocalypseName(for: name, type: type)

            return POI(
                id: UUID(),
                name: apocalypseName,
                type: type,
                coordinate: wgsCoordinate,
                discoveryStatus: .discovered,
                resourceStatus: .unknown,
                dangerLevel: randomDangerLevel(for: type),
                description: mapItem.placemark.title ?? "未知地点"
            )
        }

        print("🔍 [POI搜索] 关键词「\(keyword)」: 找到 \(pois.count) 个")
        return Array(pois)
    }

    /// 生成末世风格名称
    private func generateApocalypseName(for originalName: String, type: POIType) -> String {
        let prefixes = ["废弃的", "荒废的", "残存的", "破损的", "遗弃的"]
        let prefix = prefixes.randomElement() ?? "废弃的"
        return "\(prefix)\(originalName)"
    }

    // MARK: - 私有方法

    /// 搜索单个类型的 POI
    private func searchCategory(
        _ category: MKPointOfInterestCategory,
        center: CLLocationCoordinate2D,
        radius: Double
    ) async throws -> [POI] {
        // 创建搜索区域
        let region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: radius * 2,
            longitudinalMeters: radius * 2
        )

        // 创建搜索请求
        let request = MKLocalPointsOfInterestRequest(center: center, radius: radius)
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [category])

        // 执行搜索
        let search = MKLocalSearch(request: request)
        let response = try await search.start()

        // 转换结果
        // ⚠️ 重要：MapKit 在中国返回的坐标是 GCJ-02 格式
        // 我们需要转换回 WGS-84 存储，以便在 POIAnnotation 中统一转换
        let pois = response.mapItems.prefix(maxResultsPerCategory).compactMap { mapItem -> POI? in
            guard let name = mapItem.name else { return nil }

            let poiType = mapCategory(category)
            // MapKit 返回 GCJ-02，转换为 WGS-84 存储
            let gcjCoordinate = mapItem.placemark.coordinate
            let wgsCoordinate = CoordinateConverter.gcj02ToWgs84(gcjCoordinate)

            return POI(
                id: UUID(),
                name: name,
                type: poiType,
                coordinate: wgsCoordinate,  // 存储 WGS-84 坐标
                discoveryStatus: .discovered,
                resourceStatus: .unknown,
                dangerLevel: randomDangerLevel(for: poiType),
                description: mapItem.placemark.title ?? "未知地点"
            )
        }

        print("🔍 [POI搜索] \(category.rawValue): 找到 \(pois.count) 个")
        return Array(pois)
    }

    /// MapKit 类型映射到游戏 POI 类型
    private func mapCategory(_ category: MKPointOfInterestCategory) -> POIType {
        switch category {
        case .store:
            return .supermarket
        case .hospital:
            return .hospital
        case .pharmacy:
            return .pharmacy
        case .gasStation:
            return .gasStation
        case .restaurant:
            return .restaurant
        case .cafe:
            return .cafe
        default:
            return .house  // 未知类型默认为民宅
        }
    }

    /// 根据 POI 类型生成随机危险等级
    private func randomDangerLevel(for type: POIType) -> Int {
        switch type {
        case .hospital, .pharmacy:
            return Int.random(in: 2...4)  // 医疗设施中等危险
        case .supermarket, .restaurant, .cafe:
            return Int.random(in: 1...3)  // 商业设施较低危险
        case .gasStation:
            return Int.random(in: 2...4)  // 加油站中等危险
        case .factory, .warehouse:
            return Int.random(in: 3...5)  // 工业设施高危险
        case .police, .military:
            return Int.random(in: 4...5)  // 安全设施最高危险
        case .house:
            return Int.random(in: 1...2)  // 民宅低危险
        }
    }

    /// 去除重复的 POI（按坐标判断，10米内视为重复）
    private func removeDuplicates(from pois: [POI]) -> [POI] {
        var uniquePOIs: [POI] = []
        let threshold: Double = 10  // 10米内视为重复

        for poi in pois {
            let isDuplicate = uniquePOIs.contains { existing in
                let existingLocation = CLLocation(
                    latitude: existing.coordinate.latitude,
                    longitude: existing.coordinate.longitude
                )
                let newLocation = CLLocation(
                    latitude: poi.coordinate.latitude,
                    longitude: poi.coordinate.longitude
                )
                return existingLocation.distance(from: newLocation) < threshold
            }

            if !isDuplicate {
                uniquePOIs.append(poi)
            }
        }

        return uniquePOIs
    }
}
