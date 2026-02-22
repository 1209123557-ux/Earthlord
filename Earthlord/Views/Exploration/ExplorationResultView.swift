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
    /// 若不为 nil，则显示失败状态（正常探索时传 nil）
    var errorMessage: String? = nil

    @Environment(\.dismiss) private var dismiss

    private var isError: Bool { errorMessage != nil }

    // 控制入场动画
    @State private var headerVisible  = false
    @State private var statsVisible   = false
    @State private var lootVisible    = false

    // 数字递增动画
    @State private var countedWalk = 0

    var body: some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            if isError {
                errorStateView
            } else {
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
                    current: formatDistance(countedWalk),          // 动态递增
                    cumulative: formatDistance(result.totalWalkDistanceM),
                    rank: result.walkRank
                )
                statDivider
                // 奖励等级
                rewardTierRow
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
            Text(formatDuration(result.durationSeconds))
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

    /// 奖励等级行（替代已删除的"探索面积"）
    private var rewardTierRow: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.warning)
                Text("奖励等级")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                Spacer()
            }
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.rewardTier.displayName)
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(ApocalypseTheme.warning)
                    Text(result.rewardTier.distanceDescription)
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
                Spacer()
            }
        }
        .padding(.vertical, 14)
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
                        lootRow(loot: loot, index: idx)
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
        // 卡片整体在 lootVisible 时快速出现，内部物品行逐条错开
        .opacity(lootVisible ? 1 : 0)
        .animation(.easeOut(duration: 0.2), value: lootVisible)
    }

    private func lootRow(loot: (itemId: String, quantity: Int), index: Int) -> some View {
        let def = MockItemDefinitions.find(loot.itemId)
        let (icon, color) = iconAndColor(for: def?.category)
        // 每行的延迟：在 lootVisible 触发后，各行错开 0.18s
        let rowDelay = Double(index) * 0.18

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

            // 右：数量 + 对勾（对勾有弹跳效果）
            HStack(spacing: 8) {
                Text("×\(loot.quantity)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(ApocalypseTheme.warning)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.success)
                    // 弹跳：从 0.1 弹出到 1，低阻尼产生回弹感
                    .scaleEffect(lootVisible ? 1.0 : 0.1)
                    .animation(
                        .spring(response: 0.38, dampingFraction: 0.42)
                            .delay(rowDelay + 0.18),
                        value: lootVisible
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        // 行整体：向上滑入 + 淡入
        .opacity(lootVisible ? 1 : 0)
        .offset(y: lootVisible ? 0 : 10)
        .animation(
            .easeOut(duration: 0.3).delay(rowDelay),
            value: lootVisible
        )
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

    // MARK: - 错误状态

    private var errorStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            // 图标
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.danger)

            // 文案
            VStack(spacing: 10) {
                Text("探索失败")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(errorMessage ?? "发生未知错误，请稍后重试")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(.horizontal, 40)

            Spacer()

            // 重试按钮（关闭弹窗，让用户重新触发探索）
            Button(action: { dismiss() }) {
                Text("返回重试")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(ApocalypseTheme.danger)
                    .cornerRadius(14)
                    .shadow(color: ApocalypseTheme.danger.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 格式化工具

    private func formatDistance(_ meters: Int) -> String {
        if meters >= 1000 {
            return String(format: "%.1f 千m", Double(meters) / 1000)
        }
        return "\(meters) m"
    }

    private func formatDuration(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    // MARK: - 入场动画（分三段顺序播放）

    private func triggerAnimations() {
        guard !isError else { return }   // 失败状态无需播放入场动画
        withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) {
            headerVisible = true
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.25)) {
            statsVisible = true
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.45)) {
            lootVisible = true
        }
        // 统计数字从 0 跳动到目标值（与统计卡同步开始）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            startCounting()
        }
    }

    /// 数字递增动画：24 帧 ease-out，约 0.7 秒完成
    private func startCounting() {
        let steps      = 24
        let duration   = 0.7
        let interval   = duration / Double(steps)
        let targetWalk = result.walkDistanceM

        for i in 1...steps {
            let t     = Double(i) / Double(steps)
            let eased = 1 - pow(1 - t, 3)   // cubic ease-out
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * interval) {
                countedWalk = Int(Double(targetWalk) * eased)
            }
        }
        // 保证最终值精确
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.05) {
            countedWalk = targetWalk
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
