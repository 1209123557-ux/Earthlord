//
//  POIProximityPopup.swift
//  Earthlord
//
//  玩家进入 POI 50m 范围时弹出的提示卡片。
//  以 overlay 方式叠加在地图上方。
//

import SwiftUI
import CoreLocation

struct POIProximityPopup: View {
    let poi:         GamePOI
    let onScavenge:  () -> Void
    let onDismiss:   () -> Void

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

                // ── 文字 ──
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
                name: "沃尔玛超市",
                coordinate: .init(latitude: 31.23, longitude: 121.47),
                poiType: .store
            ),
            onScavenge: {},
            onDismiss:  {}
        )
    }
}
