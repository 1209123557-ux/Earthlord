//
//  TradeHistoryView.swift
//  Earthlord
//
//  交易历史页面（含评价功能）。
//

import SwiftUI
import Supabase

struct TradeHistoryView: View {

    @ObservedObject private var tradeManager = TradeManager.shared

    @State private var rateTarget: TradeHistory? = nil

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

                if tradeManager.isLoading && tradeManager.tradeHistory.isEmpty {
                    Spacer()
                    ProgressView()
                        .tint(ApocalypseTheme.primary)
                    Spacer()
                } else {
                    ScrollView {
                        if tradeManager.tradeHistory.isEmpty {
                            emptyState
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(tradeManager.tradeHistory) { record in
                                    HistoryCard(record: record, onRate: { rateTarget = record })
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                    }
                    .refreshable {
                        await tradeManager.loadHistory()
                    }
                }
            }
        }
        .navigationTitle("交易历史")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            Task { await tradeManager.loadHistory() }
        }
        .sheet(item: $rateTarget) { record in
            RateTradeSheet(record: record) {
                rateTarget = nil
            }
        }
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textMuted)
            Text("暂无交易记录")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textSecondary)
            Text("完成第一笔交易后，记录将显示在这里")
                .font(.system(size: 13))
                .foregroundColor(ApocalypseTheme.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
}

// MARK: - HistoryCard

private struct HistoryCard: View {
    let record: TradeHistory
    let onRate: () -> Void

    private var currentUserId: String? {
        AuthManager.shared.currentUser?.id.uuidString.lowercased()
    }

    private var isSeller: Bool {
        record.sellerId == currentUserId
    }

    // 当前用户给出的物品（seller 给 offeringItems，buyer 给 requestingItems）
    private var myItems: [TradeItemEntry] {
        isSeller
            ? record.itemsExchanged.offeringItems
            : record.itemsExchanged.requestingItems
    }

    // 当前用户获得的物品
    private var receivedItems: [TradeItemEntry] {
        isSeller
            ? record.itemsExchanged.requestingItems
            : record.itemsExchanged.offeringItems
    }

    private var counterpartName: String {
        isSeller
            ? (record.buyerUsername ?? "未知")
            : (record.sellerUsername ?? "未知")
    }

    // 当前用户的评分（seller 用 sellerRating，buyer 用 buyerRating）
    private var myRating: Int? {
        isSeller ? record.sellerRating : record.buyerRating
    }

    // 对方的评分
    private var theirRating: Int? {
        isSeller ? record.buyerRating : record.sellerRating
    }

    var body: some View {
        ELCard {
            VStack(alignment: .leading, spacing: 10) {
                // 顶部：对方用户 + 时间
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left.arrow.right.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(ApocalypseTheme.primary)
                        Text("与 @\(counterpartName) 交易")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }
                    Spacer()
                    Text(formattedDate(record.completedAt))
                        .font(.system(size: 11))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }

                Divider().background(Color.white.opacity(0.07))

                // 我给出 / 我获得
                itemsRow(label: "我给出", items: myItems,       color: ApocalypseTheme.danger)
                itemsRow(label: "我获得", items: receivedItems, color: ApocalypseTheme.success)

                Divider().background(Color.white.opacity(0.07))

                // 评价行
                HStack(spacing: 16) {
                    ratingSection(label: "我的评价", rating: myRating, showButton: true)
                    Spacer()
                    ratingSection(label: "对方评价", rating: theirRating, showButton: false)
                }
            }
        }
    }

    // MARK: - Sub-views

    private func itemsRow(label: String, items: [TradeItemEntry], color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 42, alignment: .leading)
            FlowItemList(items: items)
        }
    }

    private func ratingSection(label: String, rating: Int?, showButton: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(ApocalypseTheme.textMuted)
            if let r = rating {
                starsView(r)
            } else if showButton {
                Button(action: onRate) {
                    Text("去评价")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(ApocalypseTheme.primary.opacity(0.15))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            } else {
                Text("待评价")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
    }

    private func starsView(_ rating: Int) -> some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: i <= rating ? "star.fill" : "star")
                    .font(.system(size: 12))
                    .foregroundColor(i <= rating ? .yellow : ApocalypseTheme.textMuted)
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f.string(from: date)
    }
}

// MARK: - RateTradeSheet

struct RateTradeSheet: View {

    let record: TradeHistory
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var tradeManager = TradeManager.shared

    @State private var selectedRating: Int = 5
    @State private var comment: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String? = nil
    @State private var showErrorAlert = false

    var body: some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            VStack(spacing: 24) {
                // 标题
                Text("评价交易")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .padding(.top, 24)

                // 星星评分
                HStack(spacing: 12) {
                    ForEach(1...5, id: \.self) { i in
                        Button(action: { selectedRating = i }) {
                            Image(systemName: i <= selectedRating ? "star.fill" : "star")
                                .font(.system(size: 36))
                                .foregroundColor(i <= selectedRating ? .yellow : ApocalypseTheme.textMuted)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // 评语输入
                TextField("", text: $comment,
                          prompt: Text("写点评语（可选）").foregroundColor(ApocalypseTheme.textMuted))
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .padding(14)
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(12)
                    .padding(.horizontal, 24)

                // 提交按钮
                Button(action: submit) {
                    HStack(spacing: 8) {
                        if isSubmitting {
                            ProgressView().tint(.white).scaleEffect(0.85)
                        }
                        Text(isSubmitting ? "提交中…" : "提交评价")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(isSubmitting ? ApocalypseTheme.textMuted : ApocalypseTheme.primary)
                    .cornerRadius(14)
                }
                .disabled(isSubmitting)
                .buttonStyle(.plain)
                .padding(.horizontal, 24)

                Button("取消") { dismiss() }
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()
            }
        }
        .alert("评价失败", isPresented: $showErrorAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "提交失败，请重试")
        }
    }

    private func submit() {
        isSubmitting = true
        Task {
            do {
                try await tradeManager.rateTrade(
                    historyId: record.id,
                    rating: selectedRating,
                    comment: comment.isEmpty ? nil : comment
                )
                onDone()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
            isSubmitting = false
        }
    }
}
