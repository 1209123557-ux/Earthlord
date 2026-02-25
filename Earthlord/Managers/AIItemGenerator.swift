//
//  AIItemGenerator.swift
//  Earthlord
//
//  通过 Supabase Edge Function 调用阿里云百炼 qwen-turbo，
//  根据 POI 类型和危险等级实时生成具有独特名称和背景故事的物品。
//

import Foundation
import Supabase
import OSLog

// MARK: - AI 物品模型

/// AI 生成的物品（由 Edge Function 返回）
struct AILootItem: Codable, Identifiable {
    var id: UUID = UUID()
    let name: String        // 独特名称（≤15字）
    let category: String    // 医疗 / 食物 / 工具 / 武器 / 材料
    let rarity: String      // common / uncommon / rare / epic / legendary
    let story: String       // 末日背景故事（50-100字）

    enum CodingKeys: String, CodingKey {
        case name, category, rarity, story
    }
}

// MARK: - 私有请求/响应模型

private struct AIItemRequest: Encodable {
    struct POIInfo: Encodable {
        let name: String
        let type: String
        let dangerLevel: Int
    }
    let poi: POIInfo
    let itemCount: Int
}

private struct AIItemResponse: Decodable {
    let success: Bool
    let items: [AILootItem]?
    let error: String?
}

// MARK: - AIItemGenerator

@MainActor
final class AIItemGenerator {

    static let shared = AIItemGenerator()
    private let logger = Logger(subsystem: "com.earthlord", category: "AIItemGenerator")

    // MARK: - 生成物品

    /// 调用 Edge Function 为指定 POI 生成 AI 物品。失败时返回 nil，调用方使用 fallbackItems。
    func generateItems(for poi: GamePOI, count: Int = 3) async -> [AILootItem]? {
        logger.info("[AIItemGenerator] 🤖 为 '\(poi.name)'（危险 \(poi.dangerLevel)/5）生成 \(count) 件物品")
        ExplorationLogger.shared.log("🤖 AI 生成物品: \(poi.name)")

        let request = AIItemRequest(
            poi: .init(
                name:        poi.name,
                type:        poi.poiType.rawValue,
                dangerLevel: poi.dangerLevel
            ),
            itemCount: count
        )

        do {
            let response: AIItemResponse = try await supabase.functions
                .invoke("generate-ai-item", options: .init(body: request))

            if response.success, let items = response.items, !items.isEmpty {
                logger.info("[AIItemGenerator] ✅ 生成成功，共 \(items.count) 件")
                ExplorationLogger.shared.log("✅ AI 生成 \(items.count) 件物品", type: .success)
                return items
            } else {
                logger.warning("[AIItemGenerator] ⚠️ AI 返回空物品，使用降级方案")
            }
        } catch {
            logger.error("[AIItemGenerator] ❌ 生成失败: \(error.localizedDescription)")
            ExplorationLogger.shared.log("⚠️ AI 生成失败，使用备用物品", type: .warning)
        }
        return nil
    }

    // MARK: - 降级备用物品

    /// AI 不可用时返回的本地预设物品，保证游戏流程不中断
    static func fallbackItems(for poi: GamePOI) -> [AILootItem] {
        switch poi.poiType {
        case .hospital, .pharmacy:
            return [
                AILootItem(name: "泛黄的绷带",   category: "医疗", rarity: "common",
                           story: "药柜深处找到的绷带，包装已经泛黄，但应该还能用。"),
                AILootItem(name: "不知名药片",   category: "医疗", rarity: "common",
                           story: "标签模糊，看不清楚是什么药。末日里，先收着吧。"),
            ]
        case .store:
            return [
                AILootItem(name: "压扁的罐头",   category: "食物", rarity: "common",
                           story: "货架倒塌时被压扁的罐头，内容物应该还没问题。"),
                AILootItem(name: "过期饼干",     category: "食物", rarity: "common",
                           story: "过期三个月，但末日里谁还在乎保质期。"),
            ]
        case .gasStation:
            return [
                AILootItem(name: "破旧打火机",   category: "工具", rarity: "common",
                           story: "收银台边找到的打火机，还有点气。"),
            ]
        case .restaurant, .cafe:
            return [
                AILootItem(name: "密封调料包",   category: "食物", rarity: "common",
                           story: "厨房角落的调料包，密封完好，至少能让食物有点味道。"),
            ]
        case .unknown:
            return [
                AILootItem(name: "杂物一堆",     category: "材料", rarity: "common",
                           story: "没什么特别用处的东西，也许有人需要。"),
            ]
        }
    }
}
