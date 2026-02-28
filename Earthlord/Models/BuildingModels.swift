//
//  BuildingModels.swift
//  Earthlord
//
//  建造系统数据模型：建筑模板、玩家建筑实例、状态枚举。
//

import Foundation
import SwiftUI

// MARK: - BuildingCategory

enum BuildingCategory: String, Codable, CaseIterable {
    case survival   = "survival"
    case storage    = "storage"
    case production = "production"
    case energy     = "energy"

    var displayName: String {
        switch self {
        case .survival:   return "生存"
        case .storage:    return "仓储"
        case .production: return "生产"
        case .energy:     return "能源"
        }
    }

    var icon: String {
        switch self {
        case .survival:   return "flame.fill"
        case .storage:    return "archivebox.fill"
        case .production: return "leaf.fill"
        case .energy:     return "bolt.fill"
        }
    }
}

// MARK: - BuildingStatus

enum BuildingStatus: String, Codable {
    case constructing = "constructing"
    case active       = "active"

    var displayName: String {
        switch self {
        case .constructing: return "建造中"
        case .active:       return "运行中"
        }
    }

    var color: Color {
        switch self {
        case .constructing: return .blue
        case .active:       return .green
        }
    }
}

// MARK: - BuildingTemplate（从 JSON 加载）

struct BuildingTemplate: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let category: BuildingCategory
    let level: Int
    let maxLevel: Int
    let buildTimeSeconds: Int
    let requiredResources: [String: Int]

    enum CodingKeys: String, CodingKey {
        case id, name, description, category, level
        case maxLevel          = "max_level"
        case buildTimeSeconds  = "build_time_seconds"
        case requiredResources = "required_resources"
    }
}

// MARK: - PlayerBuilding（对应 Supabase player_buildings 表）

struct PlayerBuilding: Codable, Identifiable {
    let id: String
    let userId: String
    let territoryId: String
    let templateId: String
    let buildingName: String
    var status: BuildingStatus
    var level: Int
    let locationLat: Double?
    let locationLon: Double?
    let buildStartedAt: Date
    let buildCompletedAt: Date?
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId          = "user_id"
        case territoryId     = "territory_id"
        case templateId      = "template_id"
        case buildingName    = "building_name"
        case status, level
        case locationLat     = "location_lat"
        case locationLon     = "location_lon"
        case buildStartedAt  = "build_started_at"
        case buildCompletedAt = "build_completed_at"
        case createdAt       = "created_at"
        case updatedAt       = "updated_at"
    }

    /// 建造是否已完成（基于 buildCompletedAt）
    var isConstructionComplete: Bool {
        guard let completedAt = buildCompletedAt else { return false }
        return Date() >= completedAt
    }
}

// MARK: - BuildingError

enum BuildingError: Error, LocalizedError {
    case insufficientResources(itemId: String, required: Int, available: Int)
    case maxBuildingsReached(limit: Int)
    case templateNotFound(templateId: String)
    case invalidStatus(current: BuildingStatus, expected: BuildingStatus)
    case maxLevelReached(maxLevel: Int)
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .insufficientResources(let itemId, let required, let available):
            return "资源不足：\(itemId) 需要 \(required)，现有 \(available)"
        case .maxBuildingsReached(let limit):
            return "建筑数量已达上限（\(limit) 栋）"
        case .templateNotFound(let templateId):
            return "找不到建筑模板：\(templateId)"
        case .invalidStatus(let current, let expected):
            return "建筑状态错误：当前 \(current.displayName)，需要 \(expected.displayName)"
        case .maxLevelReached(let maxLevel):
            return "已达最高等级（\(maxLevel) 级）"
        case .notAuthenticated:
            return "请先登录后再操作建筑"
        }
    }
}
