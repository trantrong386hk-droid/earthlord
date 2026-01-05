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

        // 移除旧的轨迹 Overlay
        let existingOverlays = mapView.overlays.filter { $0 is TrackingPolyline }
        mapView.removeOverlays(existingOverlays)

        // 如果没有路径点，直接返回
        guard trackingPath.count >= 2 else {
            print("🛤️ [轨迹渲染] 路径点不足，跳过渲染")
            return
        }

        // ⭐ 关键：转换坐标（WGS-84 → GCJ-02）
        // 中国地图使用 GCJ-02 坐标系，直接用 GPS 坐标会偏移 100-500 米！
        let gcjCoordinates = CoordinateConverter.convertPath(trackingPath)

        // 创建 Polyline
        let polyline = TrackingPolyline(coordinates: gcjCoordinates, count: gcjCoordinates.count)

        // 添加到地图
        mapView.addOverlay(polyline)

        print("🛤️ [轨迹渲染] 绘制轨迹，共 \(gcjCoordinates.count) 个点")
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

        // MARK: - Overlay 渲染（关键！）

        /// ⭐ 关键方法：为 Overlay 提供渲染器
        /// 如果不实现这个方法，Polyline 不会显示！
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            // 轨迹线渲染
            if let polyline = overlay as? TrackingPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)

                // 轨迹样式：青色
                renderer.strokeColor = UIColor.cyan
                renderer.lineWidth = 5.0
                renderer.lineCap = .round
                renderer.lineJoin = .round

                print("🛤️ [轨迹渲染] 创建渲染器")
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
        isTracking: false
    )
}
