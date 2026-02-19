//
//  TerritoryManager.swift
//  Earthlord
//
//  领地管理器 - 负责领地数据的上传和拉取
//

import Foundation
import CoreLocation
import Supabase

/// 领地管理器
/// 负责将领地数据上传到 Supabase，以及从数据库拉取领地列表
class TerritoryManager {

    // MARK: - 单例
    static let shared = TerritoryManager()
    private init() {}

    // MARK: - 数据库插入专用结构体

    /// 领地插入载荷（仅用于上传，字段对应数据库列名）
    private struct TerritoryInsert: Encodable {
        let userId: String
        let path: [[String: Double]]  // [{"lat": x, "lon": y}, ...]
        let polygon: String           // WKT 格式，PostGIS geography 类型
        let bboxMinLat: Double
        let bboxMaxLat: Double
        let bboxMinLon: Double
        let bboxMaxLon: Double
        let area: Double
        let pointCount: Int
        let startedAt: String         // ISO8601 字符串
        let isActive: Bool

        enum CodingKeys: String, CodingKey {
            case userId    = "user_id"
            case path
            case polygon
            case bboxMinLat = "bbox_min_lat"
            case bboxMaxLat = "bbox_max_lat"
            case bboxMinLon = "bbox_min_lon"
            case bboxMaxLon = "bbox_max_lon"
            case area
            case pointCount = "point_count"
            case startedAt  = "started_at"
            case isActive   = "is_active"
        }
    }

    // MARK: - 坐标转换

    /// 将坐标数组转为数据库 path 字段格式
    /// - Returns: [{"lat": x, "lon": y}, ...]（只含 lat/lon，无其他字段）
    func coordinatesToPathJSON(_ coordinates: [CLLocationCoordinate2D]) -> [[String: Double]] {
        return coordinates.map { coord in
            ["lat": coord.latitude, "lon": coord.longitude]
        }
    }

    /// 将坐标数组转为 WKT 多边形字符串（PostGIS 兼容格式）
    /// ⚠️ WKT 规范：经度(longitude)在前，纬度(latitude)在后
    /// ⚠️ 多边形必须闭合：最后一个点与第一个点相同
    func coordinatesToWKT(_ coordinates: [CLLocationCoordinate2D]) -> String {
        guard !coordinates.isEmpty else { return "SRID=4326;POLYGON(())" }

        var points = coordinates.map { coord in
            "\(coord.longitude) \(coord.latitude)"
        }

        if let first = points.first {
            points.append(first)
        }

        let coordString = points.joined(separator: ", ")
        return "SRID=4326;POLYGON((\(coordString)))"
    }

    /// 计算坐标集合的边界框
    func calculateBoundingBox(_ coordinates: [CLLocationCoordinate2D]) -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        let lats = coordinates.map { $0.latitude }
        let lons = coordinates.map { $0.longitude }
        return (
            minLat: lats.min() ?? 0,
            maxLat: lats.max() ?? 0,
            minLon: lons.min() ?? 0,
            maxLon: lons.max() ?? 0
        )
    }

    // MARK: - 上传领地

    /// 上传领地到 Supabase
    func uploadTerritory(
        coordinates: [CLLocationCoordinate2D],
        area: Double,
        startTime: Date
    ) async throws {
        guard let userId = AuthManager.shared.currentUser?.id else {
            throw TerritoryError.notLoggedIn
        }

        let pathJSON   = coordinatesToPathJSON(coordinates)
        let wktPolygon = coordinatesToWKT(coordinates)
        let bbox       = calculateBoundingBox(coordinates)

        let formatter = ISO8601DateFormatter()
        let startedAtString = formatter.string(from: startTime)

        let payload = TerritoryInsert(
            userId:     userId.uuidString,
            path:       pathJSON,
            polygon:    wktPolygon,
            bboxMinLat: bbox.minLat,
            bboxMaxLat: bbox.maxLat,
            bboxMinLon: bbox.minLon,
            bboxMaxLon: bbox.maxLon,
            area:       area,
            pointCount: coordinates.count,
            startedAt:  startedAtString,
            isActive:   true
        )

        do {
            try await supabase
                .from("territories")
                .insert(payload)
                .execute()

            let areaStr = String(format: "%.0f", area)
            print("✅ 领地上传成功，面积: \(areaStr)m²，点数: \(coordinates.count)")
            TerritoryLogger.shared.log("领地上传成功！面积: \(areaStr)m²", type: .success)
        } catch {
            TerritoryLogger.shared.log("领地上传失败: \(error.localizedDescription)", type: .error)
            throw error
        }
    }

    // MARK: - 拉取所有领地（地图展示用）

    /// 从 Supabase 拉取所有有效领地（is_active = true）
    func loadAllTerritories() async throws -> [Territory] {
        let territories: [Territory] = try await supabase
            .from("territories")
            .select()
            .eq("is_active", value: true)
            .execute()
            .value

        print("✅ 加载了 \(territories.count) 个领地")
        return territories
    }

    // MARK: - 拉取我的领地（领地 Tab 用）

    /// 从 Supabase 拉取当前用户的所有有效领地，按创建时间倒序
    func loadMyTerritories() async throws -> [Territory] {
        guard let userId = AuthManager.shared.currentUser?.id else {
            throw TerritoryError.notLoggedIn
        }

        let territories: [Territory] = try await supabase
            .from("territories")
            .select()
            .eq("user_id", value: userId.uuidString.lowercased())
            .eq("is_active", value: true)
            .order("created_at", ascending: false)
            .execute()
            .value

        print("✅ 加载了我的 \(territories.count) 个领地")
        return territories
    }

    // MARK: - 删除领地（软删除）

    /// 将指定领地标记为非活跃（is_active = false）
    func deleteTerritory(territoryId: String) async throws {
        guard AuthManager.shared.currentUser != nil else {
            throw TerritoryError.notLoggedIn
        }

        try await supabase
            .from("territories")
            .update(["is_active": false])
            .eq("id", value: territoryId)
            .execute()

        print("✅ 领地已删除: \(territoryId)")
        TerritoryLogger.shared.log("领地已删除", type: .info)
    }
}

// MARK: - 错误类型

enum TerritoryError: LocalizedError {
    case notLoggedIn

    var errorDescription: String? {
        switch self {
        case .notLoggedIn:
            return "请先登录后再操作领地"
        }
    }
}
