//
//  TradeMarketView.swift
//  Earthlord
//
//  交易市场页面：浏览他人发布的可接受挂单。
//

import SwiftUI

struct TradeMarketView: View {

    @EnvironmentObject private var inventoryManager: InventoryManager
    @ObservedObject private var tradeManager = TradeManager.shared

    var body: some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // 读取失败提示
                if let errMsg = tradeManager.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 13))
                        Text(errMsg)
                            .font(.system(size: 13))
                    }
                    .foregroundColor(ApocalypseTheme.warning)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(ApocalypseTheme.warning.opacity(0.08))
                }

                if tradeManager.isLoading && tradeManager.availableOffers.isEmpty {
                    Spacer()
                    ProgressView()
                        .tint(ApocalypseTheme.primary)
                    Spacer()
                } else {
                    ScrollView {
                        if tradeManager.availableOffers.isEmpty {
                            emptyState
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(tradeManager.availableOffers) { offer in
                                    NavigationLink(destination:
                                        OfferDetailView(offer: offer)
                                            .environmentObject(inventoryManager)
                                    ) {
                                        MarketOfferCard(offer: offer)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                    }
                    .refreshable {
                        await tradeManager.loadAvailableOffers()
                    }
                }
            }
        }
        .navigationTitle("交易市场")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            Task { await tradeManager.loadAvailableOffers() }
        }
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "cart.badge.questionmark")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textMuted)
            Text("暂无可接受的交易")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textSecondary)
            Text("其他玩家尚未发布挂单，下拉刷新试试")
                .font(.system(size: 13))
                .foregroundColor(ApocalypseTheme.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
}

// MARK: - MarketOfferCard

private struct MarketOfferCard: View {
    let offer: TradeOffer

    var body: some View {
        ELCard {
            VStack(alignment: .leading, spacing: 10) {
                // 顶部：发布者 + 时间
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(ApocalypseTheme.primary)
                        Text("@\(offer.ownerUsername ?? "未知")")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }
                    Spacer()
                    Text(offer.formattedExpiry)
                        .font(.system(size: 11))
                        .foregroundColor(offer.isExpired ? .orange : ApocalypseTheme.textMuted)
                }

                Divider().background(Color.white.opacity(0.07))

                // 他出 / 他要
                itemSummaryRow(label: "他出", items: offer.offeringItems, color: ApocalypseTheme.success)
                itemSummaryRow(label: "他要", items: offer.requestingItems, color: ApocalypseTheme.danger)

                // 留言预览
                if let msg = offer.message, !msg.isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 10))
                            .foregroundColor(ApocalypseTheme.textMuted)
                        Text(msg)
                            .font(.system(size: 11))
                            .foregroundColor(ApocalypseTheme.textMuted)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private func itemSummaryRow(label: String, items: [TradeItemEntry], color: Color) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 28, alignment: .leading)
            FlowItemList(items: Array(items.prefix(3)))
            if items.count > 3 {
                Text("+\(items.count - 3)")
                    .font(.system(size: 11))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
    }
}
