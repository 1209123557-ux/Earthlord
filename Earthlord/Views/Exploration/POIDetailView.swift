//
//  POIDetailView.swift
//  Earthlord
//
//  POI 详情页面（接收 GamePOI，展示真实地点信息）
//

import SwiftUI

// MARK: - 危险等级

private enum DangerLevel {
    case safe
    case low
    case medium
    case high

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

    static func from(level: Int) -> DangerLevel {
        switch level {
        case 1:    return .safe
        case 2:    return .low
        case 3:    return .medium
        case 4, 5: return .high
        default:   return .safe
        }
    }
}

// MARK: - Hero 样式（按 GamePOIType）

private struct POIHeroStyle {
    let icon: String
    let primaryColor: Color
    let secondaryColor: Color
}

private func heroStyle(for type: GamePOIType) -> POIHeroStyle {
    switch type {
    case .hospital:
        return POIHeroStyle(icon: type.systemImage,
                            primaryColor: Color(red: 0.9, green: 0.2, blue: 0.2),
                            secondaryColor: Color(red: 0.5, green: 0.05, blue: 0.05))
    case .pharmacy:
        return POIHeroStyle(icon: type.systemImage,
                            primaryColor: Color(red: 0.65, green: 0.25, blue: 0.85),
                            secondaryColor: Color(red: 0.3, green: 0.08, blue: 0.45))
    case .store:
        return POIHeroStyle(icon: type.systemImage,
                            primaryColor: Color(red: 0.2, green: 0.75, blue: 0.3),
                            secondaryColor: Color(red: 0.05, green: 0.35, blue: 0.1))
    case .gasStation:
        return POIHeroStyle(icon: type.systemImage,
                            primaryColor: Color(red: 1.0, green: 0.55, blue: 0.1),
                            secondaryColor: Color(red: 0.6, green: 0.25, blue: 0.0))
    case .restaurant:
        return POIHeroStyle(icon: type.systemImage,
                            primaryColor: Color(red: 0.9, green: 0.6, blue: 0.2),
                            secondaryColor: Color(red: 0.55, green: 0.3, blue: 0.05))
    case .cafe:
        return POIHeroStyle(icon: type.systemImage,
                            primaryColor: Color(red: 0.6, green: 0.4, blue: 0.2),
                            secondaryColor: Color(red: 0.3, green: 0.18, blue: 0.05))
    case .unknown:
        return POIHeroStyle(icon: type.systemImage,
                            primaryColor: ApocalypseTheme.primary,
                            secondaryColor: ApocalypseTheme.primaryDark)
    }
}

// MARK: - POIDetailView

struct POIDetailView: View {
    let poi: GamePOI

    @Environment(\.dismiss) private var dismiss

    private var style: POIHeroStyle { heroStyle(for: poi.poiType) }
    private var danger: DangerLevel { DangerLevel.from(level: poi.dangerLevel) }

    var body: some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    heroSection
                    infoSection
                    navigationHintCard
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
    }

    // MARK: - 顶部 Hero 区域

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [style.primaryColor, style.secondaryColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: UIScreen.main.bounds.height / 3)

            Image(systemName: style.icon)
                .font(.system(size: 80, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .shadow(color: .black.opacity(0.3), radius: 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 4) {
                Text(poi.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                Text(poi.poiType.displayName)
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
            Text("地点信息")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .padding(.top, 20)

            VStack(spacing: 0) {
                infoRow(icon: "shippingbox.fill",
                        iconColor: poi.isLooted ? ApocalypseTheme.textMuted : ApocalypseTheme.warning,
                        label: "物资状态",
                        value: poi.isLooted ? "已被搜空" : "未搜刮")
                rowDivider
                dangerRow
                rowDivider
                infoRow(icon: "map.fill",
                        iconColor: ApocalypseTheme.textSecondary,
                        label: "来源",
                        value: "地图数据")
            }
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(14)
        }
        .padding(.horizontal, 16)
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

    // MARK: - 底部提示卡片

    private var navigationHintCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "map.fill")
                .font(.system(size: 18))
                .foregroundColor(ApocalypseTheme.info)
            Text("前往地图页开始探索，靠近此地点后可进行搜刮")
                .font(.system(size: 13))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(14)
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .padding(.bottom, 48)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        POIDetailView(poi: GamePOI(
            id: "preview_001",
            name: "协和医院",
            coordinate: .init(latitude: 39.9, longitude: 116.4),
            poiType: .hospital
        ))
    }
}
