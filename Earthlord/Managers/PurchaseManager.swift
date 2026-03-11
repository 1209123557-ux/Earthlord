//
//  PurchaseManager.swift
//  Earthlord
//
//  StoreKit 2 购买管理：加载商品、发起购买、监听 Transaction
//

import Foundation
import StoreKit
import Supabase
import OSLog
import Combine

@MainActor
final class PurchaseManager: ObservableObject {

    static let shared = PurchaseManager()
    private let logger = Logger(subsystem: "com.earthlord", category: "PurchaseManager")

    // MARK: - Published

    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading = false
    @Published private(set) var purchaseError: String? = nil
    @Published private(set) var isPurchasing = false

    // 所有 product IDs
    private let allProductIds: [String] = [
        "com.earthlord.supply.survivor",
        "com.earthlord.supply.explorer",
        "com.earthlord.supply.lord",
        "com.earthlord.supply.overlord",
        "com.earthlord.sub.monthly",
        "com.earthlord.sub.yearly",
    ]

    private var transactionListenerTask: Task<Void, Never>?

    // MARK: - Init

    private init() {
        transactionListenerTask = listenForTransactions()
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        guard products.isEmpty else { return }
        await fetchProducts()
    }

    func reloadProducts() async {
        products = []
        await fetchProducts()
    }

    private func fetchProducts() async {
        isLoading = true
        purchaseError = nil
        do {
            let fetched = try await Product.products(for: allProductIds)
            products = fetched.sorted { $0.price < $1.price }
            logger.info("[Purchase] 商品加载完成，共 \(self.products.count) 个")
            if products.isEmpty {
                purchaseError = "未找到任何商品（已请求 \(self.allProductIds.count) 个 ID）。\n请确认 Scheme → Options → StoreKit Configuration 已选择 Earthlord.storekit"
            }
        } catch {
            logger.error("[Purchase] 商品加载失败: \(error.localizedDescription)")
            purchaseError = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async {
        guard !isPurchasing else { return }
        isPurchasing = true
        purchaseError = nil

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await handleTransaction(transaction)
                await transaction.finish()
                logger.info("[Purchase] 购买成功: \(product.id)")
            case .userCancelled:
                logger.info("[Purchase] 用户取消购买: \(product.id)")
            case .pending:
                logger.info("[Purchase] 购买待处理: \(product.id)")
            @unknown default:
                break
            }
        } catch {
            logger.error("[Purchase] 购买失败: \(error.localizedDescription)")
            purchaseError = "购买失败：\(error.localizedDescription)"
        }

        isPurchasing = false
    }

    // MARK: - Transaction Listener（App 启动后持续监听，防漏单）

    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                do {
                    let transaction = try self.checkVerified(result)
                    await self.handleTransaction(transaction)
                    await transaction.finish()
                } catch {
                    await MainActor.run {
                        self.logger.error("[Purchase] Transaction 验证失败: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    // MARK: - Handle Transaction

    private func handleTransaction(_ transaction: Transaction) async {
        let productId = transaction.productID
        let transactionId = String(transaction.id)
        logger.info("[Purchase] 处理 transaction: \(productId) txId=\(transactionId)")

        guard let userId = AuthManager.shared.currentUser?.id else {
            logger.error("[Purchase] 未登录，无法发货")
            return
        }

        if let pack = PackCatalog.find(productId) {
            // 物资包：生成物品列表，写入邮箱
            await grantPackToMailbox(
                userId: userId,
                pack: pack,
                transactionId: transactionId
            )
        } else if productId == SubscriptionTier.monthly.rawValue ||
                  productId == SubscriptionTier.yearly.rawValue {
            // 订阅：刷新订阅状态
            await SubscriptionManager.shared.refreshStatus()
        }
    }

    // MARK: - Grant Pack to Mailbox

    private func grantPackToMailbox(userId: UUID, pack: PackDefinition, transactionId: String) async {
        let generatedItems = pack.generateItems()
        let itemsJSON: [AnyJSON] = generatedItems.map { item in
            .object([
                "item_id":  .string(item.itemId),
                "quantity": .integer(item.quantity),
                "source":   .string("purchase"),
            ])
        }

        let params: [String: AnyJSON] = [
            "p_user_id":        .string(userId.uuidString.lowercased()),
            "p_product_id":     .string(pack.productId),
            "p_transaction_id": .string(transactionId),
            "p_items":          .array(itemsJSON),
        ]

        do {
            try await supabase.rpc("grant_pack_to_mailbox", params: params).execute()
            logger.info("[Purchase] 邮箱发货成功: \(pack.productId) \(generatedItems.count) 种物品")
            // 通知 MailboxManager 刷新
            await MailboxManager.shared.fetchMailbox()
        } catch {
            logger.error("[Purchase] 邮箱发货失败: \(error.localizedDescription)")
        }
    }

    // MARK: - Verify Transaction

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }

    // MARK: - Helpers

    func product(for id: String) -> Product? {
        products.first { $0.id == id }
    }
}
