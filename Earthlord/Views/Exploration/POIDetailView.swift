//
//  POIDetailView.swift
//  Earthlord
//
//  POI 详情页面
//  接收一个 POI 参数，根据状态动态显示内容
//

import SwiftUI

// MARK: - 危险等级

/// 危险等级枚举（Mock：由 POI 类型推导，真实接入后改为后端字段）
private enum DangerLevel {
    case safe   // 安全
    case low    // 低危
    case medium // 中危
    case high   // 高危

    var label: String {
        switch self {
        case .safe:   return "安全"
        case .low:    return "低危"
        case .medium: return "中危"
        case .high:   return "高危"
        }
    }

    var color: Color {
        switch self {
        case .safe:   return .green
        case .low:    return .yellow
        case .medium: return .orange
        case .high:   return .red
        }
    }
}

/// 根据 POI 类型模拟危险等级（真实接入后删除此函数）
private func mockDangerLevel(for type: String) -> DangerLevel {
    switch type {
    case "医院":   return .medium
    case "超市":   return .low
    case "工厂":   return .high
    case "药店":   return .low
    case "加油站": return .medium
    default:       return .safe
    }
}

// MARK: - POI 类型样式（复用同一套颜色/图标体系）

private struct POIHeroStyle {
    let icon: String
    let primaryColor: Color
    let secondaryColor: Color    // 渐变第二色（深化版）
}

private func heroStyle(for type: String) -> POIHeroStyle {
    switch type {
    case "医院":
        return POIHeroStyle(icon: "cross.case.fill",
                            primaryColor: Color(red: 0.9, green: 0.2, blue: 0.2),
                            secondaryColor: Color(red: 0.5, green: 0.05, blue: 0.05))
    case "超市":
        return POIHeroStyle(icon: "cart.fill",
                            primaryColor: Color(red: 0.2, green: 0.75, blue: 0.3),
                            secondaryColor: Color(red: 0.05, green: 0.35, blue: 0.1))
    case "工厂":
        return POIHeroStyle(icon: "building.2.fill",
                            primaryColor: Color(red: 0.5, green: 0.5, blue: 0.5),
                            secondaryColor: Color(red: 0.2, green: 0.2, blue: 0.2))
    case "药店":
        return POIHeroStyle(icon: "pills.fill",
                            primaryColor: Color(red: 0.65, green: 0.25, blue: 0.85),
                            secondaryColor: Color(red: 0.3, green: 0.08, blue: 0.45))
    case "加油站":
        return POIHeroStyle(icon: "fuelpump.fill",
                            primaryColor: Color(red: 1.0, green: 0.55, blue: 0.1),
                            secondaryColor: Color(red: 0.6, green: 0.25, blue: 0.0))
    default:
        return POIHeroStyle(icon: "mappin.fill",
                            primaryColor: ApocalypseTheme.primary,
                            secondaryColor: ApocalypseTheme.primaryDark)
    }
}

// MARK: - POIDetailView

struct POIDetailView: View {
    let poi: POI

    // MARK: - 状态
    @State private var showExploreResult = false

    @Environment(\.dismiss) private var dismiss

    // MARK: - 计算属性
    private var style: POIHeroStyle { heroStyle(for: poi.type) }
    private var danger: DangerLevel { mockDangerLevel(for: poi.type) }
    /// 主按钮可用条件：已发现且有物资
    private var canExplore: Bool { poi.status == .discovered && poi.hasLoot }

    // MARK: - Body
    var body: some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    heroSection
                    infoSection
                    actionSection
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("关闭") { dismiss() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .buttonStyle(.plain)
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showExploreResult) {
            ExplorationResultView(result: MockExplorationResult.sample)
        }
    }

    // MARK: - 顶部 Hero 区域（屏幕约 1/3）

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            // 渐变背景
            LinearGradient(
                colors: [style.primaryColor, style.secondaryColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: UIScreen.main.bounds.height / 3)

            // 大图标（居中）
            Image(systemName: poi.status == .undiscovered ? "questionmark" : style.icon)
                .font(.system(size: 80, weight: .medium))
                .foregroundColor(.white.opacity(poi.status == .undiscovered ? 0.4 : 0.9))
                .shadow(color: .black.opacity(0.3), radius: 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 底部遮罩：POI 名称 + 类型
            VStack(alignment: .leading, spacing: 4) {
                Text(poi.status == .undiscovered ? "未知地点" : poi.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                Text(poi.status == .undiscovered ? "???" : poi.type)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.75))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.65)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .frame(height: UIScreen.main.bounds.height / 3)
        .clipped()
    }

    // MARK: - 信息卡片区域

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 节标题
            Text("地点信息")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .padding(.top, 20)

            // 分组信息卡（同 TerritoryDetailView 风格）
            VStack(spacing: 0) {
                infoRow(icon: "location.fill",     iconColor: ApocalypseTheme.info,
                        label: "距离",     value: "350 米")
                rowDivider
                infoRow(icon: "shippingbox.fill",  iconColor: lootColor,
                        label: "物资状态", value: lootLabel)
                rowDivider
                dangerRow
                rowDivider
                infoRow(icon: "map.fill",           iconColor: ApocalypseTheme.textSecondary,
                        label: "来源",    value: "地图数据")
            }
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(14)

            // POI 描述（未发现时隐藏）
            if poi.status != .undiscovered {
                Text(poi.description)
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(14)
            }
        }
        .padding(.horizontal, 16)
    }

    private var lootLabel: String {
        switch poi.status {
        case .undiscovered: return "未知"
        case .discovered:   return poi.hasLoot ? "有物资可搜刮" : "无物资"
        case .looted:       return "已被搜空"
        }
    }

    private var lootColor: Color {
        switch poi.status {
        case .undiscovered: return ApocalypseTheme.textMuted
        case .discovered:   return poi.hasLoot ? ApocalypseTheme.warning : ApocalypseTheme.textMuted
        case .looted:       return ApocalypseTheme.textMuted
        }
    }

    private func infoRow(icon: String, iconColor: Color, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(iconColor)
                .frame(width: 22)
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    /// 危险等级行（带彩色 Badge）
    private var dangerRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 15))
                .foregroundColor(danger.color)
                .frame(width: 22)
            Text("危险等级")
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textSecondary)
            Spacer()
            Text(danger.label)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(danger.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(danger.color.opacity(0.15))
                .cornerRadius(8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 1)
            .padding(.horizontal, 16)
    }

    // MARK: - 操作按钮区域

    private var actionSection: some View {
        VStack(spacing: 12) {
            // 主按钮：搜寻此 POI
            exploreButton

            // 次级按钮行
            HStack(spacing: 12) {
                secondaryButton(title: "标记已发现", icon: "eye.fill") {
                    print("标记已发现：\(poi.name)")
                }
                secondaryButton(title: "标记无物资", icon: "shippingbox.slash.fill") {
                    print("标记无物资：\(poi.name)")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .padding(.bottom, 48)
    }

    /// 主探索按钮（已搜空时置灰）
    private var exploreButton: some View {
        Button(action: { showExploreResult = true }) {
            HStack(spacing: 10) {
                Image(systemName: canExplore ? "figure.walk" : "lock.fill")
                    .font(.system(size: 16))
                Text(canExplore ? "搜寻此 POI" : "暂无物资可搜寻")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                canExplore
                    ? LinearGradient(
                        colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    : LinearGradient(
                        colors: [Color.gray.opacity(0.5), Color.gray.opacity(0.4)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
            )
            .cornerRadius(14)
            .shadow(
                color: canExplore ? ApocalypseTheme.primary.opacity(0.4) : .clear,
                radius: 8, x: 0, y: 4
            )
        }
        .disabled(!canExplore)
    }

    private func secondaryButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(ApocalypseTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("有物资") {
    NavigationStack {
        POIDetailView(poi: MockPOIData.list[0])   // 废弃超市：有物资
    }
}

#Preview("已搜空") {
    NavigationStack {
        POIDetailView(poi: MockPOIData.list[1])   // 医院废墟：已搜空
    }
}

#Preview("未发现") {
    NavigationStack {
        POIDetailView(poi: MockPOIData.list[2])   // 加油站：未发现
    }
}
