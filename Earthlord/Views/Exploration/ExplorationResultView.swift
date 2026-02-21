//
//  ExplorationResultView.swift
//  Earthlord
//
//  探索结束弹窗页面 - 显示本次收获、统计数据和排名
//  使用方式：.sheet(isPresented:) { ExplorationResultView(result: result) }
//

import SwiftUI

struct ExplorationResultView: View {
    let result: ExplorationResult

    @Environment(\.dismiss) private var dismiss

    // 控制入场动画
    @State private var headerVisible  = false
    @State private var statsVisible   = false
    @State private var lootVisible    = false

    var body: some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    achievementHeader
                    statsCard
                    lootCard
                    confirmButton
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
        }
        .onAppear { triggerAnimations() }
    }

    // MARK: - 成就标题（带入场动画）

    private var achievementHeader: some View {
        VStack(spacing: 14) {
            // 大图标 + 光晕
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [ApocalypseTheme.primary.opacity(0.35), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: "map.fill")
                    .font(.system(size: 62))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [ApocalypseTheme.primary, ApocalypseTheme.warning],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: ApocalypseTheme.primary.opacity(0.6), radius: 12)
            }

            // 主标题
            Text("探索完成！")
                .font(.system(size: 30, weight: .black))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 副标题：物品摘要
            Text(result.lootSummary)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .padding(.vertical, 8)
        .opacity(headerVisible ? 1 : 0)
        .scaleEffect(headerVisible ? 1 : 0.85)
    }

    // MARK: - 统计数据卡片

    private var statsCard: some View {
        ELCard(padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)) {
            VStack(spacing: 0) {
                // 行走距离
                statGroup(
                    icon: "figure.walk",
                    iconColor: ApocalypseTheme.info,
                    title: "行走距离",
                    current: formatDistance(result.walkDistanceM),
                    cumulative: formatDistance(result.totalWalkDistanceM),
                    rank: result.walkRank
                )
                statDivider
                // 探索面积
                statGroup(
                    icon: "map.fill",
                    iconColor: ApocalypseTheme.success,
                    title: "探索面积",
                    current: formatArea(result.exploredAreaM2),
                    cumulative: formatArea(result.totalExploredAreaM2),
                    rank: result.areaRank
                )
                statDivider
                // 探索时长（无排名）
                durationRow
            }
        }
        .opacity(statsVisible ? 1 : 0)
        .offset(y: statsVisible ? 0 : 20)
    }

    private func statGroup(
        icon: String, iconColor: Color,
        title: String,
        current: String, cumulative: String,
        rank: Int
    ) -> some View {
        VStack(spacing: 10) {
            // 标题行
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                Spacer()
                // 排名（醒目绿色）
                HStack(spacing: 2) {
                    Text("全服第")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textMuted)
                    Text("#\(rank)")
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(ApocalypseTheme.success)
                }
            }

            // 数值行：本次 vs 累计
            HStack(spacing: 0) {
                statValue(label: "本次", value: current, color: ApocalypseTheme.primary)
                Spacer()
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 1, height: 36)
                Spacer()
                statValue(label: "累计", value: cumulative, color: ApocalypseTheme.textPrimary)
            }
        }
        .padding(.vertical, 14)
    }

    private func statValue(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    /// 探索时长行（无排名，单独样式）
    private var durationRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.fill")
                .font(.system(size: 13))
                .foregroundColor(ApocalypseTheme.warning)
            Text("探索时长")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textSecondary)
            Spacer()
            Text("\(result.durationMinutes) 分钟")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .padding(.vertical, 14)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 1)
    }

    // MARK: - 奖励物品卡片

    private var lootCard: some View {
        ELCard(padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)) {
            VStack(spacing: 12) {
                // 标题
                HStack(spacing: 8) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 16))
                        .foregroundColor(ApocalypseTheme.warning)
                    Text("获得物品")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Spacer()
                }

                // 物品列表
                VStack(spacing: 0) {
                    ForEach(Array(result.lootedItems.enumerated()), id: \.offset) { idx, loot in
                        lootRow(loot: loot)
                        if idx < result.lootedItems.count - 1 {
                            Rectangle()
                                .fill(Color.white.opacity(0.06))
                                .frame(height: 1)
                                .padding(.horizontal, 4)
                        }
                    }
                }
                .background(ApocalypseTheme.background.opacity(0.5))
                .cornerRadius(10)

                // 底部提示
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
        .opacity(lootVisible ? 1 : 0)
        .offset(y: lootVisible ? 0 : 20)
    }

    private func lootRow(loot: (itemId: String, quantity: Int)) -> some View {
        let def = MockItemDefinitions.find(loot.itemId)
        let (icon, color) = iconAndColor(for: def?.category)

        return HStack(spacing: 12) {
            // 左：分类图标
            ZStack {
                Circle()
                    .fill(color.opacity(0.18))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(color)
            }

            // 中：物品名称
            Text(def?.displayName ?? loot.itemId)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            // 右：数量 + 对勾
            HStack(spacing: 8) {
                Text("×\(loot.quantity)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(ApocalypseTheme.warning)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.success)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
    }

    /// 根据物品分类返回图标和颜色
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

    // MARK: - 确认按钮

    private var confirmButton: some View {
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
        .opacity(lootVisible ? 1 : 0)
        .padding(.bottom, 8)
    }

    // MARK: - 格式化工具

    private func formatDistance(_ meters: Int) -> String {
        if meters >= 1000 {
            return String(format: "%.1f 千m", Double(meters) / 1000)
        }
        return "\(meters) m"
    }

    private func formatArea(_ m2: Int) -> String {
        if m2 >= 10_000 {
            return String(format: "%.0f 万m²", Double(m2) / 10_000)
        }
        return "\(m2) m²"
    }

    // MARK: - 入场动画（分三段顺序播放）

    private func triggerAnimations() {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) {
            headerVisible = true
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.25)) {
            statsVisible = true
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.45)) {
            lootVisible = true
        }
    }
}

// MARK: - Preview

#Preview {
    Color.black.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            ExplorationResultView(result: MockExplorationResult.sample)
        }
}
