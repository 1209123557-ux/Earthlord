//
//  TerritoryDetailView.swift
//  Earthlord
//
//  领地详情页 - 显示地图预览、领地信息、删除操作
//

import SwiftUI
import MapKit
import CoreLocation

// MARK: - TerritoryDetailView

struct TerritoryDetailView: View {
    let territory: Territory

    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    @State private var deleteError: String? = nil

    // 删除成功后回调父视图刷新
    var onDeleted: (() -> Void)?

    var body: some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    mapPreview
                    infoSection
                    deleteSection
                }
            }
        }
        .navigationTitle(territory.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .alert("删除领地", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("确认删除", role: .destructive) {
                Task { await deleteTerritory() }
            }
        } message: {
            Text("确定要放弃「\(territory.displayName)」？此操作不可撤销。")
        }
    }

    // MARK: - Map Preview
    private var mapPreview: some View {
        let coords = territory.toCoordinates()
        return TerritoryMapPreview(coordinates: coords)
            .frame(height: 260)
            .colorMultiply(Color(red: 1.0, green: 0.88, blue: 0.72))
            .saturation(0.72)
            .brightness(-0.04)
            .ignoresSafeArea(edges: .top)
    }

    // MARK: - Info Section
    private var infoSection: some View {
        VStack(spacing: 12) {
            infoCard(
                icon: "map.fill",
                iconColor: ApocalypseTheme.success,
                title: "占地面积",
                value: territory.formattedArea
            )
            infoCard(
                icon: "mappin.and.ellipse",
                iconColor: ApocalypseTheme.info,
                title: "轨迹点数",
                value: "\(territory.pointCount ?? territory.path.count) 个"
            )
            infoCard(
                icon: "calendar",
                iconColor: ApocalypseTheme.primary,
                title: "圈定时间",
                value: territory.formattedDate
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
    }

    private func infoCard(icon: String, iconColor: Color, title: String, value: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(iconColor)
                .frame(width: 36, height: 36)
                .background(iconColor.opacity(0.15))
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }
            Spacer()
        }
        .padding(14)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(14)
    }

    // MARK: - Delete Section
    private var deleteSection: some View {
        VStack(spacing: 12) {
            if let error = deleteError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.danger)
                    .multilineTextAlignment(.center)
            }

            Button(action: { showDeleteAlert = true }) {
                HStack(spacing: 8) {
                    if isDeleting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 14))
                    }
                    Text(isDeleting ? "删除中..." : "放弃此领地")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isDeleting ? ApocalypseTheme.danger.opacity(0.6) : ApocalypseTheme.danger)
                .cornerRadius(14)
            }
            .disabled(isDeleting)
        }
        .padding(.horizontal, 16)
        .padding(.top, 32)
        .padding(.bottom, 40)
    }

    // MARK: - Delete Logic
    private func deleteTerritory() async {
        isDeleting = true
        deleteError = nil

        do {
            try await TerritoryManager.shared.deleteTerritory(territoryId: territory.id)
            onDeleted?()
            dismiss()
        } catch {
            deleteError = "删除失败: \(error.localizedDescription)"
        }

        isDeleting = false
    }
}

// MARK: - TerritoryMapPreview

/// 轻量地图预览组件：只显示单个领地多边形，不可交互
struct TerritoryMapPreview: UIViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.mapType = .hybrid
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsBuildings = false
        mapView.showsUserLocation = false
        mapView.isScrollEnabled = false
        mapView.isZoomEnabled = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.delegate = context.coordinator
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.removeOverlays(uiView.overlays)
        guard coordinates.count >= 3 else { return }

        // WGS-84 → GCJ-02（与地图底图对齐）
        let gcjCoords = coordinates.map { CoordinateConverter.wgs84ToGcj02($0) }
        let polygon = MKPolygon(coordinates: gcjCoords, count: gcjCoords.count)
        uiView.addOverlay(polygon)

        // 自适应显示区域（留出 50% 的边距）
        var mapRect = polygon.boundingMapRect
        let padW = mapRect.size.width  * 0.6
        let padH = mapRect.size.height * 0.6
        mapRect = mapRect.insetBy(dx: -padW, dy: -padH)

        // 强制最小缩放（避免极小领地填满屏幕）
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

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.3)
                renderer.strokeColor = UIColor.systemGreen
                renderer.lineWidth = 2.5
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TerritoryDetailView(
            territory: Territory(
                id: "abc123",
                userId: "user1",
                name: nil,
                path: [
                    ["lat": 31.2304, "lon": 121.4737],
                    ["lat": 31.2310, "lon": 121.4750],
                    ["lat": 31.2295, "lon": 121.4760],
                    ["lat": 31.2285, "lon": 121.4745],
                    ["lat": 31.2304, "lon": 121.4737]
                ],
                area: 12500,
                pointCount: 5,
                isActive: true,
                startedAt: "2026-02-18T10:00:00Z",
                completedAt: nil,
                createdAt: "2026-02-18T10:05:00Z"
            )
        )
    }
}
