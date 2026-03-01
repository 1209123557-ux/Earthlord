//
//  BuildingPlacementView.swift
//  Earthlord
//
//  建造确认页：展示模板信息、选择建造位置、确认开始建造
//

import SwiftUI
import CoreLocation

struct BuildingPlacementView: View {
    let template: BuildingTemplate
    let territory: Territory
    let onDismiss: () -> Void
    let onConstructionStarted: () -> Void

    @State private var selectedLocation: CLLocationCoordinate2D? = nil
    @State private var showLocationPicker = false
    @State private var isBuilding = false
    @State private var errorMessage: String? = nil

    @ObservedObject private var buildingManager = BuildingManager.shared

    private var inventoryMap: [String: Int] {
        Dictionary(
            uniqueKeysWithValues: InventoryManager.shared.items.map { ($0.itemId, $0.quantity) }
        )
    }

    private var canBuild: Bool {
        template.requiredResources.allSatisfy { itemId, required in
            (inventoryMap[itemId] ?? 0) >= required
        }
    }

    /// 领地坐标 WGS-84 → GCJ-02（传给选点地图）
    private var gcjTerritoryCoords: [CLLocationCoordinate2D] {
        territory.toCoordinates().map { CoordinateConverter.wgs84ToGcj02($0) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 建筑头部
                        buildingHeader

                        // 位置选择
                        locationSection

                        // 资源列表
                        if !template.requiredResources.isEmpty {
                            resourceSection
                        }

                        // 错误提示
                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundColor(ApocalypseTheme.danger)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                        }

                        // 确认按钮
                        confirmButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("建造 \(template.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { onDismiss() }
                        .foregroundColor(.white)
                }
            }
        }
        .sheet(isPresented: $showLocationPicker) {
            BuildingLocationPickerView(
                territoryCoordinates: gcjTerritoryCoords,
                existingBuildings: buildingManager.playerBuildings,
                templateDict: buildingManager.templateDict,
                onSelectLocation: { coord in
                    selectedLocation = coord
                    showLocationPicker = false
                },
                onCancel: { showLocationPicker = false }
            )
        }
    }

    // MARK: - Building Header

    private var buildingHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(ApocalypseTheme.primary.opacity(0.15))
                    .frame(width: 56, height: 56)
                Image(systemName: categoryIcon)
                    .font(.system(size: 26))
                    .foregroundColor(ApocalypseTheme.primary)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(template.name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                HStack(spacing: 8) {
                    Text(template.category.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(ApocalypseTheme.primary.opacity(0.15))
                        .cornerRadius(8)
                    Text("建造时长：\(formattedBuildTime)")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            Spacer()
        }
        .padding(14)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(14)
    }

    // MARK: - Location Section

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("建造位置")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Button(action: { showLocationPicker = true }) {
                HStack(spacing: 12) {
                    Image(systemName: selectedLocation != nil ? "mappin.circle.fill" : "mappin.circle")
                        .font(.system(size: 22))
                        .foregroundColor(selectedLocation != nil ? ApocalypseTheme.success : ApocalypseTheme.textMuted)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedLocation != nil ? "已选择位置" : "点击在地图上选点")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(selectedLocation != nil ? ApocalypseTheme.textPrimary : ApocalypseTheme.textSecondary)
                        if let coord = selectedLocation {
                            Text(String(format: "%.6f, %.6f", coord.latitude, coord.longitude))
                                .font(.system(size: 11))
                                .foregroundColor(ApocalypseTheme.textMuted)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
                .padding(14)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(selectedLocation != nil ? ApocalypseTheme.success.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Resource Section

    private var resourceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("所需资源")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            VStack(spacing: 0) {
                let sortedKeys = template.requiredResources.keys.sorted()
                ForEach(sortedKeys, id: \.self) { itemId in
                    let required  = template.requiredResources[itemId] ?? 0
                    let available = inventoryMap[itemId] ?? 0
                    ResourceRow(itemId: itemId, required: required, available: available)
                    if itemId != sortedKeys.last {
                        Rectangle()
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 1)
                            .padding(.horizontal, 16)
                    }
                }
            }
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(14)
        }
    }

    // MARK: - Confirm Button

    private var confirmButton: some View {
        Button(action: startBuilding) {
            HStack(spacing: 8) {
                if isBuilding {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 16))
                }
                Text(buttonLabel)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(buttonBackground)
            .cornerRadius(14)
        }
        .disabled(!canBuild || isBuilding || selectedLocation == nil)
    }

    private var buttonLabel: String {
        if isBuilding { return "建造中..." }
        if selectedLocation == nil { return "请先选择位置" }
        if !canBuild { return "资源不足" }
        return "确认建造"
    }

    private var buttonBackground: Color {
        if isBuilding { return ApocalypseTheme.primary.opacity(0.6) }
        if selectedLocation == nil { return ApocalypseTheme.textMuted }
        if !canBuild { return ApocalypseTheme.textMuted }
        return ApocalypseTheme.primary
    }

    // MARK: - Build Logic

    private func startBuilding() {
        isBuilding = true
        errorMessage = nil
        Task {
            do {
                try await BuildingManager.shared.startConstruction(
                    templateId: template.id,
                    territoryId: territory.id,
                    location: selectedLocation
                )
                onConstructionStarted()
            } catch {
                errorMessage = error.localizedDescription
            }
            isBuilding = false
        }
    }

    // MARK: - Helpers

    private var categoryIcon: String {
        switch template.category {
        case .survival:   return "flame.fill"
        case .storage:    return "archivebox.fill"
        case .production: return "leaf.fill"
        case .energy:     return "bolt.fill"
        }
    }

    private var formattedBuildTime: String {
        let s = template.buildTimeSeconds
        if s < 60 { return "\(s)秒" }
        let m = s / 60
        if m < 60 { return "\(m)分钟" }
        return "\(m / 60)小时\(m % 60 > 0 ? "\(m % 60)分" : "")"
    }
}
