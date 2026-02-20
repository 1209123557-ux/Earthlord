//
//  CollisionModels.swift
//  Earthlord
//
//  碰撞检测相关枚举和结构体
//

import Foundation

// MARK: - 预警级别
enum WarningLevel: Int {
    case safe      = 0   // 安全（>100m）
    case caution   = 1   // 注意（50-100m）- 黄色横幅
    case warning   = 2   // 警告（25-50m）- 橙色横幅
    case danger    = 3   // 危险（<25m）- 红色横幅
    case violation = 4   // 违规（已碰撞）- 红色横幅 + 停止圈地

    var description: String {
        switch self {
        case .safe:      return "安全"
        case .caution:   return "注意"
        case .warning:   return "警告"
        case .danger:    return "危险"
        case .violation: return "违规"
        }
    }
}

// MARK: - 碰撞类型
enum CollisionType {
    case pointInTerritory    // 点在他人领地内
    case pathCrossTerritory  // 路径穿越他人领地边界
    case selfIntersection    // 自相交（Day 17 已有）
}

// MARK: - 碰撞检测结果
struct CollisionResult {
    let hasCollision: Bool
    let collisionType: CollisionType?
    let message: String?
    let closestDistance: Double?     // 距最近领地的距离（米）
    let warningLevel: WarningLevel

    /// 便捷构造器：安全状态
    static var safe: CollisionResult {
        CollisionResult(
            hasCollision: false,
            collisionType: nil,
            message: nil,
            closestDistance: nil,
            warningLevel: .safe
        )
    }
}
