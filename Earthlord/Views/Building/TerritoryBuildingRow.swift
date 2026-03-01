//
//  TerritoryBuildingRow.swift
//  Earthlord
//
//  领地详情建筑列表行
//  - active：显示菜单（升级 / 拆除）
//  - constructing：显示进度条 + 倒计时
//

import SwiftUI

struct TerritoryBuildingRow: View {
    let building: PlayerBuilding
    let template: BuildingTemplate
    var onUpgrade: (() -> Void)?
    var onDemolish: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(building.status.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: categoryIcon)
                    .font(.system(size: 18))
                    .foregroundColor(building.status.color)
            }

            // 信息
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(building.buildingName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Text("Lv.\(building.level)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(ApocalypseTheme.primary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ApocalypseTheme.primary.opacity(0.15))
                        .cornerRadius(6)
                }

                if building.status == .constructing {
                    // 进度条 + 倒计时
                    VStack(alignment: .leading, spacing: 3) {
                        ProgressView(value: building.buildProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            .frame(maxWidth: .infinity)
                        Text(building.formattedRemainingTime.isEmpty ? "计算中..." : building.formattedRemainingTime)
                            .font(.system(size: 11))
                            .foregroundColor(ApocalypseTheme.info)
                    }
                } else {
                    Text(building.status.displayName)
                        .font(.system(size: 12))
                        .foregroundColor(building.status.color)
                }
            }

            Spacer()

            // 操作菜单（仅 active 状态）
            if building.status == .active {
                Menu {
                    Button(action: { onUpgrade?() }) {
                        Label("升级", systemImage: "arrow.up.circle")
                    }
                    .disabled(building.level >= template.maxLevel)

                    Button(role: .destructive, action: { onDemolish?() }) {
                        Label("拆除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

// MARK: - Helper

private extension TerritoryBuildingRow {
    var categoryIcon: String {
        switch template.category {
        case .survival:   return "flame.fill"
        case .storage:    return "archivebox.fill"
        case .production: return "leaf.fill"
        case .energy:     return "bolt.fill"
        }
    }
}
