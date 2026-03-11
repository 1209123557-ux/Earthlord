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

    /// 基础容量 100 + 订阅加成
    var maxCapacity: Int { 100 + SubscriptionManager.shared.tier.backpackBonus }

    // MARK: - Fetch

    func fetchInventory() async {
        logger.info("[Inventory] 开始拉取背包数据")
        ExplorationLogger.shared.log("加载背包")
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
            ExplorationLogger.shared.log("背包加载完成: \(rows.count) 个物品", type: .success)
        } catch {
            logger.error("[Inventory] 拉取失败: \(error.localizedDescription)")
            ExplorationLogger.shared.log("背包加载失败: \(error.localizedDescription)", type: .error)
            errorMessage = "加载背包失败：\(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Add Items（调用 RPC 累加数量，防止覆盖已有物品）
    // 使用 [String: AnyJSON] 替代自定义 Encodable 结构体：
    // AnyJSON 是 Supabase SDK 内置的 Codable & Sendable 类型，
    // 其 Encodable 协议实现由 SDK 定义，不存在 @MainActor 隔离推断。

    func addItems(_ list: [(itemId: String, quantity: Int)], reason: String = "探索") async throws {
        guard !list.isEmpty else { return }
        guard let userId = AuthManager.shared.currentUser?.id else {
            throw InventoryError.notAuthenticated
        }

        logger.info("[Inventory] 开始写入 \(list.count) 种物品，原因：\(reason)")
        ExplorationLogger.shared.log("🎒 添加 \(list.count) 个物品到背包")

        // 调用 upsert_inventory_item RPC：有则 +N，没有则新建，同时写流水日志
        for entry in list {
            let params: [String: AnyJSON] = [
                "p_user_id":  .string(userId.uuidString.lowercased()),
                "p_item_id":  .string(entry.itemId),
                "p_quantity": .integer(entry.quantity),
                "p_reason":   .string(reason)
            ]
            do {
                try await supabase
                    .rpc("upsert_inventory_item", params: params)
                    .execute()
                logger.info("[Inventory] 写入完成 itemId=\(entry.itemId) qty=\(entry.quantity)")
                ExplorationLogger.shared.log("新物品添加: \(entry.itemId) x\(entry.quantity)", type: .success)
            } catch {
                logger.error("[Inventory] 写入失败 itemId=\(entry.itemId): \(error.localizedDescription)")
                ExplorationLogger.shared.log("❌ 物品写入失败 \(entry.itemId): \(error.localizedDescription)", type: .error)
                throw error
            }
        }

        // 写完后刷新本地缓存
        await fetchInventory()
    }

    // MARK: - Remove Items（调用 remove_inventory_item RPC 原子扣减，同时写流水日志）

    func removeItem(_ itemId: String, quantity: Int, reason: String = "消耗") async throws {
        guard let userId = AuthManager.shared.currentUser?.id else {
            throw InventoryError.notAuthenticated
        }
        let params: [String: AnyJSON] = [
            "p_user_id":  .string(userId.uuidString.lowercased()),
            "p_item_id":  .string(itemId),
            "p_quantity": .integer(quantity),
            "p_reason":   .string(reason)
        ]
        try await supabase
            .rpc("remove_inventory_item", params: params)
            .execute()
        logger.info("[Inventory] 扣减完成 itemId=\(itemId) qty=\(quantity) 原因：\(reason)")
        await fetchInventory()
    }

    // MARK: - Save AI Items（写入 ai_inventory 表）

    func saveAIItems(_ items: [AILootItem], poiName: String) async throws {
        guard !items.isEmpty else { return }
        guard let userId = AuthManager.shared.currentUser?.id else {
            throw InventoryError.notAuthenticated
        }

        logger.info("[Inventory] 写入 \(items.count) 件 AI 物品到 ai_inventory")

        for item in items {
            let params: [String: AnyJSON] = [
                "user_id":  .string(userId.uuidString.lowercased()),
                "name":     .string(item.name),
                "category": .string(item.category),
                "rarity":   .string(item.rarity),
                "story":    .string(item.story),
                "poi_name": .string(poiName)
            ]
            try await supabase
                .from("ai_inventory")
                .insert(params)
                .execute()
        }

        logger.info("[Inventory] ✅ AI 物品写入完成")
        ExplorationLogger.shared.log("🎒 AI 物品已保存（\(items.count) 件）", type: .success)

        // 把 AI 物品映射到标准 item_id，合并数量后写入实际背包
        var itemCounts: [String: Int] = [:]
        for item in items {
            let stdId = Self.mapAIItemToStandardId(item)
            itemCounts[stdId, default: 0] += 1
        }
        let list = itemCounts.map { (itemId: $0.key, quantity: $0.value) }
        try await addItems(list, reason: "搜刮：\(poiName)")
    }

    /// 将 AI 生成物品的 category + rarity 映射到标准 item_id
    private static func mapAIItemToStandardId(_ item: AILootItem) -> String {
        switch item.category {
        case "医疗":
            switch item.rarity {
            case "common":    return "item_bandage"
            case "uncommon":  return "item_medicine"
            case "rare":      return "item_first_aid"
            default:          return "item_antibiotic"
            }
        case "食物":
            return item.rarity == "common" ? "item_biscuit" : "item_canned_food"
        case "工具":
            switch item.rarity {
            case "common":    return "item_match"
            case "uncommon":  return "item_flashlight"
            default:          return "item_tool_kit"
            }
        case "材料":
            switch item.rarity {
            case "common":    return "item_wood"
            case "uncommon":  return "item_rope"
            default:          return "item_scrap_metal"
            }
        default:              return "item_biscuit"
        }
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
