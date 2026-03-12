//
//  TerritoryProductionView.swift
//  Earthlord
//
//  资源 Tab > 领地：查看各领地生产建筑待收取产出并一键收取。
//

import SwiftUI

struct TerritoryProductionView: View {

    @ObservedObject private var buildingManager = BuildingManager.shared
    @State private var territories: [String: String] = [:]   // territoryId → displayName
    @State private var isCollecting = false
    @State private var errorMessage: String?

    // MARK: - 数据

    /// 所有有产出配置的建筑（过滤无产出模板）
    private var productionBuildings: [PlayerBuilding] {
        buildingManager.playerBuildings.filter { building in
            guard let template = buildingManager.templateDict[building.templateId] else { return false }
            return template.productionItemId != nil
        }
    }

    /// 按领地分组
    private var groupedByTerritory: [(id: String, name: String, buildings: [PlayerBuilding])] {
        var dict: [String: [PlayerBuilding]] = [:]
        for b in productionBuildings {
            dict[b.territoryId, default: []].append(b)
        }
        return dict.map { (id: $0.key, name: territories[$0.key] ?? "领地 \($0.key.prefix(6))", buildings: $0.value) }
            .sorted { $0.name < $1.name }
    }

    private var totalPending: Int {
        productionBuildings.reduce(0) { sum, b in
            guard let t = buildingManager.templateDict[b.templateId] else { return sum }
            return sum + buildingManager.pendingCount(building: b, template: t)
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                summaryCard
                collectAllButton
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                if productionBuildings.isEmpty {
                    emptyState
                } else {
                    buildingList
                }
            }
        }
        .onAppear {
            Task {
                await buildingManager.fetchAllPlayerBuildings()
                await loadTerritories()
            }
        }
        .alert("收取失败", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("好") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - 统计卡片

    private var summaryCard: some View {
        ELCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("待收取总量")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textMuted)
                    Text("\(totalPending) 件")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(totalPending > 0 ? ApocalypseTheme.warning : ApocalypseTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 36))
                    .foregroundColor(totalPending > 0 ? ApocalypseTheme.warning : ApocalypseTheme.textMuted)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - 一键全部收取

    private var collectAllButton: some View {
        Button {
            collectAll()
        } label: {
            HStack(spacing: 8) {
                if isCollecting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.down.circle.fill")
                }
                Text(isCollecting ? "收取中..." : "一键全部收取")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(totalPending > 0 && !isCollecting
                        ? ApocalypseTheme.warning
                        : Color.gray.opacity(0.4))
            .cornerRadius(12)
        }
        .disabled(totalPending == 0 || isCollecting)
    }

    // MARK: - 建筑列表

    private var buildingList: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                ForEach(groupedByTerritory, id: \.id) { group in
                    Section {
                        ForEach(group.buildings) { building in
                            if let template = buildingManager.templateDict[building.templateId] {
                                ProductionBuildingRow(
                                    building: building,
                                    template: template,
                                    pending: buildingManager.pendingCount(building: building, template: template)
                                ) {
                                    collect(buildingId: building.id)
                                }
                                Divider()
                                    .background(Color.white.opacity(0.06))
                                    .padding(.leading, 68)
                            }
                        }
                    } header: {
                        HStack {
                            Image(systemName: "map.fill")
                                .font(.system(size: 11))
                                .foregroundColor(ApocalypseTheme.primary)
                            Text(group.name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(ApocalypseTheme.textSecondary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(ApocalypseTheme.background)
                    }
                }
            }
            .padding(.top, 12)
        }
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "leaf.fill")
                .font(.system(size: 44))
                .foregroundColor(ApocalypseTheme.textMuted)
            Text("暂无生产建筑")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textSecondary)
            Text("在领地内建造「简易农田」或「集水器」\n即可开始离线生产物资")
                .font(.system(size: 13))
                .foregroundColor(ApocalypseTheme.textMuted)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 操作

    private func collect(buildingId: String) {
        Task {
            do {
                try await buildingManager.collectProduction(buildingId: buildingId)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func collectAll() {
        isCollecting = true
        Task {
            defer { isCollecting = false }
            await withTaskGroup(of: Void.self) { group in
                for building in productionBuildings {
                    guard let template = buildingManager.templateDict[building.templateId],
                          buildingManager.pendingCount(building: building, template: template) > 0 else { continue }
                    let id = building.id
                    group.addTask {
                        try? await BuildingManager.shared.collectProduction(buildingId: id)
                    }
                }
            }
        }
    }

    // MARK: - 拉取领地名

    private func loadTerritories() async {
        do {
            let list = try await TerritoryManager.shared.loadMyTerritories()
            var map: [String: String] = [:]
            for t in list {
                map[t.id] = t.name ?? "领地 \(t.id.prefix(6))"
            }
            territories = map
        } catch {
            // 领地名加载失败不影响功能，使用 ID 前缀显示
        }
    }
}

// MARK: - ProductionBuildingRow

private struct ProductionBuildingRow: View {
    let building: PlayerBuilding
    let template: BuildingTemplate
    let pending: Int
    let onCollect: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "leaf.fill")
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
            }

            // 信息
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(building.buildingName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Text("Lv.\(building.level)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(ApocalypseTheme.primary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(ApocalypseTheme.primary.opacity(0.15))
                        .cornerRadius(5)
                }
                if let itemId = template.productionItemId {
                    Text(itemId)
                        .font(.system(size: 11))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }

            Spacer()

            // 右侧状态
            if building.status == .active {
                if pending > 0 {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("待收取 \(pending) 件")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(ApocalypseTheme.warning)
                        Button(action: onCollect) {
                            Text("收取")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(ApocalypseTheme.warning)
                                .cornerRadius(8)
                        }
                    }
                } else {
                    Text("生产中")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            } else {
                Text(building.status.displayName)
                    .font(.system(size: 12))
                    .foregroundColor(building.status.color)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var iconColor: Color {
        building.status == .active ? .green : building.status.color
    }
}
