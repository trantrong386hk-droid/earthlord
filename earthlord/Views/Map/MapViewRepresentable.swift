//
//  MapViewRepresentable.swift
//  earthlord
//
//  MKMapView 的 SwiftUI 包装器
//  实现末世风格地图显示、用户位置追踪、轨迹渲染
//

import SwiftUI
import MapKit

// MARK: - 轨迹 Overlay 标识
/// 自定义 Overlay 类，用于区分轨迹线
class TrackingPolyline: MKPolyline {}

/// 自定义 Overlay 类，用于区分领地多边形
class TerritoryPolygon: MKPolygon {}

// MARK: - POI 标注类
/// POI 地图标注
class POIAnnotation: NSObject, MKAnnotation {
    let poi: POI
    var isScavenged: Bool

    var coordinate: CLLocationCoordinate2D {
        // 转换为 GCJ-02 坐标
        CoordinateConverter.wgs84ToGcj02(poi.coordinate)
    }

    var title: String? { poi.name }
    var subtitle: String? { poi.type.displayName }

    init(poi: POI, isScavenged: Bool) {
        self.poi = poi
        self.isScavenged = isScavenged
        super.init()
    }
}

// MARK: - 地图视图包装器
/// 将 MKMapView 包装为 SwiftUI 视图
struct MapViewRepresentable: UIViewRepresentable {

    // MARK: - 绑定属性

    /// 用户位置（双向绑定）
    @Binding var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位（防止重复居中）
    @Binding var hasLocatedUser: Bool

    /// 是否需要重新居中到用户位置
    @Binding var shouldRecenter: Bool

    // MARK: - 轨迹追踪属性

    /// 追踪路径坐标数组（WGS-84 原始坐标）
    var trackingPath: [CLLocationCoordinate2D]

    /// 路径更新版本号（触发 SwiftUI 重绘）
    var pathUpdateVersion: Int

    /// 是否正在追踪
    var isTracking: Bool

    /// 路径是否闭合
    var isPathClosed: Bool

    // MARK: - 领地显示属性

    /// 已加载的领地列表
    var territories: [Territory]

    /// 当前用户 ID（用于区分自己的领地和他人领地）
    var currentUserId: String?

    // MARK: - POI 显示属性

    /// 附近 POI 列表
    var pois: [POI] = []

    /// 已搜刮的 POI ID 集合
    var scavengedPOIIds: Set<UUID> = []

    // MARK: - UIViewRepresentable

    /// 创建 MKMapView
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()

        // 配置地图类型：卫星图+道路标签（末世废土风格）
        mapView.mapType = .hybrid

        // 隐藏 POI 标签（商店、餐厅等）
        mapView.pointOfInterestFilter = .excludingAll

        // 隐藏 3D 建筑
        mapView.showsBuildings = false

        // 显示用户位置蓝点（关键！）
        mapView.showsUserLocation = true

        // 允许缩放和拖动
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = true
        mapView.isPitchEnabled = true

        // 显示指南针
        mapView.showsCompass = true

        // 设置代理（关键！否则 didUpdate userLocation 不会被调用）
        mapView.delegate = context.coordinator

        // 应用末世滤镜效果
        applyApocalypseFilter(to: mapView)

        print("🗺️ [地图视图] MKMapView 创建完成")

        return mapView
    }

    /// 更新视图
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 检查是否需要重新居中
        if shouldRecenter, let location = userLocation {
            let region = MKCoordinateRegion(
                center: location,
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            )
            mapView.setRegion(region, animated: true)

            // 重置标志
            DispatchQueue.main.async {
                self.shouldRecenter = false
            }

            print("🗺️ [地图视图] 重新居中到用户位置")
        }

        // 更新轨迹显示
        updateTrackingPath(on: mapView, context: context)

        // 更新领地显示
        drawTerritories(on: mapView, context: context)

        // 更新 POI 标记
        updatePOIAnnotations(on: mapView, context: context)
    }

    // MARK: - 轨迹渲染

    /// 更新轨迹路径显示
    private func updateTrackingPath(on mapView: MKMapView, context: Context) {
        // 检查版本是否变化
        guard context.coordinator.lastPathVersion != pathUpdateVersion else {
            return
        }

        // 更新版本号
        context.coordinator.lastPathVersion = pathUpdateVersion

        // 更新闭合状态（用于轨迹变色）
        context.coordinator.isPathClosed = isPathClosed

        // 移除旧的轨迹 Overlay 和多边形
        let existingOverlays = mapView.overlays.filter { $0 is TrackingPolyline || $0 is TerritoryPolygon }
        mapView.removeOverlays(existingOverlays)

        // 如果没有路径点，直接返回
        guard trackingPath.count >= 2 else {
            print("🛤️ [轨迹渲染] 路径点不足，跳过渲染")
            return
        }

        // ⭐ 关键：转换坐标（WGS-84 → GCJ-02）
        // 中国地图使用 GCJ-02 坐标系，直接用 GPS 坐标会偏移 100-500 米！
        let gcjCoordinates = CoordinateConverter.convertPath(trackingPath)

        // 如果已闭环且点数足够，先添加多边形填充
        if isPathClosed && gcjCoordinates.count >= 3 {
            let polygon = TerritoryPolygon(coordinates: gcjCoordinates, count: gcjCoordinates.count)
            mapView.addOverlay(polygon)
            print("🏴 [领地渲染] 绘制领地多边形，共 \(gcjCoordinates.count) 个点")
        }

        // 创建 Polyline
        let polyline = TrackingPolyline(coordinates: gcjCoordinates, count: gcjCoordinates.count)

        // 添加到地图（轨迹线在多边形上层）
        mapView.addOverlay(polyline)

        print("🛤️ [轨迹渲染] 绘制轨迹，共 \(gcjCoordinates.count) 个点，闭合: \(isPathClosed)")
    }

    // MARK: - 领地渲染

    /// 绘制已保存的领地
    private func drawTerritories(on mapView: MKMapView, context: Context) {
        // 检查领地数量是否变化
        guard context.coordinator.lastTerritoriesCount != territories.count else {
            return
        }

        // 更新记录
        context.coordinator.lastTerritoriesCount = territories.count

        // 移除旧的领地多边形（保留路径轨迹和当前圈地的多边形）
        let territoryOverlays = mapView.overlays.filter { overlay in
            if let polygon = overlay as? MKPolygon {
                // 只移除有标题的（mine/others），保留 TerritoryPolygon（当前圈地）
                return polygon.title == "mine" || polygon.title == "others"
            }
            return false
        }
        mapView.removeOverlays(territoryOverlays)

        // 绘制每个领地
        for territory in territories {
            var coords = territory.toCoordinates()

            // 中国大陆需要坐标转换 WGS-84 → GCJ-02
            coords = CoordinateConverter.convertPath(coords)

            guard coords.count >= 3 else { continue }

            let polygon = MKPolygon(coordinates: coords, count: coords.count)

            // ⚠️ 关键：比较 userId 时必须统一大小写！
            // 数据库存的是小写 UUID，但 iOS 的 uuidString 返回大写
            let isMine = territory.ownerId.uuidString.lowercased() == currentUserId?.lowercased()
            polygon.title = isMine ? "mine" : "others"

            mapView.addOverlay(polygon, level: .aboveRoads)
        }

        print("🏴 [领地渲染] 绘制 \(territories.count) 个领地")
    }

    // MARK: - POI 标记渲染

    /// 更新 POI 标记显示
    private func updatePOIAnnotations(on mapView: MKMapView, context: Context) {
        // 使用更可靠的哈希计算：包含 POI ID 的哈希值
        let poiIdsHash = pois.map { $0.id.hashValue }.reduce(0, ^)
        let currentPOIHash = pois.count * 10000 + scavengedPOIIds.count * 100 + (poiIdsHash & 0xFF)

        guard context.coordinator.lastPOIHash != currentPOIHash else {
            return
        }

        // 更新记录
        context.coordinator.lastPOIHash = currentPOIHash

        print("🏪 [POI渲染] 检测到 POI 变化，开始更新标记")

        // 移除旧的 POI 标记
        let existingAnnotations = mapView.annotations.compactMap { $0 as? POIAnnotation }
        mapView.removeAnnotations(existingAnnotations)

        // 如果没有 POI，直接返回
        guard !pois.isEmpty else {
            print("🏪 [POI渲染] 无 POI 可显示")
            return
        }

        // 添加新的 POI 标记
        for poi in pois {
            let isScavenged = scavengedPOIIds.contains(poi.id)
            let annotation = POIAnnotation(poi: poi, isScavenged: isScavenged)
            mapView.addAnnotation(annotation)
        }

        print("🏪 [POI渲染] 显示 \(pois.count) 个 POI 标记，已搜刮 \(scavengedPOIIds.count) 个")
    }

    /// 创建 Coordinator
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - 末世滤镜

    /// 应用末世风格滤镜
    private func applyApocalypseFilter(to mapView: MKMapView) {
        // 创建滤镜叠加视图
        let overlayView = UIView(frame: mapView.bounds)
        overlayView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlayView.isUserInteractionEnabled = false  // 不阻挡触摸事件

        // 末世泛黄/棕褐色调
        overlayView.backgroundColor = UIColor(red: 0.4, green: 0.3, blue: 0.1, alpha: 0.15)

        // 添加到地图上层
        mapView.addSubview(overlayView)

        print("🗺️ [地图视图] 末世滤镜已应用")
    }

    // MARK: - Coordinator

    /// 协调器：处理 MKMapViewDelegate 回调
    class Coordinator: NSObject, MKMapViewDelegate {

        /// 父视图引用
        var parent: MapViewRepresentable

        /// 首次居中标志（防止重复居中）
        private var hasInitialCentered = false

        /// 路径版本号（用于判断是否需要重绘）
        var lastPathVersion: Int = -1

        /// 路径是否闭合（用于轨迹变色）
        var isPathClosed: Bool = false

        /// 领地数量（用于判断是否需要重绘）
        var lastTerritoriesCount: Int = -1

        /// POI 哈希值（用于判断是否需要重绘）
        var lastPOIHash: Int = -1

        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }

        // MARK: - MKMapViewDelegate

        /// ⭐ 关键方法：用户位置更新时调用
        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            // 获取有效位置
            guard let location = userLocation.location else { return }

            let coordinate = location.coordinate

            // 更新绑定的位置
            DispatchQueue.main.async {
                self.parent.userLocation = coordinate
            }

            print("🗺️ [地图视图] 用户位置更新: \(coordinate.latitude), \(coordinate.longitude)")

            // 首次获得位置时，自动居中地图
            guard !hasInitialCentered else { return }

            // 创建居中区域（约1公里范围）
            let region = MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            )

            // 平滑居中地图
            mapView.setRegion(region, animated: true)

            // 标记已完成首次居中
            hasInitialCentered = true

            // 更新外部状态
            DispatchQueue.main.async {
                self.parent.hasLocatedUser = true
            }

            print("🗺️ [地图视图] 首次居中完成")
        }

        /// 地图区域变化
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // 可以在这里处理地图拖动后的逻辑
        }

        /// 地图加载完成
        func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
            print("🗺️ [地图视图] 地图加载完成")
        }

        /// 地图加载失败
        func mapViewDidFailLoadingMap(_ mapView: MKMapView, withError error: Error) {
            print("🗺️ [地图视图] 地图加载失败: \(error.localizedDescription)")
        }

        /// 用户位置追踪失败
        func mapView(_ mapView: MKMapView, didFailToLocateUserWithError error: Error) {
            print("🗺️ [地图视图] 定位失败: \(error.localizedDescription)")
        }

        // MARK: - Annotation 渲染

        /// 为 Annotation 提供自定义视图
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // 忽略用户位置标注
            guard !(annotation is MKUserLocation) else { return nil }

            // 处理 POI 标注
            guard let poiAnnotation = annotation as? POIAnnotation else { return nil }

            let identifier = "POIMarker"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }

            // 设置图标
            annotationView?.glyphImage = UIImage(systemName: poiAnnotation.poi.type.iconName)

            // 始终显示标题（POI 名称）
            annotationView?.titleVisibility = .visible

            // 设置颜色（已搜刮为灰色，未搜刮使用 POI 类型颜色）
            if poiAnnotation.isScavenged {
                annotationView?.markerTintColor = .systemGray
                annotationView?.alpha = 0.6
            } else {
                annotationView?.markerTintColor = poiAnnotation.poi.type.markerColor
                annotationView?.alpha = 1.0
            }

            return annotationView
        }

        // MARK: - Overlay 渲染（关键！）

        /// ⭐ 关键方法：为 Overlay 提供渲染器
        /// 如果不实现这个方法，Polyline 不会显示！
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            // 当前圈地的多边形渲染（TerritoryPolygon 类型）
            if let polygon = overlay as? TerritoryPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)

                // 填充色：半透明绿色
                renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.25)
                // 边框色：绿色
                renderer.strokeColor = UIColor.systemGreen
                renderer.lineWidth = 2.0

                print("🏴 [领地渲染] 创建当前圈地多边形渲染器")
                return renderer
            }

            // 已保存领地的多边形渲染（普通 MKPolygon，通过 title 区分）
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)

                if polygon.title == "mine" {
                    // 我的领地：绿色
                    renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.25)
                    renderer.strokeColor = UIColor.systemGreen
                } else if polygon.title == "others" {
                    // 他人领地：橙色
                    renderer.fillColor = UIColor.systemOrange.withAlphaComponent(0.25)
                    renderer.strokeColor = UIColor.systemOrange
                } else {
                    // 默认：绿色
                    renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.25)
                    renderer.strokeColor = UIColor.systemGreen
                }

                renderer.lineWidth = 2.0
                print("🏴 [领地渲染] 创建已保存领地渲染器，类型: \(polygon.title ?? "unknown")")
                return renderer
            }

            // 轨迹线渲染
            if let polyline = overlay as? TrackingPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)

                // 轨迹样式：根据闭合状态变色
                // 未闭环：青色，已闭环：绿色
                renderer.strokeColor = isPathClosed ? UIColor.systemGreen : UIColor.systemCyan
                renderer.lineWidth = 4.0
                renderer.lineCap = .round
                renderer.lineJoin = .round

                print("🛤️ [轨迹渲染] 创建渲染器，闭合: \(isPathClosed)")
                return renderer
            }

            // 默认渲染器
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// MARK: - Preview

#Preview {
    MapViewRepresentable(
        userLocation: .constant(nil),
        hasLocatedUser: .constant(false),
        shouldRecenter: .constant(false),
        trackingPath: [],
        pathUpdateVersion: 0,
        isTracking: false,
        isPathClosed: false,
        territories: [],
        currentUserId: nil,
        pois: [],
        scavengedPOIIds: []
    )
}
