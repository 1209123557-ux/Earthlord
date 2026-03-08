import Foundation

// MARK: - 设备类型

enum DeviceType: String, Codable, CaseIterable {
    case radio         = "radio"
    case walkieTalkie  = "walkie_talkie"
    case campRadio     = "camp_radio"
    case satellite     = "satellite"

    var displayName: String {
        switch self {
        case .radio:        return "收音机"
        case .walkieTalkie: return "对讲机"
        case .campRadio:    return "营地电台"
        case .satellite:    return "卫星通讯"
        }
    }

    var iconName: String {
        switch self {
        case .radio:        return "radio"
        case .walkieTalkie: return "walkie.talkie.radio"
        case .campRadio:    return "antenna.radiowaves.left.and.right"
        case .satellite:    return "antenna.radiowaves.left.and.right.circle"
        }
    }

    var description: String {
        switch self {
        case .radio:        return "只能接收信号，无法发送消息"
        case .walkieTalkie: return "可在3公里范围内通讯"
        case .campRadio:    return "可在30公里范围内广播"
        case .satellite:    return "可在100公里+范围内联络"
        }
    }

    var range: Double {
        switch self {
        case .radio:        return Double.infinity
        case .walkieTalkie: return 3.0
        case .campRadio:    return 30.0
        case .satellite:    return 100.0
        }
    }

    var rangeText: String {
        switch self {
        case .radio:        return "无限制（仅接收）"
        case .walkieTalkie: return "3 公里"
        case .campRadio:    return "30 公里"
        case .satellite:    return "100+ 公里"
        }
    }

    var canSend: Bool { self != .radio }

    var unlockRequirement: String {
        switch self {
        case .radio, .walkieTalkie: return "默认拥有"
        case .campRadio:            return "需建造「营地电台」建筑"
        case .satellite:            return "需建造「通讯塔」建筑"
        }
    }
}

// MARK: - 设备模型

struct CommunicationDevice: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let deviceType: DeviceType
    var deviceLevel: Int
    var isUnlocked: Bool
    var isCurrent: Bool
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId      = "user_id"
        case deviceType  = "device_type"
        case deviceLevel = "device_level"
        case isUnlocked  = "is_unlocked"
        case isCurrent   = "is_current"
        case createdAt   = "created_at"
        case updatedAt   = "updated_at"
    }
}

// MARK: - 导航枚举

enum CommunicationSection: String, CaseIterable {
    case messages = "消息"
    case channels = "频道"
    case call     = "呼叫"
    case devices  = "设备"

    var iconName: String {
        switch self {
        case .messages: return "bell.fill"
        case .channels: return "dot.radiowaves.left.and.right"
        case .call:     return "phone.fill"
        case .devices:  return "gearshape.fill"
        }
    }
}

// MARK: - 频道类型

enum ChannelType: String, Codable, CaseIterable {
    case official  = "official"
    case `public`  = "public"
    case walkie    = "walkie"
    case camp      = "camp"
    case satellite = "satellite"

    var displayName: String {
        switch self {
        case .official:  return "官方频道"
        case .public:    return "公开频道"
        case .walkie:    return "对讲频道"
        case .camp:      return "营地频道"
        case .satellite: return "卫星频道"
        }
    }

    var iconName: String {
        switch self {
        case .official:  return "megaphone.fill"
        case .public:    return "globe"
        case .walkie:    return "phone.badge.waveform"
        case .camp:      return "antenna.radiowaves.left.and.right"
        case .satellite: return "antenna.radiowaves.left.and.right.circle"
        }
    }

    var description: String {
        switch self {
        case .official:  return "官方发布的公告频道，只能收听"
        case .public:    return "所有人可见并加入的公开频道"
        case .walkie:    return "基于对讲机的近距离频道"
        case .camp:      return "营地内部的通讯频道"
        case .satellite: return "覆盖范围最广的卫星频道"
        }
    }

    var canUserCreate: Bool { self != .official }
}

// MARK: - 频道模型

struct CommunicationChannel: Codable, Identifiable {
    let id: UUID
    let creatorId: UUID
    let channelType: ChannelType
    let channelCode: String
    let name: String
    let description: String?
    let isActive: Bool
    let memberCount: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case creatorId   = "creator_id"
        case channelType = "channel_type"
        case channelCode = "channel_code"
        case name
        case description
        case isActive    = "is_active"
        case memberCount = "member_count"
        case createdAt   = "created_at"
    }
}

// MARK: - 订阅模型

struct ChannelSubscription: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let channelId: UUID
    let isMuted: Bool
    let joinedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId    = "user_id"
        case channelId = "channel_id"
        case isMuted   = "is_muted"
        case joinedAt  = "joined_at"
    }
}

// MARK: - 组合模型（我的频道列表用）

struct SubscribedChannel: Identifiable {
    var id: UUID { channel.id }
    let channel: CommunicationChannel
    let subscription: ChannelSubscription
}

// MARK: - 位置点模型（解析 PostGIS POINT）

struct LocationPoint: Codable {
    let latitude: Double
    let longitude: Double

    // 从 PostGIS WKT 格式解析：POINT(经度 纬度)
    static func fromPostGIS(_ wkt: String) -> LocationPoint? {
        let pattern = #"POINT\(([0-9.-]+)\s+([0-9.-]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: wkt, range: NSRange(wkt.startIndex..., in: wkt)),
              let lonRange = Range(match.range(at: 1), in: wkt),
              let latRange = Range(match.range(at: 2), in: wkt),
              let longitude = Double(wkt[lonRange]),
              let latitude = Double(wkt[latRange]) else {
            return nil
        }
        return LocationPoint(latitude: latitude, longitude: longitude)
    }
}

// MARK: - 消息元数据

struct MessageMetadata: Codable {
    let deviceType: String?

    enum CodingKeys: String, CodingKey {
        case deviceType = "device_type"
    }
}

// MARK: - 频道消息模型

struct ChannelMessage: Codable, Identifiable {
    let messageId: UUID
    let channelId: UUID
    let senderId: UUID?
    let senderCallsign: String?
    let content: String
    let senderLocation: LocationPoint?
    let metadata: MessageMetadata?
    let senderDeviceType: DeviceType?
    let createdAt: Date

    var id: UUID { messageId }

    enum CodingKeys: String, CodingKey {
        case messageId      = "message_id"
        case channelId      = "channel_id"
        case senderId       = "sender_id"
        case senderCallsign = "sender_callsign"
        case content
        case senderLocation    = "sender_location"
        case metadata
        case senderDeviceType  = "sender_device_type"
        case createdAt         = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        messageId       = try container.decode(UUID.self, forKey: .messageId)
        channelId       = try container.decode(UUID.self, forKey: .channelId)
        senderId        = try container.decodeIfPresent(UUID.self, forKey: .senderId)
        senderCallsign  = try container.decodeIfPresent(String.self, forKey: .senderCallsign)
        content         = try container.decode(String.self, forKey: .content)
        metadata        = try container.decodeIfPresent(MessageMetadata.self, forKey: .metadata)

        // 解析位置（PostGIS 返回 WKT 字符串）
        if let wkt = try? container.decode(String.self, forKey: .senderLocation) {
            senderLocation = LocationPoint.fromPostGIS(wkt)
        } else {
            senderLocation = try container.decodeIfPresent(LocationPoint.self, forKey: .senderLocation)
        }

        // 解析日期（兼容多种格式）
        if let dateString = try? container.decode(String.self, forKey: .createdAt) {
            createdAt = ChannelMessage.parseDate(dateString) ?? Date()
        } else {
            createdAt = try container.decode(Date.self, forKey: .createdAt)
        }

        // 解析发送者设备类型（优先读专用字段，回退到 metadata）
        if let raw = try? container.decode(String.self, forKey: .senderDeviceType),
           let dt = DeviceType(rawValue: raw) {
            senderDeviceType = dt
        } else if let dtStr = metadata?.deviceType, let dt = DeviceType(rawValue: dtStr) {
            senderDeviceType = dt
        } else {
            senderDeviceType = nil
        }
    }

    private static func parseDate(_ string: String) -> Date? {
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss"
        ]
        for format in formats {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            if let date = formatter.date(from: string) { return date }
        }
        return nil
    }

    var timeAgo: String {
        let interval = Date().timeIntervalSince(createdAt)
        if interval < 60 { return "刚刚" }
        if interval < 3600 { return "\(Int(interval / 60))分钟前" }
        if interval < 86400 { return "\(Int(interval / 3600))小时前" }
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f.string(from: createdAt)
    }

    var deviceType: String? { metadata?.deviceType }
}
