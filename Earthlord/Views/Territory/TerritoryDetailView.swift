//
//  TerritoryDetailView.swift
//  Earthlord
//
//  领地详情页 - 全屏地图 ZStack 设计
//  - 顶部悬浮工具栏（关闭 / 建造 / 信息面板开关）
//  - 底部可折叠信息面板（领地信息 + 建筑列表 + 删除）
//  - 齿轮重命名 Alert
//

import SwiftUI
import MapKit
import CoreLocation

struct TerritoryDetailView: View {
    @State private var territory: Territory

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var buildingManager = BuildingManager.shared

    // MARK: - UI State
    @State private var showInfoPanel = true
    @State private var showBuildingBrowser = false
    @State private var selectedTemplate: BuildingTemplate? = nil

    // Rename
    @State private var showRenameAlert = false
    @State private var renameText = ""
    @State private var isRenaming = false

    // Delete
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    @State private var deleteError: String? = nil

    // Upgrade / Demolish feedback
    @State private var actionError: String? = nil

    var onDeleted: (() -> Void)?

    init(territory: Territory, onDeleted: (() -> Void)? = nil) {
        _territory = State(initialValue: territory)
        self.onDeleted = onDeleted
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 全屏地图
            TerritoryMapView(
                territoryCoordinates: territory.toCoordinates(),
                buildings: buildingManager.playerBuildings.filter { $0.territoryId == territory.id },
                templates: buildingManager.templateDict
            )
            .ignoresSafeArea()

            // 顶部工具栏
            VStack(spacing: 0) {
                TerritoryToolbarView(
                    onDismiss: { dismiss() },
                    onBuildingBrowser: { showBuildingBrowser = true },
                    showInfoPanel: $showInfoPanel
                )
                Spacer()
            }

            // 底部信息面板
            VStack(spacing: 0) {
                Spacer()
                if showInfoPanel {
                    infoPanelView
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: showInfoPanel)
        }
        .toolbar(.hidden, for: .navigationBar)
        // 建筑浏览器
        .sheet(isPresented: $showBuildingBrowser) {
            BuildingBrowserView(
                onDismiss: { showBuildingBrowser = false },
                onStartConstruction: { template in
                    showBuildingBrowser = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        selectedTemplate = template
                    }
                }
            )
        }
        // 建造确认页
        .sheet(item: $selectedTemplate) { template in
            BuildingPlacementView(
                template: template,
                territory: territory,
                onDismiss: { selectedTemplate = nil },
                onConstructionStarted: {
                    selectedTemplate = nil
                    Task { await buildingManager.fetchPlayerBuildings(territoryId: territory.id) }
                }
            )
        }
        // 重命名 Alert
        .alert("重命名领地", isPresented: $showRenameAlert) {
            TextField("新名称", text: $renameText)
            Button("取消", role: .cancel) {}
            Button("确认") { Task { await performRename() } }
        } message: {
            Text("输入新的领地名称")
        }
        // 删除 Alert
        .alert("删除领地", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("确认删除", role: .destructive) { Task { await performDelete() } }
        } message: {
            Text("确定要放弃「\(territory.displayName)」？此操作不可撤销。")
        }
        .onAppear {
            buildingManager.loadTemplates()
            Task { await buildingManager.fetchPlayerBuildings(territoryId: territory.id) }
        }
        // 每秒刷新倒计时显示
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in }
    }

    // MARK: - Info Panel

    private var infoPanelView: some View {
        VStack(spacing: 0) {
            // 顶部圆角拖拽条
            Capsule()
                .fill(Color.white.opacity(0.25))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 6)

            ScrollView {
                VStack(spacing: 16) {
                    // 领地名 + 齿轮
                    HStack {
                        Text(territory.displayName)
                            .font(.title3.bold())
                            .foregroundColor(ApocalypseTheme.textPrimary)
                        Spacer()
                        Button(action: {
                            renameText = territory.displayName == "未命名领地" ? "" : territory.displayName
                            showRenameAlert = true
                        }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 18))
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }
                    }
                    .padding(.horizontal, 16)

                    // 信息卡片
                    infoCard

                    // 建筑列表
                    buildingListSection

                    // 错误提示
                    if let err = actionError {
                        Text(err)
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.danger)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }

                    // 删除按钮
                    deleteButton
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                }
                .padding(.top, 4)
            }
            .frame(maxHeight: UIScreen.main.bounds.height * 0.5)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(ApocalypseTheme.background.opacity(0.96))
        )
        .padding(.horizontal, 0)
    }

    // MARK: - Info Card

    private var infoCard: some View {
        VStack(spacing: 0) {
            infoRow(icon: "map.fill", iconColor: ApocalypseTheme.primary,
                    label: "面积", value: territory.formattedArea)
            divider
            infoRow(icon: "mappin.and.ellipse", iconColor: ApocalypseTheme.info,
                    label: "路径点", value: "\(territory.pointCount ?? territory.path.count) 个")
            divider
            infoRow(icon: "clock.fill", iconColor: ApocalypseTheme.warning,
                    label: "创建时间", value: territory.formattedDate)
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(14)
        .padding(.horizontal, 16)
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
        .padding(.vertical, 12)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 1)
            .padding(.horizontal, 16)
    }

    // MARK: - Building List

    private var buildingListSection: some View {
        let buildings = buildingManager.playerBuildings.filter { $0.territoryId == territory.id }
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("建筑（\(buildings.count)）")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 16)

            if buildings.isEmpty {
                Text("还没有建筑，点击顶部「建造」按钮开始！")
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textMuted)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(buildings) { building in
                        if let template = buildingManager.templateDict[building.templateId] {
                            TerritoryBuildingRow(
                                building: building,
                                template: template,
                                onUpgrade: { Task { await handleUpgrade(building: building) } },
                                onDemolish: { Task { await handleDemolish(building: building) } }
                            )
                            if building.id != buildings.last?.id {
                                Rectangle()
                                    .fill(Color.white.opacity(0.06))
                                    .frame(height: 1)
                                    .padding(.horizontal, 14)
                            }
                        }
                    }
                }
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(14)
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Delete Button

    private var deleteButton: some View {
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
            .padding(.vertical, 14)
            .background(isDeleting ? ApocalypseTheme.danger.opacity(0.6) : ApocalypseTheme.danger)
            .cornerRadius(14)
        }
        .disabled(isDeleting)
    }

    // MARK: - Actions

    private func performRename() async {
        let newName = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty else { return }
        isRenaming = true
        do {
            try await TerritoryManager.shared.updateTerritoryName(
                territoryId: territory.id,
                newName: newName
            )
            // 重建 Territory 以更新本地 @State
            territory = Territory(
                id: territory.id,
                userId: territory.userId,
                name: newName,
                path: territory.path,
                area: territory.area,
                pointCount: territory.pointCount,
                isActive: territory.isActive,
                startedAt: territory.startedAt,
                completedAt: territory.completedAt,
                createdAt: territory.createdAt
            )
            NotificationCenter.default.post(name: .territoryUpdated, object: nil)
        } catch {
            actionError = "重命名失败：\(error.localizedDescription)"
        }
        isRenaming = false
    }

    private func performDelete() async {
        isDeleting = true
        deleteError = nil
        do {
            try await TerritoryManager.shared.deleteTerritory(territoryId: territory.id)
            NotificationCenter.default.post(name: .territoryDeleted, object: nil)
            onDeleted?()
            dismiss()
        } catch {
            deleteError = "删除失败: \(error.localizedDescription)"
            actionError = deleteError
        }
        isDeleting = false
    }

    private func handleUpgrade(building: PlayerBuilding) async {
        do {
            try await buildingManager.upgradeBuilding(buildingId: building.id)
            actionError = nil
        } catch {
            actionError = error.localizedDescription
        }
    }

    private func handleDemolish(building: PlayerBuilding) async {
        do {
            try await buildingManager.demolishBuilding(buildingId: building.id)
            actionError = nil
        } catch {
            actionError = error.localizedDescription
        }
    }
}

// MARK: - Preview

#Preview {
    TerritoryDetailView(
        territory: Territory(
            id: "abc123",
            userId: "user1",
            name: "测试领地",
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
