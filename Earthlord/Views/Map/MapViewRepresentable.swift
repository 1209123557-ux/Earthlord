//
//  MapViewRepresentable.swift
//  Earthlord
//
//  MKMapView 的 SwiftUI 包装器 - 显示苹果地图并应用末世滤镜
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

    // MARK: - UIViewRepresentable Methods
    /// 创建并配置 MKMapView
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()

        // 基础配置
        mapView.mapType = .hybrid  // 卫星图 + 道路标签（末世废土风格）
        mapView.pointOfInterestFilter = .excludingAll  // 隐藏所有 POI（星巴克、麦当劳等）
        mapView.showsBuildings = false  // 隐藏 3D 建筑
        mapView.showsUserLocation = true  // ⭐ 显示用户位置蓝点（关键！）
        mapView.isZoomEnabled = true  // 允许双指缩放
        mapView.isScrollEnabled = true  // 允许单指拖动
        mapView.isRotateEnabled = true  // 允许旋转
        mapView.isPitchEnabled = false  // 禁用 3D 倾斜

        // ⭐ 设置代理（关键！必须设置才能接收位置更新回调）
        mapView.delegate = context.coordinator

        // 应用末世滤镜效果
        applyApocalypseFilter(to: mapView)

        return mapView
    }

    /// 更新视图（用于更新路径轨迹）
    func updateUIView(_ uiView: MKMapView, context: Context) {
        // 更新路径轨迹
        updateTrackingPath(uiView, context: context)
    }

    /// 创建协调器（处理地图代理回调）
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Private Methods
    /// 更新路径轨迹显示
    private func updateTrackingPath(_ mapView: MKMapView, context: Context) {
        // 移除旧的覆盖层（轨迹线和多边形）
        mapView.removeOverlays(mapView.overlays)

        // 如果没有路径点，直接返回
        guard trackingPath.count >= 2 else { return }

        // ⭐ 关键：转换坐标（WGS-84 → GCJ-02）
        let gcj02Coordinates = CoordinateConverter.convertPath(trackingPath)

        // 创建轨迹线
        let polyline = MKPolyline(coordinates: gcj02Coordinates, count: gcj02Coordinates.count)
        mapView.addOverlay(polyline)

        // 如果路径已闭合且点数 ≥ 3，添加多边形填充
        if isPathClosed && gcj02Coordinates.count >= 3 {
            let polygon = MKPolygon(coordinates: gcj02Coordinates, count: gcj02Coordinates.count)
            mapView.addOverlay(polygon)
        }
    }

    /// 应用末世滤镜效果（降低饱和度 + 棕褐色调）
    private func applyApocalypseFilter(to mapView: MKMapView) {
        // 色调控制：降低饱和度和亮度
        let colorControls = CIFilter(name: "CIColorControls")
        colorControls?.setValue(-0.15, forKey: kCIInputBrightnessKey)  // 稍微变暗
        colorControls?.setValue(0.5, forKey: kCIInputSaturationKey)  // 降低饱和度50%

        // 棕褐色调：废土的泛黄效果
        let sepiaFilter = CIFilter(name: "CISepiaTone")
        sepiaFilter?.setValue(0.65, forKey: kCIInputIntensityKey)  // 泛黄强度

        // 应用滤镜到地图图层
        if let colorControls = colorControls, let sepiaFilter = sepiaFilter {
            mapView.layer.filters = [colorControls, sepiaFilter]
        }
    }

    // MARK: - Coordinator
    /// 地图代理协调器 - 处理地图回调
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewRepresentable
        private var hasInitialCentered = false  // 防止重复居中

        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }

        // ⭐ 关键方法：用户位置更新时调用（实现自动居中）
        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            // 获取位置
            guard let location = userLocation.location else { return }

            // 更新绑定的位置
            DispatchQueue.main.async {
                self.parent.userLocation = location.coordinate
            }

            // 首次获得位置时，自动居中地图
            guard !hasInitialCentered else { return }

            // 创建居中区域（约 1 公里范围）
            let region = MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: 1000,  // 纬度方向 1 公里
                longitudinalMeters: 1000   // 经度方向 1 公里
            )

            // ⭐ 平滑居中地图（animated: true 实现平滑过渡）
            mapView.setRegion(region, animated: true)

            // 标记已完成首次居中（之后用户可以自由拖动地图）
            hasInitialCentered = true

            // 更新外部状态
            DispatchQueue.main.async {
                self.parent.hasLocatedUser = true
            }
        }

        // 区域改变时调用
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // 可用于后续功能（如加载附近的领地）
        }

        // 地图加载完成时调用
        func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
            // 可用于后续功能（如显示加载完成提示）
        }

        // ⭐ 关键方法：渲染轨迹线和多边形（必须实现，否则轨迹添加了也看不见！）
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            // 渲染轨迹线
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                // 根据是否闭合改变颜色
                renderer.strokeColor = parent.isPathClosed ? UIColor.systemGreen : UIColor.systemCyan
                renderer.lineWidth = 5  // 线宽 5pt
                renderer.lineCap = .round  // 圆头线头
                return renderer
            }

            // 渲染多边形填充
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.25)  // 半透明绿色填充
                renderer.strokeColor = UIColor.systemGreen  // 绿色边框
                renderer.lineWidth = 2
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
        isPathClosed: false
    )
}
