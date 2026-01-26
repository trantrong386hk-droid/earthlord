//
//  TerritoryMapView.swift
//  earthlord
//
//  领地地图组件（UIKit MKMapView）
//  全屏显示领地边界和建筑
//

import SwiftUI
import MapKit
import CoreLocation

// MARK: - 自定义建筑标注视图

/// 建筑标注视图（带进度环和等级显示）
class BuildingAnnotationView: MKAnnotationView {

    // MARK: - UI 组件

    private let containerView = UIView()
    private let iconImageView = UIImageView()
    private let progressLayer = CAShapeLayer()
    private let backgroundLayer = CAShapeLayer()
    private let levelLabel = UILabel()

    // MARK: - 属性

    private var displayLink: CADisplayLink?
    private weak var buildingAnnotation: BuildingAnnotation?

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

        // 进度圆环（橙色）
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

        // 右下角详情按钮
        let detailButton = UIButton(type: .detailDisclosure)
        rightCalloutAccessoryView = detailButton
    }

    // MARK: - 配置

    func configure(with annotation: BuildingAnnotation) {
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
            // 建造橙色，升级蓝色
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

            // 根据分类设置颜色
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

/// 领地地图视图
struct TerritoryMapView: UIViewRepresentable {

    // MARK: - 属性

    /// 领地
    let territory: Territory

    /// 领地内的建筑
    let buildings: [PlayerBuilding]

    /// 是否显示用户位置
    var showsUserLocation: Bool = true

    /// 点击建筑回调
    var onBuildingTap: ((PlayerBuilding) -> Void)?

    // MARK: - 计算属性

    /// 领地坐标
    private var territoryCoordinates: [CLLocationCoordinate2D] {
        territory.toCoordinates()
    }

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()

        // 配置地图
        mapView.mapType = .hybrid
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsBuildings = false
        mapView.showsUserLocation = showsUserLocation
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = true
        mapView.isPitchEnabled = true
        mapView.showsCompass = true

        // 设置代理
        mapView.delegate = context.coordinator

        // 应用末世滤镜
        applyApocalypseFilter(to: mapView)

        // 绘制领地边界
        drawTerritoryBoundary(on: mapView)

        // 设置初始视野
        setInitialRegion(on: mapView)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 更新建筑标注
        updateBuildingAnnotations(on: mapView, context: context)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - 私有方法

    /// 应用末世滤镜
    private func applyApocalypseFilter(to mapView: MKMapView) {
        let overlayView = UIView(frame: mapView.bounds)
        overlayView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlayView.isUserInteractionEnabled = false
        overlayView.backgroundColor = UIColor(red: 0.4, green: 0.3, blue: 0.1, alpha: 0.15)
        overlayView.tag = 999  // 用于标识
        mapView.addSubview(overlayView)
    }

    /// 绘制领地边界
    private func drawTerritoryBoundary(on mapView: MKMapView) {
        guard territoryCoordinates.count >= 3 else { return }

        // 转换坐标（如果需要）
        let coords = CoordinateConverter.convertPath(territoryCoordinates)

        let polygon = MKPolygon(coordinates: coords, count: coords.count)
        polygon.title = "territory"
        mapView.addOverlay(polygon, level: .aboveRoads)
    }

    /// 设置初始视野
    private func setInitialRegion(on mapView: MKMapView) {
        if let center = territory.centerCoordinate {
            // 计算合适的跨度
            let latSpan = (territory.bboxMaxLat ?? center.latitude) - (territory.bboxMinLat ?? center.latitude)
            let lonSpan = (territory.bboxMaxLon ?? center.longitude) - (territory.bboxMinLon ?? center.longitude)

            let region = MKCoordinateRegion(
                center: CoordinateConverter.wgs84ToGcj02(center),
                span: MKCoordinateSpan(
                    latitudeDelta: max(latSpan * 1.5, 0.005),
                    longitudeDelta: max(lonSpan * 1.5, 0.005)
                )
            )
            mapView.setRegion(region, animated: false)
        }
    }

    /// 更新建筑标注
    private func updateBuildingAnnotations(on mapView: MKMapView, context: Context) {
        let existingAnnotations = mapView.annotations.compactMap { $0 as? BuildingAnnotation }
        let existingById = Dictionary(uniqueKeysWithValues: existingAnnotations.map { ($0.building.id, $0) })

        let currentBuildingIds = Set(buildings.compactMap { $0.coordinate != nil ? $0.id : nil })
        let existingBuildingIds = Set(existingById.keys)

        // 检测状态或等级变化的建筑（需要重建标注以更新进度环）
        var statusChangedIds: Set<UUID> = []
        for building in buildings {
            if let existing = existingById[building.id],
               existing.building.status != building.status || existing.building.level != building.level {
                statusChangedIds.insert(building.id)
            }
        }

        // ID 和状态都没变化，跳过更新
        // BuildingAnnotationView 内部的 CADisplayLink 会自动更新已有进度环
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
        for building in buildings {
            guard building.coordinate != nil, idsToAdd.contains(building.id) else { continue }
            let template = buildingManager.getTemplate(for: building.templateId)
            let annotation = BuildingAnnotation(building: building, template: template)
            mapView.addAnnotation(annotation)
        }

        print("🏗️ [TerritoryMapView] 更新建筑标注: 移除 \(annotationsToRemove.count) 个, 添加 \(idsToAdd.count) 个, 状态变化 \(statusChangedIds.count) 个")
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {

        var parent: TerritoryMapView

        init(_ parent: TerritoryMapView) {
            self.parent = parent
        }

        // MARK: - MKMapViewDelegate

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon, polygon.title == "territory" {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.2)
                renderer.strokeColor = UIColor.systemGreen
                renderer.lineWidth = 3.0
                return renderer
            }

            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }

            if let buildingAnnotation = annotation as? BuildingAnnotation {
                let identifier = "TerritoryBuilding"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? BuildingAnnotationView

                if annotationView == nil {
                    annotationView = BuildingAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                } else {
                    annotationView?.annotation = annotation
                }

                annotationView?.configure(with: buildingAnnotation)
                return annotationView
            }

            return nil
        }

        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
            guard let buildingAnnotation = view.annotation as? BuildingAnnotation else { return }
            parent.onBuildingTap?(buildingAnnotation.building)
        }
    }
}

#Preview {
    TerritoryMapView(
        territory: Territory(
            id: UUID(),
            ownerId: UUID(),
            name: "测试领地",
            path: [
                ["lat": 23.0, "lon": 113.0],
                ["lat": 23.002, "lon": 113.0],
                ["lat": 23.002, "lon": 113.002],
                ["lat": 23.0, "lon": 113.002]
            ],
            areaSqm: 40000,
            pointCount: 4,
            isActive: true,
            bboxMinLat: 23.0,
            bboxMaxLat: 23.002,
            bboxMinLon: 113.0,
            bboxMaxLon: 113.002,
            startedAt: nil,
            completedAt: nil,
            createdAt: Date(),
            updatedAt: nil
        ),
        buildings: []
    )
}
