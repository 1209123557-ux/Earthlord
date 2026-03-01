//
//  TerritoryMapView.swift
//  Earthlord
//
//  领地全屏地图视图（UIViewRepresentable，不可交互，纯展示）
//  - 领地多边形：WGS-84 → GCJ-02 转换后显示
//  - 建筑标注：坐标已是 GCJ-02，直接使用
//

import SwiftUI
import MapKit
import CoreLocation

struct TerritoryMapView: UIViewRepresentable {
    /// 领地路径坐标（WGS-84，渲染前转 GCJ-02）
    let territoryCoordinates: [CLLocationCoordinate2D]
    /// 该领地内的建筑（坐标已是 GCJ-02）
    let buildings: [PlayerBuilding]
    /// 建筑模板字典（id → template）
    let templates: [String: BuildingTemplate]

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.mapType = .hybrid
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsBuildings = false
        mapView.showsUserLocation = false
        mapView.isScrollEnabled = true
        mapView.isZoomEnabled = true
        mapView.isRotateEnabled = true
        mapView.isPitchEnabled = false
        mapView.delegate = context.coordinator
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        // 移除旧覆盖层和标注
        uiView.removeOverlays(uiView.overlays)
        let existing = uiView.annotations.filter { !($0 is MKUserLocation) }
        uiView.removeAnnotations(existing)

        guard territoryCoordinates.count >= 3 else { return }

        // 领地多边形：WGS-84 → GCJ-02
        let gcjCoords = territoryCoordinates.map { CoordinateConverter.wgs84ToGcj02($0) }
        let polygon = MKPolygon(coordinates: gcjCoords, count: gcjCoords.count)
        uiView.addOverlay(polygon)

        // 建筑标注（GCJ-02，直接用）
        for building in buildings {
            guard building.coordinate != nil else { continue }
            let annotation = TerritoryBuildingAnnotation(building: building)
            uiView.addAnnotation(annotation)
        }

        // 视口只在首次加载时自动定位到领地，之后保留用户的缩放/平移状态
        guard !context.coordinator.hasInitialized else { return }
        context.coordinator.hasInitialized = true

        var mapRect = polygon.boundingMapRect
        let padW = mapRect.size.width  * 0.6
        let padH = mapRect.size.height * 0.6
        mapRect = mapRect.insetBy(dx: -padW, dy: -padH)

        let minSize = MKMapSize(width: 500, height: 500)
        if mapRect.size.width < minSize.width || mapRect.size.height < minSize.height {
            let cx = mapRect.midX
            let cy = mapRect.midY
            mapRect = MKMapRect(
                x: cx - minSize.width / 2,
                y: cy - minSize.height / 2,
                width: minSize.width,
                height: minSize.height
            )
        }
        uiView.setVisibleMapRect(mapRect, animated: false)
    }

    func makeCoordinator() -> Coordinator { Coordinator(templates: templates) }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        /// 首次加载后设为 true，防止用户操作后视口被重置
        var hasInitialized = false
        let templates: [String: BuildingTemplate]

        init(templates: [String: BuildingTemplate]) {
            self.templates = templates
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor   = UIColor.systemGreen.withAlphaComponent(0.25)
                renderer.strokeColor = UIColor.systemGreen
                renderer.lineWidth   = 2.5
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let buildingAnnotation = annotation as? TerritoryBuildingAnnotation else { return nil }

            let identifier = "TerritoryBuilding"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)

            view.annotation = annotation
            view.markerTintColor = buildingAnnotation.building.status == .constructing
                ? UIColor.systemBlue
                : UIColor.systemOrange
            let iconName = templates[buildingAnnotation.building.templateId]?.category.icon ?? "building.2.fill"
            view.glyphImage = UIImage(systemName: iconName)
            view.titleVisibility = .adaptive
            view.canShowCallout = true
            return view
        }
    }
}

// MARK: - TerritoryBuildingAnnotation

final class TerritoryBuildingAnnotation: NSObject, MKAnnotation {
    let building: PlayerBuilding

    var coordinate: CLLocationCoordinate2D {
        building.coordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)
    }
    var title: String? { building.buildingName }
    var subtitle: String? { building.status.displayName }

    init(building: PlayerBuilding) {
        self.building = building
        super.init()
    }
}
