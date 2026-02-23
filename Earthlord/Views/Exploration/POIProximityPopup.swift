//
//  POIProximityPopup.swift
//  Earthlord
//
//  玩家进入 POI 50m 范围时弹出的提示卡片。
//  显示地点名称、类型、当前距离、危险等级。
//

import SwiftUI
import CoreLocation

// MARK: - 危险等级（根据 POI 类型推断）

private enum POIDangerLevel {
    case low, medium, high

    var label: String {
        switch self {
        case .low:    return "低危"
        case .medium: return "中危"
        case .high:   return "高危"
        }
    }

    var color: Color {
        switch self {
        case .low:    return .green
        case .medium: return .orange
        case .high:   return .red
        }
    }

    var icon: String {
        switch self {
        case .low:    return "exclamationmark.circle"
        case .medium: return "exclamationmark.triangle.fill"
        case .high:   return "xmark.octagon.fill"
        }
    }

    static func forPOIType(_ type: GamePOIType) -> POIDangerLevel {
        switch type {
        case .hospital:   return .medium
        case .pharmacy:   return .low
        case .gasStation: return .medium
        case .store:      return .low
        case .restaurant: return .low
        case .cafe:       return .low
        case .unknown:    return .medium
        }
    }
}

// MARK: - POIProximityPopup

struct POIProximityPopup: View {
    let poi:        GamePOI
    let distanceM:  Double      // 当前距离（米）
    let onScavenge: () -> Void
    let onDismiss:  () -> Void

    private var danger: POIDangerLevel { .forPOIType(poi.poiType) }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {

                // ── 图标 ──
                ZStack {
                    Circle()
                        .fill(ApocalypseTheme.primary.opacity(0.18))
                        .frame(width: 72, height: 72)
                    Image(systemName: poi.poiType.systemImage)
                        .font(.system(size: 34))
                        .foregroundColor(ApocalypseTheme.primary)
                }

                // ── 名称 + 类型标签 ──
                VStack(spacing: 6) {
                    Text("发现废墟地点")
                        .font(.system(size: 13))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Text(poi.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(poi.poiType.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(8)
                }

                // ── 距离 + 危险等级 ──
                HStack(spacing: 0) {
                    // 距离
                    VStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 16))
                            .foregroundColor(ApocalypseTheme.info)
                        Text("\(Int(distanceM)) 米")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                        Text("当前距离")
                            .font(.system(size: 11))
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                    .frame(maxWidth: .infinity)

                    // 分隔线
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 1, height: 44)

                    // 危险等级
                    VStack(spacing: 4) {
                        Image(systemName: danger.icon)
                            .font(.system(size: 16))
                            .foregroundColor(danger.color)
                        Text(danger.label)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(danger.color)
                        Text("危险等级")
                            .font(.system(size: 11))
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 12)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(12)

                // ── 按钮 ──
                HStack(spacing: 12) {
                    Button(action: onDismiss) {
                        Text("稍后再说")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(ApocalypseTheme.cardBackground)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    }

                    Button(action: onScavenge) {
                        HStack(spacing: 6) {
                            Image(systemName: "hand.tap.fill")
                                .font(.system(size: 14))
                            Text("立即搜刮")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: ApocalypseTheme.primary.opacity(0.4), radius: 6, x: 0, y: 3)
                    }
                }
            }
            .padding(24)
            .background(ApocalypseTheme.background)
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.35), radius: 24, x: 0, y: -6)
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        POIProximityPopup(
            poi: GamePOI(
                id: "test",
                name: "业善医药",
                coordinate: .init(latitude: 31.23, longitude: 121.47),
                poiType: .pharmacy
            ),
            distanceM: 32,
            onScavenge: {},
            onDismiss:  {}
        )
    }
}
