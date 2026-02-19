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

    enum CodingKeys: String, CodingKey {
        case id
        case userId    = "user_id"
        case name
        case path
        case area
        case pointCount = "point_count"
        case isActive   = "is_active"
    }

    /// 将 path JSON 转换为 CLLocationCoordinate2D 数组
    func toCoordinates() -> [CLLocationCoordinate2D] {
        return path.compactMap { point in
            guard let lat = point["lat"], let lon = point["lon"] else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }
}
