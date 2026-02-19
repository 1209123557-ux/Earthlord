//
//  MapViewRepresentable.swift
//  Earthlord
//
//  MKMapView 的 SwiftUI 包装器 - 显示苹果地图、轨迹、领地多边形
//

import SwiftUI
import MapKit

// MARK: - MapViewRepresentable
/// 将 UIKit 的 MKMapView 包装成 SwiftUI View
struct MapViewRepresentable: UIViewRepresentable {
    // MARK: - Bindings
    @Binding var userLocation: CLLocationCoordinate2D?
    @Binding var hasLocatedUser: Bool

    /// 路径追踪坐标数组
    @Binding var trackingPath: [CLLocationCoordinate2D]

    /// 路径更新版本号（触发更新）
    let pathUpdateVersion: Int

    /// 是否正在追踪
    let isTracking: Bool

    /// 路径是否闭合
    let isPathClosed: Bool

    // MARK: - Territory Display
    /// 已加载的领地列表
    let territories: [Territory]
    /// 当前用户 ID（用于区分自己/他人领地颜色）
    let currentUserId: String?
    /// 领地版本号（只在该值变化时才重绘领地，避免频繁刷新）
    let territoriesVersion: Int

    // MARK: - UIViewRepresentable Methods
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()

        mapView.mapType = .hybrid
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsBuildings = false
        mapView.showsUserLocation = true
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = true
        mapView.isPitchEnabled = false
        mapView.delegate = context.coordinator

        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        // 每次更新都刷新追踪轨迹
        updateTrackingPath(uiView, context: context)

        // 只有领地版本号变化时才重绘领地（性能优化）
        if territoriesVersion != context.coordinator.lastTerritoryVersion {
            context.coordinator.lastTerritoryVersion = territoriesVersion
            drawTerritories(on: uiView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Private: Tracking Path
    /// 更新路径轨迹显示（仅移除轨迹覆盖层，保留领地多边形）
    private func updateTrackingPath(_ mapView: MKMapView, context: Context) {
        // 只移除追踪相关的覆盖层，title 为 "mine"/"others" 的领地多边形保留
        let trackingOverlays = mapView.overlays.filter { overlay in
            if overlay is MKPolyline { return true }
            if let polygon = overlay as? MKPolygon {
                let t = polygon.title
                return t != "mine" && t != "others"
            }
            return false
        }
        mapView.removeOverlays(trackingOverlays)

        guard trackingPath.count >= 2 else { return }

        // ⭐ WGS-84 → GCJ-02（修正中国地图偏移）
        let gcj02Coordinates = CoordinateConverter.convertPath(trackingPath)

        let polyline = MKPolyline(coordinates: gcj02Coordinates, count: gcj02Coordinates.count)
        mapView.addOverlay(polyline)

        if isPathClosed && gcj02Coordinates.count >= 3 {
            let polygon = MKPolygon(coordinates: gcj02Coordinates, count: gcj02Coordinates.count)
            mapView.addOverlay(polygon)
        }
    }

    // MARK: - Private: Territory Drawing
    /// 绘制所有已加载的领地（我的=绿色，他人=橙色）
    private func drawTerritories(on mapView: MKMapView) {
        // 移除旧的领地多边形
        let old = mapView.overlays.filter { overlay in
            if let polygon = overlay as? MKPolygon {
                return polygon.title == "mine" || polygon.title == "others"
            }
            return false
        }
        mapView.removeOverlays(old)

        for territory in territories {
            var coords = territory.toCoordinates()

            // ⚠️ 数据库存的是 WGS-84，显示前必须转换
            coords = coords.map { CoordinateConverter.wgs84ToGcj02($0) }
            guard coords.count >= 3 else { continue }

            let polygon = MKPolygon(coordinates: coords, count: coords.count)

            // ⚠️ UUID 比较必须统一大小写！
            // 数据库存小写，iOS uuidString 返回大写
            let isMine = territory.userId.lowercased() == currentUserId?.lowercased()
            polygon.title = isMine ? "mine" : "others"

            mapView.addOverlay(polygon, level: .aboveRoads)
        }
    }

    // MARK: - Coordinator
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewRepresentable
        /// 上次绘制领地时的版本号（防止重复绘制）
        var lastTerritoryVersion = -1
        private var hasInitialCentered = false

        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            guard let location = userLocation.location else { return }

            DispatchQueue.main.async {
                self.parent.userLocation = location.coordinate
            }

            guard !hasInitialCentered else { return }

            let region = MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            )
            mapView.setRegion(region, animated: true)
            hasInitialCentered = true

            DispatchQueue.main.async {
                self.parent.hasLocatedUser = true
            }
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {}
        func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {}

        // ⭐ 渲染所有覆盖层：追踪轨迹、当前路径多边形、领地多边形
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            // 追踪轨迹线
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = parent.isPathClosed
                    ? UIColor(red: 0.0, green: 1.0, blue: 0.3, alpha: 1.0)
                    : UIColor(red: 0.0, green: 0.95, blue: 0.95, alpha: 1.0)
                renderer.lineWidth = 5
                renderer.lineCap = .round
                return renderer
            }

            // 多边形（领地 or 当前追踪区域）
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)

                switch polygon.title {
                case "mine":
                    // 我的领地：绿色
                    renderer.fillColor   = UIColor.systemGreen.withAlphaComponent(0.25)
                    renderer.strokeColor = UIColor.systemGreen
                    renderer.lineWidth   = 2.0
                case "others":
                    // 他人领地：橙色
                    renderer.fillColor   = UIColor.systemOrange.withAlphaComponent(0.25)
                    renderer.strokeColor = UIColor.systemOrange
                    renderer.lineWidth   = 2.0
                default:
                    // 当前正在圈定的区域：亮绿色
                    renderer.fillColor   = UIColor(red: 0.0, green: 1.0, blue: 0.3, alpha: 0.35)
                    renderer.strokeColor = UIColor(red: 0.0, green: 1.0, blue: 0.3, alpha: 1.0)
                    renderer.lineWidth   = 2
                }
                return renderer
            }

            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// MARK: - Preview
#Preview {
    MapViewRepresentable(
        userLocation: .constant(nil),
        hasLocatedUser: .constant(false),
        trackingPath: .constant([]),
        pathUpdateVersion: 0,
        isTracking: false,
        isPathClosed: false,
        territories: [],
        currentUserId: nil,
        territoriesVersion: 0
    )
}
