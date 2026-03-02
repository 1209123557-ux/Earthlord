//
//  TradeModels.swift
//  Earthlord
//
//  交易系统数据模型：挂单、历史记录、物品条目、状态枚举、错误类型
//

import Foundation

// MARK: - TradeItemEntry（与 DB JSONB 格式对应）

struct TradeItemEntry: Codable, Hashable {
    let itemId: String
    let quantity: Int

    enum CodingKeys: String, CodingKey {
        case itemId   = "item_id"
        case quantity
    }
}

// MARK: - TradeStatus

enum TradeStatus: String, Codable {
    case active    = "active"
    case completed = "completed"
    case cancelled = "cancelled"
    case expired   = "expired"

    var displayName: String {
        switch self {
        case .active:    return "等待中"
        case .completed: return "已完成"
        case .cancelled: return "已取消"
        case .expired:   return "已过期"
        }
    }
}

// MARK: - TradeOffer（对应 trade_offers 表）

struct TradeOffer: Codable, Identifiable {
    let id: String
    let ownerId: String
    let ownerUsername: String?
    let offeringItems: [TradeItemEntry]
    let requestingItems: [TradeItemEntry]
    var status: TradeStatus
    let message: String?
    let createdAt: Date
    let expiresAt: Date
    let completedAt: Date?
    let completedByUserId: String?
    let completedByUsername: String?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId             = "owner_id"
        case ownerUsername       = "owner_username"
        case offeringItems       = "offering_items"
        case requestingItems     = "requesting_items"
        case status, message
        case createdAt           = "created_at"
        case expiresAt           = "expires_at"
        case completedAt         = "completed_at"
        case completedByUserId   = "completed_by_user_id"
        case completedByUsername = "completed_by_username"
    }

    /// 是否已超过过期时间（客户端判断，UI 展示用）
    var isExpired: Bool { expiresAt <= Date() }

    /// 真正可接受：状态 active 且未过期
    var isActive: Bool { status == .active && !isExpired }

    /// 格式化剩余时间
    var formattedExpiry: String {
        let remaining = expiresAt.timeIntervalSinceNow
        if remaining <= 0 { return "已过期" }
        let h = Int(remaining) / 3600
        let m = (Int(remaining) % 3600) / 60
        if h > 0 { return "\(h)小时\(m)分后过期" }
        return "\(m)分钟后过期"
    }
}

// MARK: - TradeItemsExchanged（trade_history.items_exchanged 字段）

struct TradeItemsExchanged: Codable {
    let offeringItems: [TradeItemEntry]
    let requestingItems: [TradeItemEntry]

    enum CodingKeys: String, CodingKey {
        case offeringItems   = "offering_items"
        case requestingItems = "requesting_items"
    }
}

// MARK: - TradeHistory（对应 trade_history 表）

struct TradeHistory: Codable, Identifiable {
    let id: String
    let offerId: String?
    let sellerId: String
    let sellerUsername: String?
    let buyerId: String
    let buyerUsername: String?
    let itemsExchanged: TradeItemsExchanged
    let completedAt: Date
    var sellerRating: Int?
    var buyerRating: Int?
    var sellerComment: String?
    var buyerComment: String?

    enum CodingKeys: String, CodingKey {
        case id
        case offerId        = "offer_id"
        case sellerId       = "seller_id"
        case sellerUsername = "seller_username"
        case buyerId        = "buyer_id"
        case buyerUsername  = "buyer_username"
        case itemsExchanged = "items_exchanged"
        case completedAt    = "completed_at"
        case sellerRating   = "seller_rating"
        case buyerRating    = "buyer_rating"
        case sellerComment  = "seller_comment"
        case buyerComment   = "buyer_comment"
    }
}

// MARK: - TradeError

enum TradeError: LocalizedError {
    case notAuthenticated
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:     return "请先登录"
        case .serverError(let msg): return msg
        }
    }
}
