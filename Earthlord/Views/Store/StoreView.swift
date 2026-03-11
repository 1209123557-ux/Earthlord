//
//  StoreView.swift
//  Earthlord
//
//  商城主页：物资包 Tab + 订阅 Tab
//

import SwiftUI
import StoreKit

struct StoreView: View {

    @StateObject private var purchaseManager = PurchaseManager.shared
    @StateObject private var mailboxManager = MailboxManager.shared
    @EnvironmentObject private var inventoryManager: InventoryManager
    @State private var storeTab = 0
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
                VStack(spacing: 0) {
                    // ── 顶部 Tab Picker ──
                    Picker("商城分类", selection: $storeTab) {
                        Text("物资包").tag(0)
                        Text("订阅").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if storeTab == 0 {
                        packTab
                    } else {
                        SubscriptionView(purchasingId: $purchasingId, onPurchase: { sub in
                            Task { await buySubscription(sub) }
                        })
                    }
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

    // MARK: - Pack Tab

    private var packTab: some View {
        ScrollView {
            VStack(spacing: 20) {
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

                Spacer(minLength: 24)
            }
            .padding(.top, 12)
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

    private func buySubscription(_ sub: SubscriptionProduct) async {
        guard let product = purchaseManager.product(for: sub.id) else { return }
        purchasingId = sub.id
        await purchaseManager.purchase(product)
        purchasingId = nil

        if let error = purchaseManager.purchaseError {
            alertMessage = error
            showErrorAlert = true
        } else {
            alertMessage = "订阅成功！会员权益已生效"
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
