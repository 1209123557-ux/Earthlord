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
        case .walkie:    return "walkie.talkie.radio"
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
