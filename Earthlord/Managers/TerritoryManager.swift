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

    // MARK: - 领地缓存（供碰撞检测使用）
    /// loadAllTerritories() 调用后自动更新，碰撞检测方法直接读此属性
    private(set) var territories: [Territory] = []

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

        self.territories = territories   // 缓存供碰撞检测使用
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

    // MARK: - 碰撞检测算法

    /// 射线法判断点是否在多边形内
    func isPointInPolygon(point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
        guard polygon.count >= 3 else { return false }

        var inside = false
        let x = point.longitude
        let y = point.latitude

        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let xi = polygon[i].longitude
            let yi = polygon[i].latitude
            let xj = polygon[j].longitude
            let yj = polygon[j].latitude

            let intersect = ((yi > y) != (yj > y)) &&
                           (x < (xj - xi) * (y - yi) / (yj - yi) + xi)
            if intersect { inside.toggle() }
            j = i
        }

        return inside
    }

    /// 检查起始点是否在他人领地内
    func checkPointCollision(location: CLLocationCoordinate2D, currentUserId: String) -> CollisionResult {
        let others = territories.filter { $0.userId.lowercased() != currentUserId.lowercased() }
        guard !others.isEmpty else { return .safe }

        for territory in others {
            let polygon = territory.toCoordinates()
            guard polygon.count >= 3 else { continue }

            if isPointInPolygon(point: location, polygon: polygon) {
                TerritoryLogger.shared.log("起点碰撞：位于他人领地内", type: .error)
                return CollisionResult(
                    hasCollision: true,
                    collisionType: .pointInTerritory,
                    message: "不能在他人领地内开始圈地！",
                    closestDistance: 0,
                    warningLevel: .violation
                )
            }
        }

        return .safe
    }

    /// 判断两条线段是否相交（CCW 算法）
    private func segmentsIntersectForCollision(
        p1: CLLocationCoordinate2D, p2: CLLocationCoordinate2D,
        p3: CLLocationCoordinate2D, p4: CLLocationCoordinate2D
    ) -> Bool {
        func ccw(_ A: CLLocationCoordinate2D, _ B: CLLocationCoordinate2D, _ C: CLLocationCoordinate2D) -> Bool {
            return (C.latitude - A.latitude) * (B.longitude - A.longitude) >
                   (B.latitude - A.latitude) * (C.longitude - A.longitude)
        }
        return ccw(p1, p3, p4) != ccw(p2, p3, p4) && ccw(p1, p2, p3) != ccw(p1, p2, p4)
    }

    /// 检查路径是否穿越他人领地边界
    func checkPathCrossTerritory(path: [CLLocationCoordinate2D], currentUserId: String) -> CollisionResult {
        guard path.count >= 2 else { return .safe }

        let others = territories.filter { $0.userId.lowercased() != currentUserId.lowercased() }
        guard !others.isEmpty else { return .safe }

        for i in 0..<(path.count - 1) {
            let pathStart = path[i]
            let pathEnd   = path[i + 1]

            for territory in others {
                let polygon = territory.toCoordinates()
                guard polygon.count >= 3 else { continue }

                // 检查路径段与领地每条边的相交
                for j in 0..<polygon.count {
                    let bStart = polygon[j]
                    let bEnd   = polygon[(j + 1) % polygon.count]

                    if segmentsIntersectForCollision(p1: pathStart, p2: pathEnd, p3: bStart, p4: bEnd) {
                        TerritoryLogger.shared.log("路径碰撞：轨迹穿越他人领地边界", type: .error)
                        return CollisionResult(
                            hasCollision: true,
                            collisionType: .pathCrossTerritory,
                            message: "轨迹不能穿越他人领地！",
                            closestDistance: 0,
                            warningLevel: .violation
                        )
                    }
                }

                // 检查路径终点是否进入领地内
                if isPointInPolygon(point: pathEnd, polygon: polygon) {
                    TerritoryLogger.shared.log("路径碰撞：轨迹点进入他人领地", type: .error)
                    return CollisionResult(
                        hasCollision: true,
                        collisionType: .pointInTerritory,
                        message: "轨迹不能进入他人领地！",
                        closestDistance: 0,
                        warningLevel: .violation
                    )
                }
            }
        }

        return .safe
    }

    /// 计算当前位置到他人所有领地顶点的最近距离（米）
    func calculateMinDistanceToTerritories(location: CLLocationCoordinate2D, currentUserId: String) -> Double {
        let others = territories.filter { $0.userId.lowercased() != currentUserId.lowercased() }
        guard !others.isEmpty else { return .infinity }

        let current = CLLocation(latitude: location.latitude, longitude: location.longitude)
        var minDist = Double.infinity

        for territory in others {
            for vertex in territory.toCoordinates() {
                let d = current.distance(from: CLLocation(latitude: vertex.latitude, longitude: vertex.longitude))
                if d < minDist { minDist = d }
            }
        }

        return minDist
    }

    /// 综合碰撞检测（主方法）：先检碰撞，再计算距离预警
    func checkPathCollisionComprehensive(path: [CLLocationCoordinate2D], currentUserId: String) -> CollisionResult {
        guard path.count >= 2 else { return .safe }

        // 1. 路径穿越/进入检测
        let crossResult = checkPathCrossTerritory(path: path, currentUserId: currentUserId)
        if crossResult.hasCollision { return crossResult }

        // 2. 距离预警
        guard let lastPoint = path.last else { return .safe }
        let minDist = calculateMinDistanceToTerritories(location: lastPoint, currentUserId: currentUserId)

        let warningLevel: WarningLevel
        let message: String?

        switch minDist {
        case 100...:
            warningLevel = .safe;    message = nil
        case 50..<100:
            warningLevel = .caution; message = "注意：距离他人领地 \(Int(minDist))m"
        case 25..<50:
            warningLevel = .warning; message = "警告：正在靠近他人领地（\(Int(minDist))m）"
        default:
            warningLevel = .danger;  message = "危险：即将进入他人领地！（\(Int(minDist))m）"
        }

        if warningLevel != .safe {
            TerritoryLogger.shared.log("距离预警：\(warningLevel.description)，距离 \(Int(minDist))m", type: .warning)
        }

        return CollisionResult(
            hasCollision: false,
            collisionType: nil,
            message: message,
            closestDistance: minDist,
            warningLevel: warningLevel
        )
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
