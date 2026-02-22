//
//  RewardGenerator.swift
//  Earthlord
//
//  纯静态逻辑：根据行走距离计算奖励等级和物品列表。
//  不依赖网络或数据库，随时可离线使用。
//

import Foundation

// MARK: - 奖励等级

enum RewardTier: String, Codable {
    case none    = "none"
    case bronze  = "bronze"
    case silver  = "silver"
    case gold    = "gold"
    case diamond = "diamond"

    /// 显示文字（含 emoji）
    var displayName: String {
        switch self {
        case .none:    return "无奖励"
        case .bronze:  return "🥉 铜级"
        case .silver:  return "🥈 银级"
        case .gold:    return "🥇 金级"
        case .diamond: return "💎 钻石级"
        }
    }

    /// 对应距离描述
    var distanceDescription: String {
        switch self {
        case .none:    return "行走距离不足 200 米"
        case .bronze:  return "行走 200 – 500 米"
        case .silver:  return "行走 500 – 1000 米"
        case .gold:    return "行走 1000 – 2000 米"
        case .diamond: return "行走超过 2000 米"
        }
    }

    /// 物品数量
    var itemCount: Int {
        switch self {
        case .none:    return 0
        case .bronze:  return 1
        case .silver:  return 2
        case .gold:    return 3
        case .diamond: return 5
        }
    }

    /// 各稀有度概率 (common, uncommon/rare, rare/epic)
    var rarityWeights: (common: Int, uncommon: Int, rare: Int) {
        switch self {
        case .none:    return (0,  0,  0)
        case .bronze:  return (90, 10, 0)
        case .silver:  return (70, 25, 5)
        case .gold:    return (50, 35, 15)
        case .diamond: return (30, 40, 30)
        }
    }
}

// MARK: - 物品池

private struct ItemPool {
    /// 普通物品
    static let common: [String] = [
        "item_water_bottle",
        "item_canned_food",
        "item_biscuit",
        "item_bandage",
        "item_match",
        "item_rope",
    ]

    /// 稀有物品
    static let uncommon: [String] = [
        "item_first_aid",
        "item_flashlight",
        "item_tool_kit",
        "item_rope",
    ]

    /// 史诗物品
    static let rare: [String] = [
        "item_antibiotic",
        "item_gas_mask",
        "item_generator_part",
    ]
}

// MARK: - RewardGenerator

enum RewardGenerator {

    // MARK: - 等级计算

    static func calculateTier(distanceM: Int) -> RewardTier {
        switch distanceM {
        case ..<200:      return .none
        case 200..<500:   return .bronze
        case 500..<1000:  return .silver
        case 1000..<2000: return .gold
        default:          return .diamond
        }
    }

    /// 返回下一奖励等级的名称及还差多少米，已是最高级时返回 nil
    static func nextTierInfo(distanceM: Int) -> (tierName: String, remaining: Int)? {
        switch distanceM {
        case ..<200:      return ("铜级", 200  - distanceM)
        case 200..<500:   return ("银级", 500  - distanceM)
        case 500..<1000:  return ("金级", 1000 - distanceM)
        case 1000..<2000: return ("钻石级", 2000 - distanceM)
        default:          return nil
        }
    }

    // MARK: - 物品生成

    /// 根据距离生成奖励物品列表。
    /// 同一 item_id 可能出现多次，由调用方合并数量。
    static func generateRewards(distanceM: Int) -> [(itemId: String, quantity: Int)] {
        let tier = calculateTier(distanceM: distanceM)
        guard tier != .none else { return [] }

        var result: [String: Int] = [:]

        for _ in 0..<tier.itemCount {
            let itemId = pickItemId(tier: tier)
            result[itemId, default: 0] += 1
        }

        return result.map { (itemId: $0.key, quantity: $0.value) }
                     .sorted { $0.itemId < $1.itemId }
    }

    // MARK: - 私有

    private static func pickItemId(tier: RewardTier) -> String {
        let weights = tier.rarityWeights
        let total   = weights.common + weights.uncommon + weights.rare
        let roll    = Int.random(in: 0..<total)

        let pool: [String]
        if roll < weights.common {
            pool = ItemPool.common
        } else if roll < weights.common + weights.uncommon {
            pool = ItemPool.uncommon
        } else {
            pool = ItemPool.rare
        }

        return pool.randomElement() ?? ItemPool.common[0]
    }
}
