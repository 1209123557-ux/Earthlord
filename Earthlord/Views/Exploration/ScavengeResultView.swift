//
//  ScavengeResultView.swift
//  Earthlord
//
//  搜刮 POI 后显示的结果界面，列出获得的物品并提供"确认"按钮。
//

import SwiftUI
import CoreLocation

struct ScavengeResultView: View {
    let poi:   GamePOI
    let items: [(itemId: String, quantity: Int)]

    @Environment(\.dismiss) private var dismiss
    @State private var itemsVisible = false

    var body: some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ── 成功标题 ──
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [ApocalypseTheme.success.opacity(0.35), .clear],
                                    center: .center,
                                    startRadius: 20,
                                    endRadius: 60
                                )
                            )
                            .frame(width: 120, height: 120)

                        Image(systemName: "bag.fill")
                            .font(.system(size: 55))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [ApocalypseTheme.success, ApocalypseTheme.primary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: ApocalypseTheme.success.opacity(0.5), radius: 10)
                    }

                    Text("搜刮成功！")
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    HStack(spacing: 5) {
                        Image(systemName: poi.poiType.systemImage)
                            .font(.system(size: 12))
                        Text(poi.name)
                            .font(.system(size: 14))
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
                .padding(.bottom, 24)

                // ── 物品卡片 ──
                ELCard(padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)) {
                    VStack(spacing: 12) {

                        HStack(spacing: 8) {
                            Image(systemName: "gift.fill")
                                .font(.system(size: 16))
                                .foregroundColor(ApocalypseTheme.warning)
                            Text("获得物品")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(ApocalypseTheme.textPrimary)
                            Spacer()
                        }

                        VStack(spacing: 0) {
                            ForEach(Array(items.enumerated()), id: \.offset) { idx, loot in
                                lootRow(loot: loot, index: idx)
                                if idx < items.count - 1 {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.06))
                                        .frame(height: 1)
                                }
                            }
                        }
                        .background(ApocalypseTheme.background.opacity(0.5))
                        .cornerRadius(10)

                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundColor(ApocalypseTheme.success)
                            Text("已添加到背包")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(ApocalypseTheme.success)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(ApocalypseTheme.success.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 20)

                Spacer()

                // ── 确认按钮 ──
                Button(action: { dismiss() }) {
                    Text("收下，继续探索")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(14)
                        .shadow(color: ApocalypseTheme.primary.opacity(0.45), radius: 10, x: 0, y: 5)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .opacity(itemsVisible ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                itemsVisible = true
            }
        }
    }

    // MARK: - 物品行

    private func lootRow(loot: (itemId: String, quantity: Int), index: Int) -> some View {
        let def      = MockItemDefinitions.find(loot.itemId)
        let (icon, color) = iconAndColor(for: def?.category)
        let rowDelay = Double(index) * 0.15

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.18))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(color)
            }

            Text(def?.displayName ?? loot.itemId)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            HStack(spacing: 8) {
                Text("×\(loot.quantity)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(ApocalypseTheme.warning)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.success)
                    .scaleEffect(itemsVisible ? 1.0 : 0.1)
                    .animation(
                        .spring(response: 0.38, dampingFraction: 0.42)
                            .delay(rowDelay + 0.18),
                        value: itemsVisible
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .opacity(itemsVisible ? 1 : 0)
        .offset(y: itemsVisible ? 0 : 10)
        .animation(.easeOut(duration: 0.3).delay(rowDelay), value: itemsVisible)
    }

    private func iconAndColor(for category: ItemCategory?) -> (String, Color) {
        switch category {
        case .water:    return ("drop.fill",   .blue)
        case .food:     return ("fork.knife",  .orange)
        case .medical:  return ("cross.fill",  .red)
        case .material: return ("cube.fill",   Color(red: 0.6, green: 0.45, blue: 0.3))
        case .tool:     return ("wrench.fill", .yellow)
        case .none:     return ("questionmark", ApocalypseTheme.textMuted)
        }
    }
}

// MARK: - Preview

#Preview {
    Color.black.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            ScavengeResultView(
                poi: GamePOI(
                    id: "test",
                    name: "沃尔玛超市",
                    coordinate: .init(latitude: 31.23, longitude: 121.47),
                    poiType: .store
                ),
                items: [
                    (itemId: "item_water_bottle", quantity: 2),
                    (itemId: "item_bandage",      quantity: 1),
                ]
            )
        }
}
