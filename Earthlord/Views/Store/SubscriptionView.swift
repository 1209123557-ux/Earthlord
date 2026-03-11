//
//  SubscriptionView.swift
//  Earthlord
//
//  订阅子页：展示月度/年度权益卡片，已订阅时显示状态与每日补给领取
//

import SwiftUI
import StoreKit

struct SubscriptionView: View {

    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @Binding var purchasingId: String?
    let onPurchase: (SubscriptionProduct) -> Void

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        f.locale = Locale(identifier: "zh_CN")
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if subscriptionManager.isSubscribed {
                    subscribedSection
                } else {
                    unsubscribedSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }

    // MARK: - 已订阅视图

    private var subscribedSection: some View {
        VStack(spacing: 16) {
            // 当前状态卡片
            currentStatusCard

            // 每日补给领取
            dailyRewardCard

            // 权益说明
            benefitsCard(for: subscriptionManager.tier)
        }
    }

    private var currentStatusCard: some View {
        ELCard(padding: EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)) {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Text(subscriptionManager.tier.badgeText ?? "")
                        .font(.system(size: 32))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(subscriptionManager.tier.tierName)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                        if subscriptionManager.tier == .monthly {
                            Text("月度领主令")
                                .font(.system(size: 13))
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        } else {
                            Text("年度领主令")
                                .font(.system(size: 13))
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }
                    }
                    Spacer()
                }

                if let expDate = subscriptionManager.expirationDate {
                    Divider().background(Color.white.opacity(0.1))
                    HStack {
                        Image(systemName: "calendar.badge.checkmark")
                            .foregroundColor(ApocalypseTheme.success)
                            .font(.system(size: 14))
                        Text("到期时间：\(dateFormatter.string(from: expDate))")
                            .font(.system(size: 13))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                        Spacer()
                    }
                }
            }
        }
    }

    private var dailyRewardCard: some View {
        ELCard(padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)) {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "gift.fill")
                        .foregroundColor(ApocalypseTheme.warning)
                        .font(.system(size: 16))
                    Text("每日末日补给")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Spacer()
                    if subscriptionManager.tier == .yearly {
                        Text("豪华款")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.warning)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(ApocalypseTheme.warning.opacity(0.15))
                            .cornerRadius(6)
                    } else {
                        Text("基础款")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.textMuted)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(6)
                    }
                }

                // 补给内容预览
                let rewardItems = subscriptionManager.tier == .yearly
                    ? ["矿泉水×5", "饼干×3", "绷带×2", "急救包×1（30%）"]
                    : ["矿泉水×3", "饼干×2", "绷带×1"]

                HStack(spacing: 6) {
                    ForEach(rewardItems, id: \.self) { item in
                        Text(item)
                            .font(.system(size: 11))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(6)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // 领取按钮
                Button(action: {
                    Task { await subscriptionManager.claimDailyReward() }
                }) {
                    HStack(spacing: 8) {
                        if subscriptionManager.isClaimLoading {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else if subscriptionManager.canClaimToday {
                            Image(systemName: "hand.tap.fill")
                                .font(.system(size: 14))
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                        }
                        Text(subscriptionManager.isClaimLoading ? "领取中..."
                             : subscriptionManager.canClaimToday ? "领取今日补给"
                             : "今日已领取")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        subscriptionManager.canClaimToday && !subscriptionManager.isClaimLoading
                            ? ApocalypseTheme.warning
                            : Color.white.opacity(0.15)
                    )
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .disabled(!subscriptionManager.canClaimToday || subscriptionManager.isClaimLoading)
            }
        }
    }

    private func benefitsCard(for tier: SubscriptionTier) -> some View {
        let sub = tier == .yearly ? SubscriptionCatalog.yearly : SubscriptionCatalog.monthly
        return ELCard(padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)) {
            VStack(alignment: .leading, spacing: 10) {
                Text("当前会员权益")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                ForEach(sub.benefits, id: \.self) { benefit in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(ApocalypseTheme.success)
                            .font(.system(size: 13))
                        Text(benefit)
                            .font(.system(size: 14))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }
                }
            }
        }
    }

    // MARK: - 未订阅视图

    private var unsubscribedSection: some View {
        VStack(spacing: 16) {
            // 头部说明
            VStack(spacing: 6) {
                Text("解锁领主特权")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Text("订阅会员，享受更多探索、建造与交易权益")
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)

            // 月度卡片
            subscriptionCard(sub: SubscriptionCatalog.monthly, isRecommended: false)

            // 年度卡片
            subscriptionCard(sub: SubscriptionCatalog.yearly, isRecommended: true)

            // 免费玩家限制说明
            freePlayerHint
        }
    }

    private func subscriptionCard(sub: SubscriptionProduct, isRecommended: Bool) -> some View {
        ELCard(padding: EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18)) {
            VStack(alignment: .leading, spacing: 14) {
                // 标题行
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(sub.name)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(ApocalypseTheme.textPrimary)
                            if isRecommended {
                                Text("推荐")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(ApocalypseTheme.warning)
                                    .cornerRadius(5)
                            }
                        }
                        if let save = sub.saveLabel {
                            Text(save)
                                .font(.system(size: 12))
                                .foregroundColor(ApocalypseTheme.success)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(sub.price)
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundColor(isRecommended ? ApocalypseTheme.warning : ApocalypseTheme.primary)
                        Text("/\(sub.period)")
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                }

                Divider().background(Color.white.opacity(0.1))

                // 权益列表
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(sub.benefits, id: \.self) { benefit in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(isRecommended ? ApocalypseTheme.warning : ApocalypseTheme.success)
                                .font(.system(size: 13))
                            Text(benefit)
                                .font(.system(size: 13))
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }
                    }
                }

                // 购买按钮
                let isPurchasing = purchasingId == sub.id
                Button(action: { onPurchase(sub) }) {
                    HStack(spacing: 8) {
                        if isPurchasing {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 13))
                        }
                        Text(isPurchasing ? "订阅中..." : "立即订阅 \(sub.price)/\(sub.period)")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        isPurchasing
                            ? (isRecommended ? ApocalypseTheme.warning.opacity(0.5) : ApocalypseTheme.primary.opacity(0.5))
                            : (isRecommended ? ApocalypseTheme.warning : ApocalypseTheme.primary)
                    )
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .disabled(isPurchasing)
            }
        }
        .overlay(
            isRecommended
                ? RoundedRectangle(cornerRadius: 16)
                    .stroke(ApocalypseTheme.warning.opacity(0.5), lineWidth: 1.5)
                : nil
        )
    }

    private var freePlayerHint: some View {
        ELCard(padding: EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(ApocalypseTheme.info)
                    .font(.system(size: 14))
                Text("免费玩家：探索5次/日，建造3个，挂单3条，背包无加成")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
    }
}
