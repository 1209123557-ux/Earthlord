//
//  InventoryManager.swift
//  Earthlord
//
//  负责背包数据与 Supabase inventory_items 表的同步。
//  作为 @StateObject 注入 MainTabView，通过 @EnvironmentObject 向下传递。
//

import Foundation
import Combine
import Supabase
import OSLog

@MainActor
final class InventoryManager: ObservableObject {

    // MARK: - Published

    @Published private(set) var items: [InventoryItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String? = nil

    // MARK: - Singleton（也可直接用 @EnvironmentObject，这里保留 shared 供 MapTabView 调用）

    static let shared = InventoryManager()

    private let logger = Logger(subsystem: "com.earthlord", category: "InventoryManager")

    // MARK: - 计算属性

    /// 背包中所有物品的总件数（用于容量显示）
    var totalCount: Int { items.reduce(0) { $0 + $1.quantity } }
    let maxCapacity = 100

    // MARK: - Fetch

    func fetchInventory() async {
        logger.info("[Inventory] 开始拉取背包数据")
        isLoading = true
        errorMessage = nil
        do {
            let rows: [InventoryRow] = try await supabase
                .from("inventory_items")
                .select("item_id, quantity, obtained_at")
                .order("obtained_at", ascending: false)
                .execute()
                .value

            items = rows.compactMap { row in
                let slotId = "\(row.itemId)_slot"
                return InventoryItem(
                    id:             slotId,
                    itemId:         row.itemId,
                    quantity:       row.quantity,
                    qualityPercent: nil
                )
            }
            logger.info("[Inventory] 拉取成功，共 \(rows.count) 条记录")
        } catch {
            logger.error("[Inventory] 拉取失败: \(error.localizedDescription)")
            errorMessage = "加载背包失败：\(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Add Items（调用 RPC 累加数量，防止覆盖已有物品）
    // 使用 [String: AnyJSON] 替代自定义 Encodable 结构体：
    // AnyJSON 是 Supabase SDK 内置的 Codable & Sendable 类型，
    // 其 Encodable 协议实现由 SDK 定义，不存在 @MainActor 隔离推断。

    func addItems(_ list: [(itemId: String, quantity: Int)]) async throws {
        guard !list.isEmpty else { return }
        guard let userId = AuthManager.shared.currentUser?.id else {
            throw InventoryError.notAuthenticated
        }

        logger.info("[Inventory] 开始写入 \(list.count) 种物品")

        // 调用 upsert_inventory_item RPC：有则 +N，没有则新建
        for entry in list {
            let params: [String: AnyJSON] = [
                "p_user_id":  .string(userId.uuidString.lowercased()),
                "p_item_id":  .string(entry.itemId),
                "p_quantity": .integer(entry.quantity)
            ]
            do {
                try await supabase
                    .rpc("upsert_inventory_item", params: params)
                    .execute()
                logger.info("[Inventory] 写入完成 itemId=\(entry.itemId) qty=\(entry.quantity)")
            } catch {
                logger.error("[Inventory] 写入失败 itemId=\(entry.itemId): \(error.localizedDescription)")
                throw error
            }
        }

        // 写完后刷新本地缓存
        await fetchInventory()
    }

    // MARK: - Errors

    enum InventoryError: Error, LocalizedError {
        case notAuthenticated
        var errorDescription: String? { "请先登录后再操作背包" }
    }
}

// MARK: - Supabase Row Codable

private struct InventoryRow: Decodable {
    let itemId:     String
    let quantity:   Int
    let obtainedAt: String?

    enum CodingKeys: String, CodingKey {
        case itemId     = "item_id"
        case quantity
        case obtainedAt = "obtained_at"
    }
}
