//
//  ScavengeResultView.swift
//  Earthlord
//
//  POI 搜刮结果界面：展示 AI 生成的物品名称、稀有度标签和末日背景故事。
//

import SwiftUI
import CoreLocation

struct ScavengeResultView: View {
    let poi:   GamePOI
    let items: [AILootItem]

    @Environment(\.dismiss) private var dismiss
    @State private var itemsVisible    = false
    @State private var expandedStories: Set<UUID> = []

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
                            Image(systemName: "sparkles")
                                .font(.system(size: 16))
                                .foregroundColor(ApocalypseTheme.warning)
                            Text("获得物品")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(ApocalypseTheme.textPrimary)
                            Spacer()
                            Text("点击展开故事")
                                .font(.system(size: 11))
                                .foregroundColor(ApocalypseTheme.textMuted)
                        }

                        VStack(spacing: 6) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                                aiItemRow(item: item, index: idx)
                            }
                        }

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

    // MARK: - AI 物品行

    @ViewBuilder
    private func aiItemRow(item: AILootItem, index: Int) -> some View {
        let (icon, iconColor) = iconAndColor(for: item.category)
        let rarityData        = rarityInfo(for: item.rarity)
        let rowDelay          = Double(index) * 0.15
        let isExpanded        = expandedStories.contains(item.id)

        VStack(alignment: .leading, spacing: 0) {
            // 主行
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.18))
                        .frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .font(.system(size: 15))
                        .foregroundColor(iconColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text(rarityData.label)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(rarityData.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(rarityData.color.opacity(0.15))
                        .cornerRadius(4)
                }

                Spacer()

                // 展开故事按钮
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        if isExpanded {
                            expandedStories.remove(item.id)
                        } else {
                            expandedStories.insert(item.id)
                        }
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(6)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)

            // 展开的故事文字
            if isExpanded {
                Text("「\(item.story)」")
                    .font(.system(size: 13, weight: .regular, design: .serif))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .italic()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(ApocalypseTheme.background.opacity(0.5))
        .cornerRadius(10)
        .opacity(itemsVisible ? 1 : 0)
        .offset(y: itemsVisible ? 0 : 10)
        .animation(.easeOut(duration: 0.3).delay(rowDelay), value: itemsVisible)
    }

    // MARK: - 分类 → 图标/颜色

    private func iconAndColor(for category: String) -> (String, Color) {
        switch category {
        case "医疗": return ("cross.fill",      .red)
        case "食物": return ("fork.knife",      .orange)
        case "工具": return ("wrench.fill",     .yellow)
        case "武器": return ("shield.fill",     Color(red: 0.9, green: 0.3, blue: 0.3))
        case "材料": return ("cube.fill",       Color(red: 0.6, green: 0.45, blue: 0.3))
        default:     return ("questionmark.circle", ApocalypseTheme.textMuted)
        }
    }

    // MARK: - 稀有度 → 标签/颜色

    private func rarityInfo(for rarity: String) -> (label: String, color: Color) {
        switch rarity {
        case "common":    return ("普通",  .gray)
        case "uncommon":  return ("优秀",  .green)
        case "rare":      return ("稀有",  .blue)
        case "epic":      return ("史诗",  .purple)
        case "legendary": return ("传奇",  Color(red: 1.0, green: 0.75, blue: 0.0))
        default:          return ("普通",  .gray)
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
                    name: "协和医院急诊室",
                    coordinate: .init(latitude: 31.23, longitude: 121.47),
                    poiType: .hospital
                ),
                items: [
                    AILootItem(name: "「最后的希望」应急包", category: "医疗",  rarity: "epic",
                               story: "这个急救包上贴着一张便签：'给值夜班的自己准备的'。便签已经褪色，主人再也没能用上它..."),
                    AILootItem(name: "护士站的咖啡罐头",   category: "食物",  rarity: "rare",
                               story: "罐头上写着'夜班续命神器'。末日来临时，护士们大概正在喝着咖啡讨论患者病情。"),
                    AILootItem(name: "急诊室钥匙扣",       category: "工具",  rarity: "uncommon",
                               story: "金属钥匙扣上刻着'急诊23'，可能属于一位忙碌的住院医生。"),
                ]
            )
        }
}
