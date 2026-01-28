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

// MARK: - 建筑标注类
/// 主地图建筑标注
class MapBuildingAnnotation: NSObject, MKAnnotation {
    let building: PlayerBuilding
    let template: BuildingTemplate?

    var coordinate: CLLocationCoordinate2D {
        // 数据库中已是 GCJ-02 坐标，直接使用
        building.coordinate ?? CLLocationCoordinate2D()
    }

    var title: String? { building.buildingName }

    var subtitle: String? {
        if building.status == .constructing {
            return "建造中 - \(building.formattedRemainingTime)"
        } else if building.status == .upgrading {
            return "升级中 - \(building.formattedRemainingTime)"
        }
        return template?.category.displayName
    }

    init(building: PlayerBuilding, template: BuildingTemplate?) {
        self.building = building
        self.template = template
        super.init()
    }
}

// MARK: - 主地图建筑标注视图
/// 自定义建筑标注视图（带进度环、图标和等级显示）
class MapBuildingAnnotationView: MKAnnotationView {

    // MARK: - UI 组件

    private let containerView = UIView()
    private let iconImageView = UIImageView()
    private let progressLayer = CAShapeLayer()
    private let backgroundLayer = CAShapeLayer()
    private let levelLabel = UILabel()

    // MARK: - 属性

    private var displayLink: CADisplayLink?
    private weak var buildingAnnotation: MapBuildingAnnotation?

    static let size: CGFloat = 50

    // MARK: - 初始化

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupViews()
    }

    // MARK: - 设置视图

    private func setupViews() {
        frame = CGRect(x: 0, y: 0, width: Self.size, height: Self.size)
        centerOffset = CGPoint(x: 0, y: -Self.size / 2)
        canShowCallout = true

        // 容器视图
        containerView.frame = bounds
        containerView.backgroundColor = .clear
        addSubview(containerView)

        // 背景圆环（灰色）
        let center = CGPoint(x: Self.size / 2, y: Self.size / 2)
        let radius = Self.size / 2 - 4
        let circlePath = UIBezierPath(arcCenter: center, radius: radius, startAngle: -.pi / 2, endAngle: .pi * 1.5, clockwise: true)

        backgroundLayer.path = circlePath.cgPath
        backgroundLayer.fillColor = UIColor.clear.cgColor
        backgroundLayer.strokeColor = UIColor.systemGray4.cgColor
        backgroundLayer.lineWidth = 4
        containerView.layer.addSublayer(backgroundLayer)

        // 进度圆环
        progressLayer.path = circlePath.cgPath
        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.strokeColor = UIColor.systemOrange.cgColor
        progressLayer.lineWidth = 4
        progressLayer.lineCap = .round
        progressLayer.strokeEnd = 0
        containerView.layer.addSublayer(progressLayer)

        // 中心背景圆
        let innerCircle = UIView(frame: CGRect(x: 6, y: 6, width: Self.size - 12, height: Self.size - 12))
        innerCircle.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
        innerCircle.layer.cornerRadius = (Self.size - 12) / 2
        innerCircle.layer.shadowColor = UIColor.black.cgColor
        innerCircle.layer.shadowOffset = CGSize(width: 0, height: 2)
        innerCircle.layer.shadowRadius = 4
        innerCircle.layer.shadowOpacity = 0.3
        containerView.addSubview(innerCircle)

        // 图标
        iconImageView.frame = CGRect(x: 0, y: 0, width: 24, height: 24)
        iconImageView.center = CGPoint(x: innerCircle.bounds.width / 2, y: innerCircle.bounds.height / 2 - 2)
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .systemOrange
        innerCircle.addSubview(iconImageView)

        // 等级标签
        levelLabel.frame = CGRect(x: 0, y: innerCircle.bounds.height - 14, width: innerCircle.bounds.width, height: 12)
        levelLabel.textAlignment = .center
        levelLabel.font = .systemFont(ofSize: 9, weight: .bold)
        levelLabel.textColor = .secondaryLabel
        innerCircle.addSubview(levelLabel)
    }

    // MARK: - 配置

    func configure(with annotation: MapBuildingAnnotation) {
        self.buildingAnnotation = annotation
        let building = annotation.building
        let template = annotation.template

        // 设置图标
        let iconName = template?.icon ?? "building.2"
        iconImageView.image = UIImage(systemName: iconName)

        // 设置等级
        levelLabel.text = "Lv.\(building.level)"

        // 根据状态配置
        if building.status.isInProgress {
            // 建造中/升级中 - 显示进度环
            backgroundLayer.isHidden = false
            progressLayer.isHidden = false
            let progressColor: UIColor = building.status == .upgrading ? .systemBlue : .systemOrange
            progressLayer.strokeColor = progressColor.cgColor
            iconImageView.tintColor = progressColor
            updateProgress()
            startProgressAnimation()
        } else {
            // 已完成 - 隐藏进度环，显示分类颜色
            backgroundLayer.isHidden = true
            progressLayer.isHidden = true
            stopProgressAnimation()

            let color: UIColor
            switch template?.category {
            case .survival:
                color = .systemOrange
            case .storage:
                color = .systemBlue
            case .production:
                color = .systemGreen
            case .energy:
                color = .systemYellow
            case .none:
                color = .systemGray
            }
            iconImageView.tintColor = color
        }
    }

    // MARK: - 进度动画

    private func updateProgress() {
        guard let building = buildingAnnotation?.building else { return }
        let progress = building.buildProgress
        progressLayer.strokeEnd = CGFloat(progress)
    }

    private func startProgressAnimation() {
        stopProgressAnimation()
        displayLink = CADisplayLink(target: self, selector: #selector(updateProgressFromDisplayLink))
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopProgressAnimation() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func updateProgressFromDisplayLink() {
        updateProgress()
    }

    // MARK: - 生命周期

    override func prepareForReuse() {
        super.prepareForReuse()
        stopProgressAnimation()
        progressLayer.strokeEnd = 0
        buildingAnnotation = nil
    }

    deinit {
        stopProgressAnimation()
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

    // MARK: - 建筑显示属性

    /// 所有玩家建筑列表
    var playerBuildings: [PlayerBuilding] = []

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

        // 更新建筑标记
        updateBuildingAnnotations(on: mapView, context: context)
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

    // MARK: - 建筑标记渲染

    /// 更新建筑标记显示
    private func updateBuildingAnnotations(on mapView: MKMapView, context: Context) {
        let existingAnnotations = mapView.annotations.compactMap { $0 as? MapBuildingAnnotation }
        let existingById = Dictionary(uniqueKeysWithValues: existingAnnotations.map { ($0.building.id, $0) })

        let currentBuildingIds = Set(playerBuildings.compactMap { $0.coordinate != nil ? $0.id : nil })
        let existingBuildingIds = Set(existingById.keys)

        // 检测状态或等级变化的建筑（需要重建标注以更新进度环）
        var statusChangedIds: Set<UUID> = []
        for building in playerBuildings {
            if let existing = existingById[building.id],
               existing.building.status != building.status || existing.building.level != building.level {
                statusChangedIds.insert(building.id)
            }
        }

        // ID 和状态都没变化，跳过更新
        // MapBuildingAnnotationView 内部的 CADisplayLink 会自动更新已有进度环
        if currentBuildingIds == existingBuildingIds && statusChangedIds.isEmpty {
            return
        }

        let buildingManager = BuildingManager.shared

        // 需要移除的标注：已删除的 + 状态变化的
        let idsToRemove = existingBuildingIds.subtracting(currentBuildingIds).union(statusChangedIds)
        let annotationsToRemove = existingAnnotations.filter { idsToRemove.contains($0.building.id) }
        mapView.removeAnnotations(annotationsToRemove)

        // 需要添加的标注：新增的 + 状态变化的
        let idsToAdd = currentBuildingIds.subtracting(existingBuildingIds).union(statusChangedIds)
        for building in playerBuildings {
            guard building.coordinate != nil, idsToAdd.contains(building.id) else { continue }
            let template = buildingManager.getTemplate(for: building.templateId)
            let annotation = MapBuildingAnnotation(building: building, template: template)
            mapView.addAnnotation(annotation)
        }

        print("🏗️ [建筑渲染] 移除 \(annotationsToRemove.count) 个, 添加 \(idsToAdd.count) 个, 状态变化 \(statusChangedIds.count) 个")
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

            // 处理建筑标注（使用自定义视图：进度环 + 图标 + 等级）
            if let buildingAnnotation = annotation as? MapBuildingAnnotation {
                let identifier = "MapBuilding"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MapBuildingAnnotationView

                if annotationView == nil {
                    annotationView = MapBuildingAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                } else {
                    annotationView?.annotation = annotation
                }

                annotationView?.configure(with: buildingAnnotation)
                return annotationView
            }

            // 处理 POI 标注
            if let poiAnnotation = annotation as? POIAnnotation {
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

            return nil
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
        scavengedPOIIds: [],
        playerBuildings: []
    )
}
