//
//  BuildingLocationPickerView.swift
//  earthlord
//
//  地图位置选择器
//  用于在领地内选择建筑位置（UIKit MKMapView）
//

import SwiftUI
import MapKit
import CoreLocation

/// 建筑标注
class BuildingAnnotation: NSObject, MKAnnotation {
    let building: PlayerBuilding
    let template: BuildingTemplate?

    var coordinate: CLLocationCoordinate2D {
        building.coordinate ?? CLLocationCoordinate2D()
    }

    var title: String? { building.buildingName }

    var subtitle: String? {
        if building.status == .constructing {
            return "🔨 建造中 - \(building.formattedRemainingTime)"
        }
        return template?.category.displayName
    }

    init(building: PlayerBuilding, template: BuildingTemplate?) {
        self.building = building
        self.template = template
        super.init()
    }
}

/// 位置选择器中的建筑标注视图（简化版，带进度环和等级）
class PickerBuildingAnnotationView: MKAnnotationView {

    private let containerView = UIView()
    private let iconImageView = UIImageView()
    private let progressLayer = CAShapeLayer()
    private let backgroundLayer = CAShapeLayer()
    private let levelLabel = UILabel()

    static let size: CGFloat = 44

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupViews()
    }

    private func setupViews() {
        frame = CGRect(x: 0, y: 0, width: Self.size, height: Self.size)
        centerOffset = CGPoint(x: 0, y: -Self.size / 2)
        canShowCallout = true

        containerView.frame = bounds
        containerView.backgroundColor = .clear
        addSubview(containerView)

        // 背景圆环
        let center = CGPoint(x: Self.size / 2, y: Self.size / 2)
        let radius = Self.size / 2 - 3
        let circlePath = UIBezierPath(arcCenter: center, radius: radius, startAngle: -.pi / 2, endAngle: .pi * 1.5, clockwise: true)

        backgroundLayer.path = circlePath.cgPath
        backgroundLayer.fillColor = UIColor.clear.cgColor
        backgroundLayer.strokeColor = UIColor.systemGray4.cgColor
        backgroundLayer.lineWidth = 3
        containerView.layer.addSublayer(backgroundLayer)

        // 进度圆环
        progressLayer.path = circlePath.cgPath
        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.strokeColor = UIColor.systemOrange.cgColor
        progressLayer.lineWidth = 3
        progressLayer.lineCap = .round
        progressLayer.strokeEnd = 0
        containerView.layer.addSublayer(progressLayer)

        // 中心背景圆
        let innerCircle = UIView(frame: CGRect(x: 5, y: 5, width: Self.size - 10, height: Self.size - 10))
        innerCircle.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
        innerCircle.layer.cornerRadius = (Self.size - 10) / 2
        innerCircle.layer.shadowColor = UIColor.black.cgColor
        innerCircle.layer.shadowOffset = CGSize(width: 0, height: 1)
        innerCircle.layer.shadowRadius = 2
        innerCircle.layer.shadowOpacity = 0.2
        containerView.addSubview(innerCircle)

        // 图标
        iconImageView.frame = CGRect(x: 0, y: 0, width: 18, height: 18)
        iconImageView.center = CGPoint(x: innerCircle.bounds.width / 2, y: innerCircle.bounds.height / 2 - 2)
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .systemBlue
        innerCircle.addSubview(iconImageView)

        // 等级标签
        levelLabel.frame = CGRect(x: 0, y: innerCircle.bounds.height - 12, width: innerCircle.bounds.width, height: 10)
        levelLabel.textAlignment = .center
        levelLabel.font = .systemFont(ofSize: 8, weight: .bold)
        levelLabel.textColor = .secondaryLabel
        innerCircle.addSubview(levelLabel)
    }

    func configure(with annotation: BuildingAnnotation) {
        let building = annotation.building
        let template = annotation.template

        // 设置图标
        let iconName = template?.icon ?? "building.2"
        iconImageView.image = UIImage(systemName: iconName)

        // 设置等级
        levelLabel.text = "Lv.\(building.level)"

        if building.status.isInProgress {
            backgroundLayer.isHidden = false
            progressLayer.isHidden = false
            progressLayer.strokeEnd = CGFloat(building.buildProgress)
            let progressColor: UIColor = building.status == .upgrading ? .systemBlue : .systemOrange
            progressLayer.strokeColor = progressColor.cgColor
            iconImageView.tintColor = progressColor
        } else {
            backgroundLayer.isHidden = true
            progressLayer.isHidden = true

            let color: UIColor
            switch template?.category {
            case .survival: color = .systemOrange
            case .storage: color = .systemBlue
            case .production: color = .systemGreen
            case .energy: color = .systemYellow
            case .none: color = .systemGray
            }
            iconImageView.tintColor = color
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        progressLayer.strokeEnd = 0
    }
}

/// 选中位置标注
class SelectedLocationAnnotation: NSObject, MKAnnotation {
    dynamic var coordinate: CLLocationCoordinate2D

    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
        super.init()
    }
}

/// 建筑位置选择器
struct BuildingLocationPickerView: UIViewRepresentable {

    // MARK: - 属性

    /// 领地边界坐标
    let territoryCoordinates: [CLLocationCoordinate2D]

    /// 已有建筑列表
    let existingBuildings: [PlayerBuilding]

    /// 选中的坐标
    @Binding var selectedCoordinate: CLLocationCoordinate2D?

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()

        // 配置地图
        mapView.mapType = .hybrid
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsBuildings = false
        mapView.showsUserLocation = true
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false

        // 设置代理
        mapView.delegate = context.coordinator

        // 添加点击手势
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        mapView.addGestureRecognizer(tapGesture)

        // 添加领地多边形（需要转换坐标到 GCJ-02）
        if territoryCoordinates.count >= 3 {
            let convertedCoords = CoordinateConverter.convertPath(territoryCoordinates)
            let polygon = MKPolygon(
                coordinates: convertedCoords,
                count: convertedCoords.count
            )
            polygon.title = "territory"
            mapView.addOverlay(polygon)

            // 缩放到领地范围
            let rect = polygon.boundingMapRect
            let padding = UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50)
            mapView.setVisibleMapRect(rect, edgePadding: padding, animated: false)
        }

        // 添加已有建筑标注
        addBuildingAnnotations(to: mapView)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 更新选中位置标注
        updateSelectedAnnotation(on: mapView, context: context)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - 辅助方法

    /// 添加建筑标注
    private func addBuildingAnnotations(to mapView: MKMapView) {
        let buildingManager = BuildingManager.shared

        for building in existingBuildings {
            guard building.coordinate != nil else { continue }
            let template = buildingManager.getTemplate(for: building.templateId)
            let annotation = BuildingAnnotation(building: building, template: template)
            mapView.addAnnotation(annotation)
        }
    }

    /// 更新选中位置标注
    private func updateSelectedAnnotation(on mapView: MKMapView, context: Context) {
        // 移除旧的选中标注
        let existingSelected = mapView.annotations.compactMap { $0 as? SelectedLocationAnnotation }
        mapView.removeAnnotations(existingSelected)

        // 添加新的选中标注
        if let coordinate = selectedCoordinate {
            let annotation = SelectedLocationAnnotation(coordinate: coordinate)
            mapView.addAnnotation(annotation)
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {

        var parent: BuildingLocationPickerView

        init(_ parent: BuildingLocationPickerView) {
            self.parent = parent
        }

        // MARK: - 点击处理

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }

            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)

            // 检查是否在领地内
            if isPointInTerritory(coordinate) {
                parent.selectedCoordinate = coordinate
                print("📍 [LocationPicker] 选中位置: \(coordinate.latitude), \(coordinate.longitude)")
            } else {
                print("📍 [LocationPicker] 点击位置不在领地内")
            }
        }

        /// 检查点是否在领地多边形内（使用转换后的坐标）
        private func isPointInTerritory(_ point: CLLocationCoordinate2D) -> Bool {
            // 将原始坐标转换为 GCJ-02（与地图显示一致）
            let polygon = CoordinateConverter.convertPath(parent.territoryCoordinates)
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

                let intersect = ((yi > y) != (yj > y)) &&
                               (x < (xj - xi) * (y - yi) / (yj - yi) + xi)

                if intersect {
                    inside.toggle()
                }
                j = i
            }

            return inside
        }

        // MARK: - MKMapViewDelegate

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)

                if polygon.title == "territory" {
                    // 领地边界：半透明绿色填充，绿色边框
                    renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.2)
                    renderer.strokeColor = UIColor.systemGreen
                    renderer.lineWidth = 3.0
                }

                return renderer
            }

            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // 忽略用户位置
            guard !(annotation is MKUserLocation) else { return nil }

            // 选中位置标注
            if annotation is SelectedLocationAnnotation {
                let identifier = "SelectedLocation"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                } else {
                    annotationView?.annotation = annotation
                }

                annotationView?.glyphImage = UIImage(systemName: "plus.circle.fill")
                annotationView?.markerTintColor = .systemOrange
                annotationView?.displayPriority = .required

                return annotationView
            }

            // 建筑标注（使用自定义视图）
            if let buildingAnnotation = annotation as? BuildingAnnotation {
                let identifier = "Building"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? PickerBuildingAnnotationView

                if annotationView == nil {
                    annotationView = PickerBuildingAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                } else {
                    annotationView?.annotation = annotation
                }

                annotationView?.configure(with: buildingAnnotation)
                return annotationView
            }

            return nil
        }
    }
}

#Preview {
    BuildingLocationPickerView(
        territoryCoordinates: [
            CLLocationCoordinate2D(latitude: 23.0, longitude: 113.0),
            CLLocationCoordinate2D(latitude: 23.002, longitude: 113.0),
            CLLocationCoordinate2D(latitude: 23.002, longitude: 113.002),
            CLLocationCoordinate2D(latitude: 23.0, longitude: 113.002)
        ],
        existingBuildings: [],
        selectedCoordinate: .constant(nil)
    )
}
