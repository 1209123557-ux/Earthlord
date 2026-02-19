//
//  TerritoryDetailView.swift
//  Earthlord
//
//  领地详情页 - 显示地图预览、领地信息、删除操作、更多功能占位
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

    var onDeleted: (() -> Void)?

    var body: some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    mapPreview
                    contentSection
                }
            }
        }
        .navigationTitle(territory.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Text("关闭")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(20)
                }
                .buttonStyle(.plain)
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .alert("删除领地", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("确认删除", role: .destructive) {
                Task { await performDelete() }
            }
        } message: {
            Text("确定要放弃「\(territory.displayName)」？此操作不可撤销。")
        }
    }

    // MARK: - Map Preview
    private var mapPreview: some View {
        TerritoryMapPreview(coordinates: territory.toCoordinates())
            .frame(height: 240)
            .colorMultiply(Color(red: 1.0, green: 0.88, blue: 0.72))
            .saturation(0.72)
            .brightness(-0.04)
    }

    // MARK: - Content Section
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            infoSection
            deleteSection
            moreFeaturesSection
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .padding(.bottom, 48)
    }

    // MARK: - 领地信息
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("领地信息")

            VStack(spacing: 0) {
                infoRow(
                    icon: "map.fill",
                    iconColor: ApocalypseTheme.primary,
                    label: "面积",
                    value: territory.formattedArea
                )
                divider
                infoRow(
                    icon: "mappin.and.ellipse",
                    iconColor: ApocalypseTheme.info,
                    label: "路径点",
                    value: "\(territory.pointCount ?? territory.path.count) 个"
                )
                divider
                infoRow(
                    icon: "clock.fill",
                    iconColor: ApocalypseTheme.warning,
                    label: "创建时间",
                    value: territory.formattedDate
                )
            }
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(14)
        }
    }

    private func infoRow(icon: String, iconColor: Color, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
                .frame(width: 24)
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 1)
            .padding(.horizontal, 16)
    }

    // MARK: - 删除按钮
    private var deleteSection: some View {
        VStack(spacing: 8) {
            if let error = deleteError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.danger)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            Button(action: { showDeleteAlert = true }) {
                HStack(spacing: 8) {
                    if isDeleting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 15))
                    }
                    Text(isDeleting ? "删除中..." : "删除领地")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isDeleting ? ApocalypseTheme.danger.opacity(0.6) : ApocalypseTheme.danger)
                .cornerRadius(14)
            }
            .disabled(isDeleting)
        }
    }

    // MARK: - 更多功能
    private var moreFeaturesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("更多功能")

            VStack(spacing: 0) {
                featureRow(icon: "pencil", label: "重命名领地")
                divider
                featureRow(icon: "building.2.fill", label: "建筑系统")
                divider
                featureRow(icon: "arrow.left.arrow.right", label: "领地交易")
            }
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(14)
        }
    }

    private func featureRow(icon: String, label: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(width: 24)
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textPrimary)
            Spacer()
            Text("敬请期待")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(ApocalypseTheme.textMuted)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.07))
                .cornerRadius(8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Section Header
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(ApocalypseTheme.textPrimary)
    }

    // MARK: - Delete Logic
    private func performDelete() async {
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

        let gcjCoords = coordinates.map { CoordinateConverter.wgs84ToGcj02($0) }
        let polygon = MKPolygon(coordinates: gcjCoords, count: gcjCoords.count)
        uiView.addOverlay(polygon)

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

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor   = UIColor.systemGreen.withAlphaComponent(0.3)
                renderer.strokeColor = UIColor.systemGreen
                renderer.lineWidth   = 2.5
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
