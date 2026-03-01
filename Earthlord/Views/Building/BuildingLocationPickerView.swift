//
//  BuildingLocationPickerView.swift
//  Earthlord
//
//  地图选点视图：在领地多边形内点击选择建造位置
//  - 领地边界坐标已是 GCJ-02（调用方转换好传入）
//  - 点击坐标 MKMapView 返回 GCJ-02，直接存 DB
//

import SwiftUI
import MapKit
import CoreLocation

struct BuildingLocationPickerView: View {
    /// 领地边界坐标（已是 GCJ-02）
    let territoryCoordinates: [CLLocationCoordinate2D]
    /// 已有建筑（坐标已是 GCJ-02）
    let existingBuildings: [PlayerBuilding]
    let templateDict: [String: BuildingTemplate]
    let onSelectLocation: (CLLocationCoordinate2D) -> Void
    let onCancel: () -> Void

    @State private var selectedCoord: CLLocationCoordinate2D? = nil
    @State private var showOutsideAlert = false

    var body: some View {
        ZStack {
            LocationPickerMapView(
                territoryCoordinates: territoryCoordinates,
                existingBuildings: existingBuildings,
                selectedCoord: $selectedCoord,
                showOutsideAlert: $showOutsideAlert
            )
            .ignoresSafeArea()

            // 顶部提示
            VStack {
                HStack {
                    Button(action: onCancel) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                            Text("取消")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(20)
                    }

                    Spacer()

                    Text("在领地内点击选择位置")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 56)

                Spacer()

                // 底部确认按钮
                if let coord = selectedCoord {
                    Button(action: { onSelectLocation(coord) }) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18))
                            Text("确认此位置")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(ApocalypseTheme.primary)
                        .cornerRadius(14)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: selectedCoord != nil)
        }
        .alert("位置无效", isPresented: $showOutsideAlert) {
            Button("好的", role: .cancel) {}
        } message: {
            Text("请在领地范围内选择建造位置")
        }
    }
}

// MARK: - LocationPickerMapView

struct LocationPickerMapView: UIViewRepresentable {
    let territoryCoordinates: [CLLocationCoordinate2D]
    let existingBuildings: [PlayerBuilding]
    @Binding var selectedCoord: CLLocationCoordinate2D?
    @Binding var showOutsideAlert: Bool

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.mapType = .hybrid
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsBuildings = false
        mapView.showsUserLocation = false
        mapView.isScrollEnabled = true
        mapView.isZoomEnabled = true
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.delegate = context.coordinator

        // 领地多边形（GCJ-02，直接用）
        if territoryCoordinates.count >= 3 {
            let polygon = MKPolygon(coordinates: territoryCoordinates, count: territoryCoordinates.count)
            polygon.title = "territory"
            mapView.addOverlay(polygon)

            // 初始视口
            var mapRect = polygon.boundingMapRect
            let padW = mapRect.size.width  * 0.6
            let padH = mapRect.size.height * 0.6
            mapRect = mapRect.insetBy(dx: -padW, dy: -padH)
            mapView.setVisibleMapRect(mapRect, animated: false)
        }

        // 已有建筑标注（GCJ-02，直接用）
        for building in existingBuildings {
            guard building.coordinate != nil else { continue }
            let ann = ExistingBuildingAnnotation(building: building)
            mapView.addAnnotation(ann)
        }

        // 点击手势
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        mapView.addGestureRecognizer(tap)

        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        // 更新选中 pin
        let existing = uiView.annotations.compactMap { $0 as? SelectedPinAnnotation }
        uiView.removeAnnotations(existing)
        if let coord = selectedCoord {
            let pin = SelectedPinAnnotation(coordinate: coord)
            uiView.addAnnotation(pin)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: LocationPickerMapView

        init(_ parent: LocationPickerMapView) {
            self.parent = parent
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let point  = gesture.location(in: mapView)
            let coord  = mapView.convert(point, toCoordinateFrom: mapView)

            // 验证是否在领地内（同为 GCJ-02，直接比较）
            let inside = TerritoryManager.shared.isPointInPolygon(
                point: coord,
                polygon: parent.territoryCoordinates
            )

            if inside {
                parent.selectedCoord = coord
            } else {
                parent.showOutsideAlert = true
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor   = UIColor.systemGreen.withAlphaComponent(0.15)
                renderer.strokeColor = UIColor.systemGreen
                renderer.lineWidth   = 2.5
                renderer.lineDashPattern = [6, 4]
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }

            if annotation is SelectedPinAnnotation {
                let id = "SelectedPin"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView
                    ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
                view.annotation = annotation
                view.markerTintColor = UIColor(red: 1, green: 0.4, blue: 0.1, alpha: 1)
                view.glyphImage = UIImage(systemName: "mappin.circle.fill")
                view.animatesWhenAdded = true
                return view
            }

            if annotation is ExistingBuildingAnnotation {
                let id = "ExistingBuilding"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView
                    ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
                view.annotation = annotation
                view.markerTintColor = UIColor.systemOrange
                view.glyphImage = UIImage(systemName: "building.2.fill")
                view.titleVisibility = .adaptive
                return view
            }

            return nil
        }
    }
}

// MARK: - Annotations

final class SelectedPinAnnotation: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D
    var title: String? { "建造位置" }
    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
        super.init()
    }
}

final class ExistingBuildingAnnotation: NSObject, MKAnnotation {
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
