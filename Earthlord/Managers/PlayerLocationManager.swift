//
//  PlayerLocationManager.swift
//  Earthlord
//
//  负责将玩家位置定期上报到 Supabase player_locations 表，
//  并查询附近 1km 内的在线玩家数量，以决定 POI 显示上限。
//

import Foundation
import CoreLocation
import Combine
import OSLog
import Supabase

@MainActor
final class PlayerLocationManager: ObservableObject {

    static let shared = PlayerLocationManager()

    private let logger = Logger(subsystem: "com.earthlord", category: "PlayerLocationManager")

    // MARK: - 密度等级

    enum PlayerDensity {
        case solo    // 0 人
        case low     // 1–5 人
        case medium  // 6–20 人
        case high    // 20+ 人

        /// 允许显示的最大 POI 数量
        var poiLimit: Int {
            switch self {
            case .solo:   return 1
            case .low:    return 3
            case .medium: return 6
            case .high:   return 20
            }
        }

        /// 探索横幅展示名称
        var displayName: String {
            switch self {
            case .solo:   return "独行者"
            case .low:    return "低密度"
            case .medium: return "中密度"
            case .high:   return "高密度"
            }
        }

        static func from(_ count: Int) -> PlayerDensity {
            switch count {
            case 0:      return .solo
            case 1...5:  return .low
            case 6...20: return .medium
            default:     return .high
            }
        }
    }

    // MARK: - Published

    @Published private(set) var nearbyPlayerCount: Int = 0
    @Published private(set) var densityLevel: PlayerDensity = .solo

    // MARK: - 私有

    private var lastUploadCoord: CLLocationCoordinate2D?
    private var lastUploadTime:  Date?

    private let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private init() {}

    // MARK: - 上报位置（upsert）

    func reportLocation(_ coord: CLLocationCoordinate2D) async {
        guard let userId = supabase.auth.currentUser?.id.uuidString.lowercased() else {
            logger.warning("[PlayerLocation] 未登录，跳过上报")
            return
        }

        let now = Date()
        let payload: [String: AnyJSON] = [
            "user_id":    .string(userId),
            "latitude":   .double(coord.latitude),
            "longitude":  .double(coord.longitude),
            "updated_at": .string(isoFormatter.string(from: now)),
            "is_online":  .bool(true)
        ]

        do {
            try await supabase
                .from("player_locations")
                .upsert(payload, onConflict: "user_id")
                .execute()
            lastUploadCoord = coord
            lastUploadTime  = now
            logger.info("[PlayerLocation] 📡 上报位置成功")
        } catch {
            logger.warning("[PlayerLocation] 上报失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 查询附近玩家数（bounding box 近似 1km）

    func refreshNearbyCount(at coord: CLLocationCoordinate2D) async {
        guard let userId = supabase.auth.currentUser?.id.uuidString.lowercased() else { return }

        // 1° 纬度 ≈ 111km → 1km ≈ 0.009°（对中国纬度精度足够）
        let delta   = 0.009
        let lat     = coord.latitude
        let lng     = coord.longitude
        let fiveMinAgoStr = isoFormatter.string(from: Date().addingTimeInterval(-300))

        do {
            let rows: [PlayerIdOnly] = try await supabase
                .from("player_locations")
                .select("user_id")
                .eq("is_online", value: true)
                .gte("updated_at", value: fiveMinAgoStr)
                .neq("user_id", value: userId)
                .gte("latitude",  value: "\(lat - delta)")
                .lte("latitude",  value: "\(lat + delta)")
                .gte("longitude", value: "\(lng - delta)")
                .lte("longitude", value: "\(lng + delta)")
                .execute()
                .value

            nearbyPlayerCount = rows.count
            densityLevel      = .from(rows.count)
            let displayName = densityLevel.displayName
            let poiLimit    = densityLevel.poiLimit
            logger.info("[PlayerLocation] 📊 附近 \(rows.count) 名玩家 → \(displayName)，POI 上限 \(poiLimit)")
        } catch {
            // 查询失败时保留上次结果，不影响游戏流程
            logger.warning("[PlayerLocation] 查询附近玩家失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 标记离线

    func markOffline() async {
        guard let userId = supabase.auth.currentUser?.id.uuidString.lowercased() else { return }

        let payload: [String: AnyJSON] = [
            "is_online":  .bool(false),
            "updated_at": .string(isoFormatter.string(from: Date()))
        ]

        do {
            try await supabase
                .from("player_locations")
                .update(payload)
                .eq("user_id", value: userId)
                .execute()
            logger.info("[PlayerLocation] 已标记离线")
        } catch {
            logger.warning("[PlayerLocation] 标记离线失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 智能上报（30s 计时 或 移动 >50m）

    func reportIfNeeded(_ coord: CLLocationCoordinate2D) async {
        let now = Date()

        // 30 秒触发
        let should30s = lastUploadTime.map { now.timeIntervalSince($0) >= 30 } ?? false

        // 50 米触发
        var should50m = false
        if let last = lastUploadCoord {
            let dist = CLLocation(latitude: coord.latitude,  longitude: coord.longitude)
                .distance(from: CLLocation(latitude: last.latitude, longitude: last.longitude))
            should50m = dist >= 50
        }

        guard should30s || should50m else { return }
        logger.debug("[PlayerLocation] 触发上报：30s=\(should30s) 50m=\(should50m)")
        await reportLocation(coord)
    }

    // MARK: - 私有解码模型

    private struct PlayerIdOnly: Decodable {
        let user_id: String
    }
}
