//
//  MailboxView.swift
//  Earthlord
//
//  邮箱页面：查看并领取通过内购获得的物品
//

import SwiftUI

struct MailboxView: View {

    @StateObject private var mailboxManager = MailboxManager.shared
    @EnvironmentObject private var inventoryManager: InventoryManager
    @State private var claimResultMessage: String? = nil
    @State private var showResultAlert = false

    var body: some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // 一键全领按钮（有未领取时显示）
                if mailboxManager.unclaimedCount > 0 {
                    claimAllBanner
                }

                if mailboxManager.isLoading && mailboxManager.items.isEmpty {
                    loadingView
                } else if mailboxManager.items.isEmpty {
                    emptyView
                } else {
                    itemList
                }
            }
        }
        .navigationTitle("邮箱")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await mailboxManager.fetchMailbox() }
        .alert("提示", isPresented: $showResultAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(claimResultMessage ?? "")
        }
    }

    // MARK: - Claim All Banner

    private var claimAllBanner: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("有 \(mailboxManager.unclaimedCount) 件物品待领取")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Text("30天内未领取将自动过期")
                    .font(.system(size: 11))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
            Spacer()
            Button(action: {
                Task { await claimAll() }
            }) {
                HStack(spacing: 6) {
                    if mailboxManager.isClaiming {
                        ProgressView().tint(.white).scaleEffect(0.7)
                    } else {
                        Image(systemName: "tray.and.arrow.down.fill")
                            .font(.system(size: 13))
                    }
                    Text("一键全领")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(ApocalypseTheme.primary)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .disabled(mailboxManager.isClaiming)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - Item List

    private var itemList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(mailboxManager.items) { item in
                    MailboxItemRow(
                        item: item,
                        isClaiming: mailboxManager.isClaiming,
                        onClaim: { Task { await claimSingle(item) } }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Loading / Empty

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().tint(ApocalypseTheme.primary).scaleEffect(1.3)
            Text("加载邮件中...").font(.system(size: 14)).foregroundColor(ApocalypseTheme.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "envelope")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)
            Text("邮箱空空如也")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textSecondary)
            Text("购买物资包后，物品将通过邮箱发放")
                .font(.system(size: 13))
                .foregroundColor(ApocalypseTheme.textMuted)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func claimSingle(_ item: MailboxItem) async {
        let result = await mailboxManager.claimItem(item)
        switch result {
        case .success:
            return
        case .alreadyClaimed:
            claimResultMessage = "该物品已领取"
        case .expired:
            claimResultMessage = "该物品已过期"
        case .bagFull(let need, let available):
            claimResultMessage = "背包空间不足（需要 \(need) 格，剩余 \(available) 格）\n请清理背包或购买扩容包"
        case .failed(let msg):
            claimResultMessage = msg
        }
        showResultAlert = true
    }

    private func claimAll() async {
        await mailboxManager.claimAll()
        if let error = mailboxManager.claimError {
            claimResultMessage = error
            showResultAlert = true
        }
    }
}

// MARK: - MailboxItemRow

private struct MailboxItemRow: View {
    let item: MailboxItem
    let isClaiming: Bool
    let onClaim: () -> Void

    private var definition: ItemDefinition? { MockItemDefinitions.find(item.itemId) }

    private var statusColor: Color {
        if item.isClaimed { return Color(white: 0.45) }
        if item.isExpired  { return ApocalypseTheme.danger }
        return ApocalypseTheme.success
    }

    private var statusLabel: String {
        if item.isClaimed { return "已领取" }
        if item.isExpired  { return "已过期" }
        return "待领取"
    }

    var body: some View {
        ELCard(padding: EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)) {
            HStack(spacing: 12) {
                // 图标
                itemIcon

                // 物品信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(definition?.displayName ?? item.itemId)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(item.isClaimed ? ApocalypseTheme.textMuted : ApocalypseTheme.textPrimary)
                    Text("数量：×\(item.quantity)")
                        .font(.system(size: 13))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    // 状态标签
                    Text(statusLabel)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(statusColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(statusColor.opacity(0.15))
                        .cornerRadius(5)
                }

                Spacer()

                // 领取按钮（仅未领取且未过期时显示）
                if !item.isClaimed && !item.isExpired {
                    Button(action: onClaim) {
                        Text("领取")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 54, height: 32)
                            .background(ApocalypseTheme.primary)
                            .cornerRadius(9)
                    }
                    .buttonStyle(.plain)
                    .disabled(isClaiming)
                }
            }
        }
        .opacity(item.isClaimed || item.isExpired ? 0.55 : 1.0)
    }

    private var itemIcon: some View {
        let (icon, color) = definition.map { def -> (String, Color) in
            switch def.category {
            case .water:    return ("drop.fill", .blue)
            case .food:     return ("fork.knife", .orange)
            case .medical:  return ("cross.fill", .red)
            case .material: return ("cube.fill", Color(red: 0.6, green: 0.45, blue: 0.3))
            case .tool:     return ("wrench.fill", .yellow)
            }
        } ?? ("shippingbox.fill", ApocalypseTheme.textMuted)

        return ZStack {
            Circle()
                .fill(color.opacity(0.18))
                .frame(width: 42, height: 42)
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
        }
    }
}

#Preview {
    NavigationStack {
        MailboxView()
    }
    .environmentObject(InventoryManager.shared)
}
