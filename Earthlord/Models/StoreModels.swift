//
//  StoreModels.swift
//  Earthlord
//
//  商城物品定义：每个物资包的保底物品 + 随机物品
//

import Foundation

// MARK: - PackItem

/// 物资包中的单个物品条目
struct PackItem {
    let itemId: String
    let quantity: Int
    /// nil = 保底必得；0.0~1.0 = 随机概率
    let probability: Double?

    /// 是否保底
    var isGuaranteed: Bool { probability == nil }
}

// MARK: - PackDefinition

/// 单个物资包的完整定义
struct PackDefinition {
    let productId: String
    let displayName: String
    let price: String
    let tagline: String
    let items: [PackItem]

    /// 根据概率随机生成实际发放的物品列表
    func generateItems() -> [(itemId: String, quantity: Int)] {
        var result: [(itemId: String, quantity: Int)] = []
        for packItem in items {
            if let prob = packItem.probability {
                // 随机判断
                if Double.random(in: 0..<1) < prob {
                    result.append((packItem.itemId, packItem.quantity))
                }
            } else {
                // 保底必得
                result.append((packItem.itemId, packItem.quantity))
            }
        }
        return result
    }
}

// MARK: - PackCatalog

/// 全部物资包目录（按价格从低到高）
enum PackCatalog {

    static let all: [PackDefinition] = [survivor, explorer, lord, overlord]

    // ────────── 幸存者补给包 ¥6 ──────────
    static let survivor = PackDefinition(
        productId: "com.earthlord.supply.survivor",
        displayName: "幸存者补给包",
        price: "¥6",
        tagline: "新手入门，解决燃眉之急",
        items: [
            PackItem(itemId: "item_water_bottle",  quantity: 10, probability: nil),
            PackItem(itemId: "item_canned_food",   quantity: 8,  probability: nil),
            PackItem(itemId: "item_biscuit",       quantity: 6,  probability: nil),
            PackItem(itemId: "item_bandage",       quantity: 5,  probability: nil),
            PackItem(itemId: "item_match",         quantity: 4,  probability: nil),
            PackItem(itemId: "item_rope",          quantity: 3,  probability: 0.5),
        ]
    )

    // ────────── 探索者物资包 ¥18 ──────────
    static let explorer = PackDefinition(
        productId: "com.earthlord.supply.explorer",
        displayName: "探索者物资包",
        price: "¥18",
        tagline: "中度玩家，性价比之选",
        items: [
            PackItem(itemId: "item_water_bottle",  quantity: 25, probability: nil),
            PackItem(itemId: "item_canned_food",   quantity: 20, probability: nil),
            PackItem(itemId: "item_biscuit",       quantity: 15, probability: nil),
            PackItem(itemId: "item_bandage",       quantity: 12, probability: nil),
            PackItem(itemId: "item_match",         quantity: 8,  probability: nil),
            PackItem(itemId: "item_rope",          quantity: 8,  probability: nil),
            PackItem(itemId: "item_first_aid",     quantity: 2,  probability: 0.6),
        ]
    )

    // ────────── 领主物资包 ¥30 ──────────
    static let lord = PackDefinition(
        productId: "com.earthlord.supply.lord",
        displayName: "领主物资包",
        price: "¥30",
        tagline: "核心玩家，快速发展",
        items: [
            PackItem(itemId: "item_water_bottle",  quantity: 50, probability: nil),
            PackItem(itemId: "item_canned_food",   quantity: 40, probability: nil),
            PackItem(itemId: "item_biscuit",       quantity: 30, probability: nil),
            PackItem(itemId: "item_bandage",       quantity: 25, probability: nil),
            PackItem(itemId: "item_match",         quantity: 15, probability: nil),
            PackItem(itemId: "item_rope",          quantity: 15, probability: nil),
            PackItem(itemId: "item_first_aid",     quantity: 3,  probability: nil),
            PackItem(itemId: "item_flashlight",    quantity: 2,  probability: 0.7),
            PackItem(itemId: "item_tool_kit",      quantity: 1,  probability: 0.5),
            PackItem(itemId: "item_antibiotic",    quantity: 1,  probability: 0.3),
        ]
    )

    // ────────── 末日霸主包 ¥68 ──────────
    static let overlord = PackDefinition(
        productId: "com.earthlord.supply.overlord",
        displayName: "末日霸主包",
        price: "¥68",
        tagline: "重度玩家，一步到位",
        items: [
            PackItem(itemId: "item_water_bottle",  quantity: 100, probability: nil),
            PackItem(itemId: "item_canned_food",   quantity: 80,  probability: nil),
            PackItem(itemId: "item_biscuit",       quantity: 60,  probability: nil),
            PackItem(itemId: "item_bandage",       quantity: 50,  probability: nil),
            PackItem(itemId: "item_match",         quantity: 30,  probability: nil),
            PackItem(itemId: "item_rope",          quantity: 30,  probability: nil),
            PackItem(itemId: "item_first_aid",     quantity: 5,   probability: nil),
            PackItem(itemId: "item_flashlight",    quantity: 3,   probability: nil),
            PackItem(itemId: "item_tool_kit",      quantity: 2,   probability: 0.8),
            PackItem(itemId: "item_antibiotic",    quantity: 2,   probability: nil),
            PackItem(itemId: "item_gas_mask",      quantity: 1,   probability: 0.8),
            PackItem(itemId: "item_generator_part",quantity: 1,   probability: 0.2),
        ]
    )

    /// 根据 productId 查找定义
    static func find(_ productId: String) -> PackDefinition? {
        all.first { $0.productId == productId }
    }
}

// MARK: - SubscriptionTier

/// 订阅档位
enum SubscriptionTier: String {
    case none
    case monthly = "com.earthlord.sub.monthly"
    case yearly  = "com.earthlord.sub.yearly"

    var maxDailyExplorations: Int {
        switch self {
        case .none:    return 5
        case .monthly: return 10
        case .yearly:  return 999
        }
    }

    var maxBuildings: Int {
        switch self {
        case .none:    return 3
        case .monthly: return 10
        case .yearly:  return 20
        }
    }

    var maxTradeListings: Int {
        switch self {
        case .none:    return 3
        case .monthly: return 10
        case .yearly:  return 20
        }
    }

    var backpackBonus: Int {
        switch self {
        case .none:    return 0
        case .monthly: return 100
        case .yearly:  return 200
        }
    }

    var badgeText: String? {
        switch self {
        case .none:    return nil
        case .monthly: return "🥈"
        case .yearly:  return "👑"
        }
    }

    var tierName: String {
        switch self {
        case .none:    return "免费玩家"
        case .monthly: return "银色领主"
        case .yearly:  return "金色领主"
        }
    }
}

// MARK: - SubscriptionProduct

struct SubscriptionProduct {
    let id: String
    let name: String
    let price: String
    let period: String
    let saveLabel: String?
    let benefits: [String]
}

// MARK: - SubscriptionCatalog

enum SubscriptionCatalog {
    static let monthly = SubscriptionProduct(
        id: "com.earthlord.sub.monthly",
        name: "月度领主令",
        price: "¥18",
        period: "月",
        saveLabel: nil,
        benefits: ["每日探索10次", "建造上限10个", "挂单上限10条", "背包+100格", "每日基础补给", "🥈 银色领主徽章"]
    )

    static let yearly = SubscriptionProduct(
        id: "com.earthlord.sub.yearly",
        name: "年度领主令",
        price: "¥128",
        period: "年",
        saveLabel: "省¥88",
        benefits: ["每日探索无限次", "建造上限20个", "挂单上限20条", "背包+200格", "每日豪华补给", "👑 金色领主徽章"]
    )

    static let all: [SubscriptionProduct] = [monthly, yearly]
}

// MARK: - MailboxItem（邮箱行模型）

struct MailboxItem: Identifiable, Decodable {
    let id: String
    let itemId: String
    let quantity: Int
    let source: String
    let productId: String?
    let expiresAt: String?
    let claimedAt: String?
    let createdAt: String?

    var isClaimed: Bool { claimedAt != nil }

    var isExpired: Bool {
        guard let expiresAtStr = expiresAt,
              let date = ISO8601DateFormatter().date(from: expiresAtStr) else { return false }
        return date < Date()
    }

    enum CodingKeys: String, CodingKey {
        case id
        case itemId     = "item_id"
        case quantity
        case source
        case productId  = "product_id"
        case expiresAt  = "expires_at"
        case claimedAt  = "claimed_at"
        case createdAt  = "created_at"
    }
}
