//
//  OfferDetailView.swift
//  Earthlord
//
//  挂单详情页，从 TradeMarketView push 进入。
//

import SwiftUI

struct OfferDetailView: View {

    let offer: TradeOffer

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var inventoryManager: InventoryManager
    @ObservedObject private var tradeManager = TradeManager.shared

    @State private var showAcceptAlert = false
    @State private var isAccepting = false
    @State private var toastText: String? = nil
    @State private var showToast = false

    // 库存是否全部足够
    private var inventorySufficient: Bool {
        offer.requestingItems.allSatisfy { entry in
            let inv = inventoryManager.items.first(where: { $0.itemId == entry.itemId })
            return (inv?.quantity ?? 0) >= entry.quantity
        }
    }

    var body: some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 发布者信息卡
                    publisherCard

                    // 他提供的物品
                    itemGridSection(
                        title: "他提供",
                        icon: "arrow.down.circle.fill",
                        iconColor: ApocalypseTheme.success,
                        items: offer.offeringItems
                    )

                    // 他想要的物品
                    itemGridSection(
                        title: "他想要",
                        icon: "arrow.up.circle.fill",
                        iconColor: ApocalypseTheme.danger,
                        items: offer.requestingItems
                    )

                    // 留言
                    if let msg = offer.message, !msg.isEmpty {
                        messageCard(msg)
                    }

                    // 库存检查
                    inventoryCheckCard

                    // 接受按钮
                    acceptButton

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }

            // Toast
            if showToast, let text = toastText {
                toastView(text)
            }
        }
        .navigationTitle("交易详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .alert("确认接受交易", isPresented: $showAcceptAlert) {
            Button("确认", role: .none) { acceptTrade() }
            Button("取消", role: .cancel) {}
        } message: {
            let offerNames = offer.requestingItems.map { entry in
                let name = MockItemDefinitions.find(entry.itemId)?.displayName ?? entry.itemId
                return "\(name)×\(entry.quantity)"
            }.joined(separator: "、")
            let receiveNames = offer.offeringItems.map { entry in
                let name = MockItemDefinitions.find(entry.itemId)?.displayName ?? entry.itemId
                return "\(name)×\(entry.quantity)"
            }.joined(separator: "、")
            return Text("你将付出：\(offerNames)\n你将获得：\(receiveNames)")
        }
    }

    // MARK: - 发布者信息卡

    private var publisherCard: some View {
        ELCard {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(ApocalypseTheme.primary.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: "person.fill")
                        .font(.system(size: 18))
                        .foregroundColor(ApocalypseTheme.primary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("@\(offer.ownerUsername ?? "未知用户")")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Text("发布于 \(formattedDate(offer.createdAt))")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(offer.formattedExpiry)
                        .font(.system(size: 12))
                        .foregroundColor(offer.isExpired ? .orange : ApocalypseTheme.info)
                }
            }
        }
    }

    // MARK: - 物品网格区块（2 列）

    private func itemGridSection(
        title: String,
        icon: String,
        iconColor: Color,
        items: [TradeItemEntry]
    ) -> some View {
        ELCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(iconColor)
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
                Divider().background(Color.white.opacity(0.07))
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(items, id: \.itemId) { entry in
                        itemGridCell(entry: entry)
                    }
                }
            }
        }
    }

    private func itemGridCell(entry: TradeItemEntry) -> some View {
        let def = MockItemDefinitions.find(entry.itemId)
        let (icon, color) = categoryIconColor(def?.category ?? .material)
        return HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.18))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(def?.displayName ?? entry.itemId)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .lineLimit(1)
                Text("×\(entry.quantity)")
                    .font(.system(size: 11))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.04))
        .cornerRadius(8)
    }

    // MARK: - 留言卡

    private func messageCard(_ msg: String) -> some View {
        ELCard {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "bubble.left.fill")
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textMuted)
                Text(msg)
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - 库存检查卡

    private var inventoryCheckCard: some View {
        ELCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 14))
                        .foregroundColor(inventorySufficient ? ApocalypseTheme.success : ApocalypseTheme.warning)
                    Text("库存检查")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
                Divider().background(Color.white.opacity(0.07))
                ForEach(offer.requestingItems, id: \.itemId) { entry in
                    inventoryCheckRow(entry)
                }
            }
        }
    }

    private func inventoryCheckRow(_ entry: TradeItemEntry) -> some View {
        let def = MockItemDefinitions.find(entry.itemId)
        let invQty = inventoryManager.items.first(where: { $0.itemId == entry.itemId })?.quantity ?? 0
        let sufficient = invQty >= entry.quantity
        return HStack {
            Text(def?.displayName ?? entry.itemId)
                .font(.system(size: 13))
                .foregroundColor(ApocalypseTheme.textPrimary)
            Spacer()
            Text("需要 ×\(entry.quantity) / 库存 ×\(invQty)")
                .font(.system(size: 12))
                .foregroundColor(ApocalypseTheme.textSecondary)
            Image(systemName: sufficient ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 15))
                .foregroundColor(sufficient ? ApocalypseTheme.success : ApocalypseTheme.danger)
        }
    }

    // MARK: - 接受按钮

    private var acceptButton: some View {
        Button(action: { showAcceptAlert = true }) {
            HStack(spacing: 8) {
                if isAccepting {
                    ProgressView().tint(.white).scaleEffect(0.85)
                }
                Text(isAccepting ? "处理中…" : "接受交易")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(inventorySufficient && offer.isActive && !isAccepting
                        ? ApocalypseTheme.primary
                        : ApocalypseTheme.textMuted)
            .cornerRadius(14)
        }
        .disabled(!inventorySufficient || !offer.isActive || isAccepting)
        .buttonStyle(.plain)
    }

    // MARK: - Accept Trade

    private func acceptTrade() {
        isAccepting = true
        Task {
            do {
                try await tradeManager.acceptTradeOffer(offerId: offer.id)
                toastText = "交易成功！"
                showToast = true
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                dismiss()
            } catch {
                toastText = error.localizedDescription
                showToast = true
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                showToast = false
            }
            isAccepting = false
        }
    }

    // MARK: - Toast

    private func toastView(_ text: String) -> some View {
        VStack {
            Spacer()
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.75))
                .cornerRadius(20)
                .padding(.bottom, 50)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Helpers

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f.string(from: date)
    }

    private func categoryIconColor(_ category: ItemCategory) -> (String, Color) {
        switch category {
        case .water:    return ("drop.fill",   .blue)
        case .food:     return ("fork.knife",  .orange)
        case .medical:  return ("cross.fill",  .red)
        case .material: return ("cube.fill",   Color(red: 0.6, green: 0.45, blue: 0.3))
        case .tool:     return ("wrench.fill", .yellow)
        }
    }
}
