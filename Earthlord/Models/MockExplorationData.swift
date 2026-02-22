//
//  MockExplorationData.swift
//  Earthlord
//
//  探索模块测试假数据
//  用途：在真实后端接入前，为探索相关 UI 提供可视化测试数据
//

import Foundation
import CoreLocation

// MARK: - POI 兴趣点

/// 兴趣点发现状态
enum POIStatus {
    case undiscovered   // 未发现（地图上仅显示迷雾/问号）
    case discovered     // 已发现
    case looted         // 已被搜空（物资耗尽）
}

/// 兴趣点数据结构
struct POI: Identifiable {
    let id: String
    let name: String            // 地点名称
    let type: String            // 地点类型（超市/医院/加油站等）
    let coordinate: CLLocationCoordinate2D
    let status: POIStatus
    let hasLoot: Bool           // 是否有可搜刮物资
    let description: String     // 地点描述
}

/// 测试用 POI 列表（5 个不同状态的兴趣点）
enum MockPOIData {

    static let list: [POI] = [

        // 1. 废弃超市 —— 已发现，有物资可搜刮
        POI(
            id: "poi_001",
            name: "废弃超市",
            type: "超市",
            coordinate: CLLocationCoordinate2D(latitude: 31.2310, longitude: 121.4750),
            status: .discovered,
            hasLoot: true,
            description: "一座大型连锁超市的废墟，货架部分倒塌，但仍有食品和日用品残留。"
        ),

        // 2. 医院废墟 —— 已发现，已被他人搜空
        POI(
            id: "poi_002",
            name: "医院废墟",
            type: "医院",
            coordinate: CLLocationCoordinate2D(latitude: 31.2280, longitude: 121.4780),
            status: .looted,
            hasLoot: false,
            description: "市区中心医院，曾是救援中心。药品和医疗器械已被之前的幸存者搜刮一空。"
        ),

        // 3. 加油站 —— 未发现（玩家尚未探索到此处）
        POI(
            id: "poi_003",
            name: "加油站",
            type: "加油站",
            coordinate: CLLocationCoordinate2D(latitude: 31.2260, longitude: 121.4720),
            status: .undiscovered,
            hasLoot: true,
            description: "???"
        ),

        // 4. 药店废墟 —— 已发现，有医疗物资残留
        POI(
            id: "poi_004",
            name: "药店废墟",
            type: "药店",
            coordinate: CLLocationCoordinate2D(latitude: 31.2295, longitude: 121.4760),
            status: .discovered,
            hasLoot: true,
            description: "一家社区药店，正面墙壁坍塌，但后储藏室完好，里面或许还有药品。"
        ),

        // 5. 工厂废墟 —— 未发现
        POI(
            id: "poi_005",
            name: "工厂废墟",
            type: "工厂",
            coordinate: CLLocationCoordinate2D(latitude: 31.2240, longitude: 121.4800),
            status: .undiscovered,
            hasLoot: true,
            description: "???"
        ),
    ]
}

// MARK: - 物品系统

/// 物品分类
enum ItemCategory: String {
    case water      = "水"
    case food       = "食物"
    case medical    = "医疗"
    case material   = "材料"
    case tool       = "工具"
}

/// 物品稀有度
enum ItemRarity: String {
    case common     = "普通"
    case uncommon   = "少见"
    case rare       = "稀有"
}

/// 物品定义（静态属性，全局唯一）
struct ItemDefinition: Identifiable {
    let id: String              // 物品 ID，与背包物品关联
    let displayName: String     // 中文名
    let category: ItemCategory  // 分类
    let weightKg: Double        // 单件重量（公斤）
    let volumeL: Double         // 单件体积（升）
    let rarity: ItemRarity      // 稀有度
}

/// 物品定义表（记录每种物品的基础属性）
enum MockItemDefinitions {

    static let table: [ItemDefinition] = [

        // ── 水类 ──────────────────────────────────────────
        ItemDefinition(id: "item_water_bottle",
                       displayName: "矿泉水",
                       category: .water,
                       weightKg: 0.5, volumeL: 0.5,
                       rarity: .common),

        // ── 食物 ──────────────────────────────────────────
        ItemDefinition(id: "item_canned_food",
                       displayName: "罐头食品",
                       category: .food,
                       weightKg: 0.4, volumeL: 0.3,
                       rarity: .common),

        ItemDefinition(id: "item_biscuit",
                       displayName: "饼干",
                       category: .food,
                       weightKg: 0.2, volumeL: 0.2,
                       rarity: .common),

        // ── 医疗 ──────────────────────────────────────────
        ItemDefinition(id: "item_bandage",
                       displayName: "绷带",
                       category: .medical,
                       weightKg: 0.1, volumeL: 0.1,
                       rarity: .common),

        ItemDefinition(id: "item_medicine",
                       displayName: "药品",
                       category: .medical,
                       weightKg: 0.2, volumeL: 0.1,
                       rarity: .uncommon),

        ItemDefinition(id: "item_first_aid",
                       displayName: "急救包",
                       category: .medical,
                       weightKg: 0.5, volumeL: 0.5,
                       rarity: .uncommon),

        ItemDefinition(id: "item_antibiotic",
                       displayName: "抗生素",
                       category: .medical,
                       weightKg: 0.1, volumeL: 0.05,
                       rarity: .rare),

        // ── 材料 ──────────────────────────────────────────
        ItemDefinition(id: "item_wood",
                       displayName: "木材",
                       category: .material,
                       weightKg: 2.0, volumeL: 3.0,
                       rarity: .common),

        ItemDefinition(id: "item_scrap_metal",
                       displayName: "废金属",
                       category: .material,
                       weightKg: 3.0, volumeL: 1.5,
                       rarity: .common),

        ItemDefinition(id: "item_generator_part",
                       displayName: "发电机零件",
                       category: .material,
                       weightKg: 4.0, volumeL: 2.0,
                       rarity: .rare),

        // ── 工具 ──────────────────────────────────────────
        ItemDefinition(id: "item_flashlight",
                       displayName: "手电筒",
                       category: .tool,
                       weightKg: 0.3, volumeL: 0.2,
                       rarity: .uncommon),

        ItemDefinition(id: "item_rope",
                       displayName: "绳子",
                       category: .tool,
                       weightKg: 0.5, volumeL: 0.4,
                       rarity: .common),

        ItemDefinition(id: "item_match",
                       displayName: "火柴",
                       category: .tool,
                       weightKg: 0.05, volumeL: 0.05,
                       rarity: .common),

        ItemDefinition(id: "item_tool_kit",
                       displayName: "工具箱",
                       category: .tool,
                       weightKg: 2.0, volumeL: 2.5,
                       rarity: .uncommon),

        ItemDefinition(id: "item_gas_mask",
                       displayName: "防毒面具",
                       category: .tool,
                       weightKg: 1.2, volumeL: 1.5,
                       rarity: .rare),
    ]

    /// 按 ID 快速查找物品定义
    static func find(_ id: String) -> ItemDefinition? {
        table.first { $0.id == id }
    }
}

// MARK: - 背包物品

/// 背包中的单条物品记录（含数量、品质等实例属性）
struct InventoryItem: Identifiable {
    let id: String                  // 背包槽 ID（唯一）
    let itemId: String              // 对应 ItemDefinition.id
    let quantity: Int               // 数量
    let qualityPercent: Int?        // 品质百分比（0-100），nil 表示该物品无品质属性

    /// 从定义表中取出名称（方便 UI 直接显示）
    var displayName: String {
        MockItemDefinitions.find(itemId)?.displayName ?? itemId
    }

    /// 计算总重量
    var totalWeightKg: Double {
        let unitWeight = MockItemDefinitions.find(itemId)?.weightKg ?? 0
        return unitWeight * Double(quantity)
    }
}

/// 测试用背包物品列表（6-8 种不同类型物品）
enum MockInventoryData {

    static let items: [InventoryItem] = [

        // 水类
        InventoryItem(id: "inv_001", itemId: "item_water_bottle",
                      quantity: 4, qualityPercent: nil),     // 矿泉水无品质概念

        // 食物
        InventoryItem(id: "inv_002", itemId: "item_canned_food",
                      quantity: 6, qualityPercent: 80),      // 品质 80%，部分生锈但可食用

        // 医疗
        InventoryItem(id: "inv_003", itemId: "item_bandage",
                      quantity: 3, qualityPercent: 100),     // 全新绷带
        InventoryItem(id: "inv_004", itemId: "item_medicine",
                      quantity: 2, qualityPercent: 60),      // 药品过期，品质下降

        // 材料
        InventoryItem(id: "inv_005", itemId: "item_wood",
                      quantity: 5, qualityPercent: nil),     // 原材料无品质
        InventoryItem(id: "inv_006", itemId: "item_scrap_metal",
                      quantity: 3, qualityPercent: nil),

        // 工具
        InventoryItem(id: "inv_007", itemId: "item_flashlight",
                      quantity: 1, qualityPercent: 45),      // 老旧手电筒，电池快耗尽
        InventoryItem(id: "inv_008", itemId: "item_rope",
                      quantity: 2, qualityPercent: 90),      // 结实的绳子
    ]

    /// 背包总重量（公斤）
    static var totalWeightKg: Double {
        items.reduce(0) { $0 + $1.totalWeightKg }
    }
}

// MARK: - 探索结果

/// 单次探索结果数据（由 ExplorationManager + RewardGenerator 生成真实数据）
struct ExplorationResult {
    // 行走距离（本次）
    let walkDistanceM:   Int

    // 奖励等级（由距离计算）
    let rewardTier: RewardTier

    // 探索时长（秒，UI 格式化为 MM:SS）
    let durationSeconds: Int

    // 获得物品列表（itemId → 数量）
    let lootedItems: [(itemId: String, quantity: Int)]

    /// 获得物品的可读字符串（如"绷带×2、矿泉水×1"）
    var lootSummary: String {
        lootedItems.compactMap { loot in
            guard let def = MockItemDefinitions.find(loot.itemId) else { return nil }
            return "\(def.displayName)×\(loot.quantity)"
        }.joined(separator: "、")
    }
}

/// 预览用示例数据（UI Preview 专用）
enum MockExplorationResult {

    static let sample = ExplorationResult(
        walkDistanceM:   750,
        rewardTier:      .silver,
        durationSeconds: 932,    // 15 分 32 秒
        lootedItems: [
            (itemId: "item_bandage",      quantity: 1),
            (itemId: "item_water_bottle", quantity: 1),
        ]
    )
}
