//
//  BuildingDetailView.swift
//  Earthlord
//
//  建筑详情页：头部图标、信息行、资源列表、开始建造按钮
//

import SwiftUI

struct BuildingDetailView: View {
    let template: BuildingTemplate
    let onStartConstruction: (BuildingTemplate) -> Void
    let onDismiss: () -> Void

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

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        headerSection
                        infoSection
                        if !template.requiredResources.isEmpty {
                            resourceSection
                        }
                        buildButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(template.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { onDismiss() }
                        .foregroundColor(.white)
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.15))
                    .frame(width: 80, height: 80)
                Image(systemName: categoryIcon)
                    .font(.system(size: 36))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            Text(template.name)
                .font(.title2.bold())
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text(template.category.displayName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(ApocalypseTheme.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(ApocalypseTheme.primary.opacity(0.15))
                .cornerRadius(10)

            Text(template.description)
                .font(.body)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
    }

    // MARK: - Info

    private var infoSection: some View {
        VStack(spacing: 0) {
            infoRow(icon: "clock.fill", iconColor: ApocalypseTheme.warning,
                    label: "建造时间", value: formattedBuildTime)
            divider
            infoRow(icon: "arrow.up.circle.fill", iconColor: ApocalypseTheme.info,
                    label: "最高等级", value: "Lv.\(template.maxLevel)")
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(14)
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

    // MARK: - Resources

    private var resourceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("所需资源")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            VStack(spacing: 0) {
                ForEach(Array(template.requiredResources.keys.sorted()), id: \.self) { itemId in
                    let required  = template.requiredResources[itemId] ?? 0
                    let available = inventoryMap[itemId] ?? 0
                    ResourceRow(itemId: itemId, required: required, available: available)
                    if itemId != template.requiredResources.keys.sorted().last {
                        divider
                    }
                }
            }
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(14)
        }
    }

    // MARK: - Build Button

    private var buildButton: some View {
        Button(action: { onStartConstruction(template) }) {
            HStack(spacing: 8) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 16))
                Text(canBuild ? "开始建造" : "资源不足")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(canBuild ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
            .cornerRadius(14)
        }
        .disabled(!canBuild)
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
