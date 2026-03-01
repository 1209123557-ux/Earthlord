//
//  BuildingCard.swift
//  Earthlord
//
//  LazyVGrid 2列建筑卡片：图标 + 名称 + 分类标签 + 资源摘要
//

import SwiftUI

struct BuildingCard: View {
    let template: BuildingTemplate
    let onTap: () -> Void

    /// 判断是否资源充足（全部满足才显示绿色）
    private var canBuild: Bool {
        let inventoryMap = Dictionary(
            uniqueKeysWithValues: InventoryManager.shared.items.map { ($0.itemId, $0.quantity) }
        )
        return template.requiredResources.allSatisfy { itemId, required in
            (inventoryMap[itemId] ?? 0) >= required
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                // 顶部：图标 + 分类标签
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(ApocalypseTheme.primary.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: categoryIcon)
                            .font(.system(size: 20))
                            .foregroundColor(ApocalypseTheme.primary)
                    }
                    Spacer()
                    Text(template.category.displayName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(ApocalypseTheme.primary.opacity(0.15))
                        .cornerRadius(8)
                }

                // 名称
                Text(template.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .lineLimit(2)

                // 建造时间
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                        .foregroundColor(ApocalypseTheme.textMuted)
                    Text(formattedBuildTime)
                        .font(.system(size: 11))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                // 资源状态指示
                HStack(spacing: 4) {
                    Circle()
                        .fill(canBuild ? ApocalypseTheme.success : ApocalypseTheme.danger)
                        .frame(width: 6, height: 6)
                    Text(canBuild ? "可建造" : "资源不足")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(canBuild ? ApocalypseTheme.success : ApocalypseTheme.danger)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(canBuild ? ApocalypseTheme.primary.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

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
