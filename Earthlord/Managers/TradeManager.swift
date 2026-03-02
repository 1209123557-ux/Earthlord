//
//  TradeManager.swift
//  Earthlord
//
//  交易系统核心逻辑：挂单创建、接受、取消、查询、评价。
//  所有写操作通过 Supabase RPC 函数执行，保证数据原子性和行级锁安全。
//

import Foundation
import Combine
import Supabase
import OSLog

@MainActor
final class TradeManager: ObservableObject {

    static let shared = TradeManager()

    private let logger = Logger(subsystem: "com.earthlord", category: "TradeManager")

    // MARK: - Published

    @Published private(set) var myOffers: [TradeOffer] = []
    @Published private(set) var availableOffers: [TradeOffer] = []
    @Published private(set) var tradeHistory: [TradeHistory] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    // MARK: - 创建挂单

    /// 发布一条交易挂单，同时从库存扣除 offeringItems。
    func createTradeOffer(
        offeringItems: [(itemId: String, quantity: Int)],
        requestingItems: [(itemId: String, quantity: Int)],
        expireHours: Int = 24,
        message: String? = nil
    ) async throws {
        guard AuthManager.shared.currentUser != nil else { throw TradeError.notAuthenticated }

        isLoading = true
        defer { isLoading = false }

        let params: [String: AnyJSON] = [
            "p_offering_items":   itemsToAnyJSON(offeringItems),
            "p_requesting_items": itemsToAnyJSON(requestingItems),
            "p_expire_hours":     .number(Double(expireHours)),
            "p_message":          message.map { .string($0) } ?? .null
        ]

        let result: AnyJSON = try await supabase
            .rpc("create_trade_offer", params: params)
            .execute().value
        try parseResult(result, action: "创建挂单")

        await InventoryManager.shared.fetchInventory()
        await loadMyOffers()
        logger.info("[Trade] ✅ 挂单创建成功")
    }

    // MARK: - 接受交易

    /// 接受一条他人的挂单，触发双向物品转移。
    func acceptTradeOffer(offerId: String) async throws {
        guard AuthManager.shared.currentUser != nil else { throw TradeError.notAuthenticated }

        isLoading = true
        defer { isLoading = false }

        let params: [String: AnyJSON] = ["p_offer_id": .string(offerId)]
        let result: AnyJSON = try await supabase
            .rpc("accept_trade_offer", params: params)
            .execute().value
        try parseResult(result, action: "接受交易")

        await InventoryManager.shared.fetchInventory()
        await loadAvailableOffers()
        await loadHistory()
        logger.info("[Trade] ✅ 交易接受成功（offer: \(offerId)）")
    }

    // MARK: - 取消挂单

    /// 取消自己发布的挂单，物品自动退回库存。
    func cancelTradeOffer(offerId: String) async throws {
        guard AuthManager.shared.currentUser != nil else { throw TradeError.notAuthenticated }

        isLoading = true
        defer { isLoading = false }

        let params: [String: AnyJSON] = ["p_offer_id": .string(offerId)]
        let result: AnyJSON = try await supabase
            .rpc("cancel_trade_offer", params: params)
            .execute().value
        try parseResult(result, action: "取消挂单")

        await InventoryManager.shared.fetchInventory()
        await loadMyOffers()
        logger.info("[Trade] ✅ 挂单取消成功（offer: \(offerId)）")
    }

    // MARK: - 加载我的挂单

    /// 打开"我的挂单"页面时调用。先处理过期挂单（退还物品），再拉取列表。
    func loadMyOffers() async {
        guard let userId = AuthManager.shared.currentUser?.id else { return }

        // 处理过期挂单（退还物品到库存）
        let _: AnyJSON? = try? await supabase
            .rpc("expire_my_trade_offers", params: [:] as [String: AnyJSON])
            .execute().value

        do {
            let offers: [TradeOffer] = try await supabase
                .from("trade_offers")
                .select()
                .eq("owner_id", value: userId.uuidString.lowercased())
                .order("created_at", ascending: false)
                .execute().value
            myOffers = offers
            logger.info("[Trade] 我的挂单 \(offers.count) 条")
        } catch {
            logger.error("[Trade] 拉取我的挂单失败: \(error)")
            errorMessage = "加载我的挂单失败"
        }
    }

    // MARK: - 加载可接受的挂单

    /// 打开"交易市场"页面时调用。返回他人发布的、active 且未过期的挂单。
    func loadAvailableOffers() async {
        guard let userId = AuthManager.shared.currentUser?.id else { return }

        let nowISO = ISO8601DateFormatter().string(from: Date())
        do {
            let offers: [TradeOffer] = try await supabase
                .from("trade_offers")
                .select()
                .eq("status", value: "active")
                .gt("expires_at", value: nowISO)
                .neq("owner_id", value: userId.uuidString.lowercased())
                .order("created_at", ascending: false)
                .execute().value
            availableOffers = offers
            logger.info("[Trade] 可接受挂单 \(offers.count) 条")
        } catch {
            logger.error("[Trade] 拉取可用挂单失败: \(error)")
            errorMessage = "加载交易市场失败"
        }
    }

    // MARK: - 加载交易历史

    /// 打开"交易历史"页面时调用。
    func loadHistory() async {
        guard let userId = AuthManager.shared.currentUser?.id else { return }

        let uid = userId.uuidString.lowercased()
        do {
            let history: [TradeHistory] = try await supabase
                .from("trade_history")
                .select()
                .or("seller_id.eq.\(uid),buyer_id.eq.\(uid)")
                .order("completed_at", ascending: false)
                .execute().value
            tradeHistory = history
            logger.info("[Trade] 交易历史 \(history.count) 条")
        } catch {
            logger.error("[Trade] 拉取交易历史失败: \(error)")
            errorMessage = "加载交易历史失败"
        }
    }

    // MARK: - 评价交易

    /// 对已完成的交易提交评分（1-5）和可选评语。买卖双方各限一次。
    func rateTrade(historyId: String, rating: Int, comment: String? = nil) async throws {
        guard AuthManager.shared.currentUser != nil else { throw TradeError.notAuthenticated }

        let params: [String: AnyJSON] = [
            "p_history_id": .string(historyId),
            "p_rating":     .number(Double(rating)),
            "p_comment":    comment.map { .string($0) } ?? .null
        ]
        let result: AnyJSON = try await supabase
            .rpc("rate_trade", params: params)
            .execute().value
        try parseResult(result, action: "评价交易")
        await loadHistory()
        logger.info("[Trade] ✅ 评价提交成功（history: \(historyId)，rating: \(rating)）")
    }

    // MARK: - Private Helpers

    /// 将 [(itemId, quantity)] 转换为 AnyJSON 数组
    private func itemsToAnyJSON(_ list: [(itemId: String, quantity: Int)]) -> AnyJSON {
        .array(list.map {
            .object(["item_id": .string($0.itemId), "quantity": .number(Double($0.quantity))])
        })
    }

    /// 解析 RPC 返回的 JSONB 结果，失败时抛出 TradeError.serverError
    private func parseResult(_ result: AnyJSON, action: String) throws {
        guard case .object(let obj) = result,
              case .bool(true) = obj["success"] else {
            let msg: String
            if case .object(let obj) = result,
               case .string(let errMsg) = obj["error"] {
                msg = errMsg
            } else {
                msg = "\(action)失败"
            }
            logger.error("[Trade] ❌ \(action)失败: \(msg)")
            throw TradeError.serverError(msg)
        }
    }
}
