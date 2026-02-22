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

@MainActor
final class InventoryManager: ObservableObject {

    // MARK: - Published

    @Published private(set) var items: [InventoryItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String? = nil

    // MARK: - Singleton（也可直接用 @EnvironmentObject，这里保留 shared 供 MapTabView 调用）

    static let shared = InventoryManager()

    // MARK: - 计算属性

    /// 背包中所有物品的总件数（用于容量显示）
    var totalCount: Int { items.reduce(0) { $0 + $1.quantity } }
    let maxCapacity = 100

    // MARK: - Fetch

    func fetchInventory() async {
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
        } catch {
            errorMessage = "加载背包失败：\(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Add Items（调用 RPC 累加数量，防止覆盖已有物品）

    func addItems(_ list: [(itemId: String, quantity: Int)]) async throws {
        guard !list.isEmpty else { return }
        guard let userId = AuthManager.shared.currentUser?.id else {
            throw InventoryError.notAuthenticated
        }

        // 调用 upsert_inventory_item RPC：有则 +N，没有则新建
        for entry in list {
            try await supabase
                .rpc("upsert_inventory_item", params: UpsertInventoryParams(
                    p_user_id:  userId.uuidString.lowercased(),
                    p_item_id:  entry.itemId,
                    p_quantity: entry.quantity
                ))
                .execute()
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

// MARK: - RPC Params（文件级声明，避免 @MainActor 隔离与 Encodable 冲突）

private struct UpsertInventoryParams: Encodable, Sendable {
    let p_user_id:  String
    let p_item_id:  String
    let p_quantity: Int
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
