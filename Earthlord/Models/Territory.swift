//
//  Territory.swift
//  Earthlord
//
//  领地数据模型 - 对应数据库 territories 表
//

import Foundation
import CoreLocation

/// 领地数据模型，用于解析数据库返回的领地记录
struct Territory: Codable, Identifiable {
    let id: String
    let userId: String
    let name: String?             // ⚠️ 可选，数据库允许为空
    let path: [[String: Double]]  // 格式：[{"lat": x, "lon": y}, ...]
    let area: Double
    let pointCount: Int?          // 可选，防止旧数据解码失败
    let isActive: Bool?           // 可选，防止旧数据解码失败
    let startedAt: String?        // ISO8601 字符串，开始圈地时间
    let completedAt: String?      // ISO8601 字符串，完成圈地时间（暂未使用）
    let createdAt: String?        // ISO8601 字符串，数据库插入时间

    enum CodingKeys: String, CodingKey {
        case id
        case userId     = "user_id"
        case name
        case path
        case area
        case pointCount = "point_count"
        case isActive   = "is_active"
        case startedAt  = "started_at"
        case completedAt = "completed_at"
        case createdAt  = "created_at"
    }

    // MARK: - 将 path JSON 转换为 CLLocationCoordinate2D 数组
    func toCoordinates() -> [CLLocationCoordinate2D] {
        return path.compactMap { point in
            guard let lat = point["lat"], let lon = point["lon"] else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }

    // MARK: - 显示名称（无名称时用 ID 前6位）
    var displayName: String {
        if let name = name, !name.isEmpty {
            return name
        }
        return "领地 #\(id.prefix(6).uppercased())"
    }

    // MARK: - 格式化面积
    var formattedArea: String {
        if area >= 1_000_000 {
            return String(format: "%.2f km²", area / 1_000_000)
        } else {
            return String(format: "%.0f m²", area)
        }
    }

    // MARK: - 格式化日期（优先用 createdAt，其次 startedAt）
    var formattedDate: String {
        let rawStr = createdAt ?? startedAt ?? ""
        guard !rawStr.isEmpty else { return "未知时间" }

        // 尝试 ISO8601 解析（带时区/不带时区两种格式）
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = formatter.date(from: rawStr)

        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: rawStr)
        }

        guard let parsedDate = date else { return String(rawStr.prefix(10)) }

        let display = DateFormatter()
        display.dateFormat = "yyyy-MM-dd HH:mm"
        display.locale = Locale(identifier: "zh_CN")
        return display.string(from: parsedDate)
    }
}
