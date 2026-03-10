//
//  StoreView.swift
//  Earthlord
//
//  商城主页：物资包 + 背包扩容包
//

import SwiftUI
import StoreKit

struct StoreView: View {

    @StateObject private var purchaseManager = PurchaseManager.shared
    @StateObject private var mailboxManager = MailboxManager.shared
    @EnvironmentObject private var inventoryManager: InventoryManager
    @State private var purchasingId: String? = nil
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var alertMessage = ""
    @State private var showMailbox = false

    var body: some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            if purchaseManager.isLoading {
                loadingView
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        // ── 物资包区域 ──
                        sectionHeader(title: "末日物资包", icon: "shippingbox.fill")

                        ForEach(PackCatalog.all, id: \.productId) { pack in
                            PackProductCard(
                                pack: pack,
                                product: purchaseManager.product(for: pack.productId),
                                isPurchasing: purchasingId == pack.productId,
                                onBuy: { Task { await buyPack(pack) } }
                            )
                            .padding(.horizontal, 16)
                        }

                        // ── 背包扩容区域 ──
                        sectionHeader(title: "背包扩容", icon: "bag.badge.plus")

                        ForEach(BagExpansionCatalog.all, id: \.productId) { exp in
                            BagExpansionCard(
                                expansion: exp,
                                product: purchaseManager.product(for: exp.productId),
                                isPurchasing: purchasingId == exp.productId,
                                onBuy: { Task { await buyExpansion(exp) } }
                            )
                            .padding(.horizontal, 16)
                        }

                        // 当前背包容量提示
                        capacityHint
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
                    }
                    .padding(.top, 12)
                }
            }
        }
        .navigationTitle("末日商城")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showMailbox = true }) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 17))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                        if mailboxManager.unclaimedCount > 0 {
                            Circle()
                                .fill(ApocalypseTheme.danger)
                                .frame(width: 8, height: 8)
                                .offset(x: 4, y: -4)
                        }
                    }
                }
            }
        }
        .navigationDestination(isPresented: $showMailbox) {
            MailboxView()
        }
        .task {
            await purchaseManager.loadProducts()
            await mailboxManager.fetchMailbox()
        }
        .alert("购买成功", isPresented: $showSuccessAlert) {
            Button("去邮箱领取", role: .none) { }
        } message: {
            Text(alertMessage)
        }
        .alert("购买失败", isPresented: $showErrorAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - Section Header

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ApocalypseTheme.primary)
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    // MARK: - Capacity Hint

    private var capacityHint: some View {
        ELCard(padding: EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(ApocalypseTheme.info)
                    .font(.system(size: 14))
                Text("当前背包容量：\(inventoryManager.totalCount) / \(inventoryManager.maxCapacity)（基础100 + 扩容\(inventoryManager.expansionCapacity)）")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(ApocalypseTheme.primary)
                .scaleEffect(1.4)
            Text("加载商品中...")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Buy Actions

    private func buyPack(_ pack: PackDefinition) async {
        guard let product = purchaseManager.product(for: pack.productId) else { return }
        purchasingId = pack.productId
        await purchaseManager.purchase(product)
        purchasingId = nil

        if let error = purchaseManager.purchaseError {
            alertMessage = error
            showErrorAlert = true
        } else {
            alertMessage = "物品已发送到您的邮箱，请打开邮箱领取"
            showSuccessAlert = true
        }
    }

    private func buyExpansion(_ expansion: BagExpansionProduct) async {
        guard let product = purchaseManager.product(for: expansion.productId) else { return }
        purchasingId = expansion.productId
        await purchaseManager.purchase(product)
        purchasingId = nil

        if let error = purchaseManager.purchaseError {
            alertMessage = error
            showErrorAlert = true
        } else {
            alertMessage = "背包已扩容 +\(expansion.extraCapacity) 格，立即生效"
            showSuccessAlert = true
        }
    }
}

#Preview {
    NavigationStack {
        StoreView()
    }
    .environmentObject(InventoryManager.shared)
}
