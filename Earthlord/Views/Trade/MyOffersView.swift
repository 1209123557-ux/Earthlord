//
//  MyOffersView.swift
//  Earthlord
//
//  我的挂单列表页面。
//

import SwiftUI

struct MyOffersView: View {

    @EnvironmentObject private var inventoryManager: InventoryManager
    @ObservedObject private var tradeManager = TradeManager.shared

    @State private var cancelTargetId: String? = nil
    @State private var showCancelAlert = false

    var body: some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // 发布新挂单按钮
                NavigationLink(destination: CreateOfferView().environmentObject(inventoryManager)) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                        Text("发布新挂单")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)

                Divider().background(Color.white.opacity(0.07))

                // 挂单列表
                if tradeManager.isLoading && tradeManager.myOffers.isEmpty {
                    Spacer()
                    ProgressView()
                        .tint(ApocalypseTheme.primary)
                    Spacer()
                } else if tradeManager.myOffers.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(tradeManager.myOffers) { offer in
                                OfferCard(offer: offer, onCancel: {
                                    cancelTargetId = offer.id
                                    showCancelAlert = true
                                })
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .refreshable {
                        await tradeManager.loadMyOffers()
                    }
                }
            }
        }
        .navigationTitle("我的挂单")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            Task { await tradeManager.loadMyOffers() }
        }
        .alert("取消挂单", isPresented: $showCancelAlert) {
            Button("确认取消", role: .destructive) {
                guard let id = cancelTargetId else { return }
                Task {
                    try? await tradeManager.cancelTradeOffer(offerId: id)
                    cancelTargetId = nil
                }
            }
            Button("再想想", role: .cancel) { cancelTargetId = nil }
        } message: {
            Text("取消后物品将退回背包，确定要取消吗？")
        }
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tag.slash")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textMuted)
            Text("还没有发布过挂单")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textSecondary)
            Text("点击上方按钮发布第一个交易挂单吧")
                .font(.system(size: 13))
                .foregroundColor(ApocalypseTheme.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
}

// MARK: - OfferCard

struct OfferCard: View {
    let offer: TradeOffer
    let onCancel: (() -> Void)?

    init(offer: TradeOffer, onCancel: (() -> Void)? = nil) {
        self.offer = offer
        self.onCancel = onCancel
    }

    var body: some View {
        ELCard {
            VStack(alignment: .leading, spacing: 10) {
                // 状态行
                HStack {
                    statusBadge
                    Spacer()
                    if offer.isActive {
                        Text(offer.formattedExpiry)
                            .font(.system(size: 11))
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                }

                Divider().background(Color.white.opacity(0.07))

                // 我出 / 我要
                itemsRow(label: "我出", items: offer.offeringItems, color: ApocalypseTheme.danger)
                itemsRow(label: "我要", items: offer.requestingItems, color: ApocalypseTheme.success)

                // 留言
                if let msg = offer.message, !msg.isEmpty {
                    Text("\"\(msg)\"")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textMuted)
                        .italic()
                }

                // 已完成 → 显示接受方
                if offer.status == .completed, let buyer = offer.completedByUsername {
                    Text("由 @\(buyer) 接受")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.success)
                }

                // active → 显示取消按钮
                if offer.isActive, let cancel = onCancel {
                    Button(action: cancel) {
                        Text("取消挂单")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(ApocalypseTheme.danger)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(ApocalypseTheme.danger.opacity(0.12))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Sub-views

    private var statusBadge: some View {
        let (label, color): (String, Color) = {
            switch offer.status {
            case .active:    return (offer.isExpired ? "已过期" : "等待中", offer.isExpired ? .orange : ApocalypseTheme.info)
            case .completed: return ("已完成", ApocalypseTheme.success)
            case .cancelled: return ("已取消", ApocalypseTheme.textMuted)
            case .expired:   return ("已过期", .orange)
            }
        }()
        return Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .cornerRadius(6)
    }

    private func itemsRow(label: String, items: [TradeItemEntry], color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 28, alignment: .leading)
            FlowItemList(items: items)
        }
    }
}

// MARK: - FlowItemList（横向显示物品标签，支持换行）

struct FlowItemList: View {
    let items: [TradeItemEntry]

    var body: some View {
        let tags = items.map { entry -> String in
            let name = MockItemDefinitions.find(entry.itemId)?.displayName ?? entry.itemId
            return "\(name)×\(entry.quantity)"
        }
        return FlowLayout(tags: tags)
    }
}

// 简单的横向流式布局（最多显示前 5 个，超出省略）
struct FlowLayout: View {
    let tags: [String]

    var body: some View {
        let displayTags = tags.prefix(5)
        return HStack(spacing: 4) {
            ForEach(Array(displayTags.enumerated()), id: \.offset) { _, tag in
                Text(tag)
                    .font(.system(size: 11))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.07))
                    .cornerRadius(5)
            }
            if tags.count > 5 {
                Text("+\(tags.count - 5)")
                    .font(.system(size: 11))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
