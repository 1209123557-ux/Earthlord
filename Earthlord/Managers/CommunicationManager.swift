import Foundation
import Combine
import CoreLocation
import Supabase
import OSLog

@MainActor
final class CommunicationManager: ObservableObject {

    static let shared = CommunicationManager()

    private let logger = Logger(subsystem: "com.earthlord", category: "CommunicationManager")

    // MARK: - Published

    @Published private(set) var devices: [CommunicationDevice] = []
    @Published private(set) var currentDevice: CommunicationDevice?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    @Published private(set) var channels: [CommunicationChannel] = []
    @Published private(set) var subscribedChannels: [SubscribedChannel] = []
    @Published private(set) var mySubscriptions: [ChannelSubscription] = []

    @Published var channelMessages: [UUID: [ChannelMessage]] = [:]
    @Published var isSendingMessage = false
    @Published var subscribedChannelIds: Set<UUID> = []

    private var realtimeChannel: RealtimeChannelV2?
    private var messageSubscriptionTask: Task<Void, Never>?

    private init() {}

    // MARK: - 加载设备

    func loadDevices(userId: UUID) async {
        isLoading = true
        errorMessage = nil
        do {
            let response: [CommunicationDevice] = try await supabase
                .from("communication_devices")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            devices = response
            currentDevice = devices.first(where: { $0.isCurrent })
            logger.info("[Communication] 加载设备 \(response.count) 台")

            if devices.isEmpty {
                await initializeDevices(userId: userId)
            }
        } catch {
            logger.error("[Communication] 加载失败: \(error.localizedDescription)")
            errorMessage = "加载失败: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - 初始化设备

    func initializeDevices(userId: UUID) async {
        do {
            let params: [String: AnyJSON] = ["p_user_id": .string(userId.uuidString.lowercased())]
            try await supabase
                .rpc("initialize_user_devices", params: params)
                .execute()
            logger.info("[Communication] 初始化设备完成")
            await loadDevices(userId: userId)
        } catch {
            logger.error("[Communication] 初始化失败: \(error.localizedDescription)")
            errorMessage = "初始化失败: \(error.localizedDescription)"
        }
    }

    // MARK: - 切换设备

    func switchDevice(userId: UUID, to deviceType: DeviceType) async {
        guard let device = devices.first(where: { $0.deviceType == deviceType }),
              device.isUnlocked else {
            errorMessage = "设备未解锁"
            return
        }
        guard !device.isCurrent else { return }

        isLoading = true
        do {
            let params: [String: AnyJSON] = [
                "p_user_id":     .string(userId.uuidString.lowercased()),
                "p_device_type": .string(deviceType.rawValue)
            ]
            try await supabase
                .rpc("switch_current_device", params: params)
                .execute()

            for i in devices.indices {
                devices[i].isCurrent = (devices[i].deviceType == deviceType)
            }
            currentDevice = devices.first(where: { $0.deviceType == deviceType })
            logger.info("[Communication] 切换至 \(deviceType.displayName)")
        } catch {
            logger.error("[Communication] 切换失败: \(error.localizedDescription)")
            errorMessage = "切换失败: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - 解锁设备（由建造系统调用）

    func unlockDevice(userId: UUID, deviceType: DeviceType) async {
        do {
            struct UnlockPayload: Encodable {
                let is_unlocked: Bool
                let updated_at: String
            }
            let payload = UnlockPayload(
                is_unlocked: true,
                updated_at: ISO8601DateFormatter().string(from: Date())
            )
            try await supabase
                .from("communication_devices")
                .update(payload)
                .eq("user_id", value: userId.uuidString)
                .eq("device_type", value: deviceType.rawValue)
                .execute()

            if let index = devices.firstIndex(where: { $0.deviceType == deviceType }) {
                devices[index].isUnlocked = true
            }
            logger.info("[Communication] 解锁设备 \(deviceType.displayName)")
        } catch {
            logger.error("[Communication] 解锁失败: \(error.localizedDescription)")
            errorMessage = "解锁失败: \(error.localizedDescription)"
        }
    }

    // MARK: - 便捷查询

    func getCurrentDeviceType() -> DeviceType { currentDevice?.deviceType ?? .walkieTalkie }
    func canSendMessage() -> Bool { currentDevice?.deviceType.canSend ?? false }
    func getCurrentRange() -> Double { currentDevice?.deviceType.range ?? 3.0 }
    func isDeviceUnlocked(_ deviceType: DeviceType) -> Bool {
        devices.first(where: { $0.deviceType == deviceType })?.isUnlocked ?? false
    }

    // MARK: - 加载公开频道

    func loadPublicChannels() async {
        do {
            let response: [CommunicationChannel] = try await supabase
                .from("communication_channels")
                .select()
                .eq("is_active", value: true)
                .order("created_at", ascending: false)
                .execute()
                .value
            channels = response
            logger.info("[Channel] 加载公开频道 \(response.count) 个")
        } catch {
            logger.error("[Channel] 加载公开频道失败: \(error.localizedDescription)")
            errorMessage = "加载频道失败: \(error.localizedDescription)"
        }
    }

    // MARK: - 加载订阅频道

    func loadSubscribedChannels(userId: UUID) async {
        do {
            let subs: [ChannelSubscription] = try await supabase
                .from("channel_subscriptions")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value
            mySubscriptions = subs

            guard !subs.isEmpty else {
                subscribedChannels = []
                return
            }

            let channelIds = subs.map { $0.channelId.uuidString }
            let chans: [CommunicationChannel] = try await supabase
                .from("communication_channels")
                .select()
                .in("id", values: channelIds)
                .execute()
                .value

            self.subscribedChannels = subs.compactMap { sub in
                guard let chan = chans.first(where: { $0.id == sub.channelId }) else { return nil }
                return SubscribedChannel(channel: chan, subscription: sub)
            }
            logger.info("[Channel] 加载订阅频道 \(self.subscribedChannels.count) 个")
        } catch {
            logger.error("[Channel] 加载订阅失败: \(error.localizedDescription)")
            errorMessage = "加载订阅失败: \(error.localizedDescription)"
        }
    }

    // MARK: - 创建频道

    func createChannel(userId: UUID, type: ChannelType, name: String, description: String?) async {
        isLoading = true
        do {
            let params: [String: AnyJSON] = [
                "p_creator_id":   .string(userId.uuidString.lowercased()),
                "p_channel_type": .string(type.rawValue),
                "p_name":         .string(name),
                "p_description":  description.map { .string($0) } ?? .null,
                "p_latitude":     .null,
                "p_longitude":    .null
            ]
            try await supabase
                .rpc("create_channel_with_subscription", params: params)
                .execute()
            logger.info("[Channel] 创建频道成功: \(name)")
            await loadPublicChannels()
            await loadSubscribedChannels(userId: userId)
        } catch {
            logger.error("[Channel] 创建频道失败: \(error.localizedDescription)")
            errorMessage = "创建频道失败: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - 订阅频道

    func subscribeToChannel(userId: UUID, channelId: UUID) async {
        do {
            let params: [String: AnyJSON] = [
                "p_user_id":    .string(userId.uuidString.lowercased()),
                "p_channel_id": .string(channelId.uuidString.lowercased())
            ]
            try await supabase
                .rpc("subscribe_to_channel", params: params)
                .execute()
            logger.info("[Channel] 订阅频道成功")
            await loadSubscribedChannels(userId: userId)
            await loadPublicChannels()
        } catch {
            logger.error("[Channel] 订阅失败: \(error.localizedDescription)")
            errorMessage = "订阅失败: \(error.localizedDescription)"
        }
    }

    // MARK: - 取消订阅

    func unsubscribeFromChannel(userId: UUID, channelId: UUID) async {
        do {
            let params: [String: AnyJSON] = [
                "p_user_id":    .string(userId.uuidString.lowercased()),
                "p_channel_id": .string(channelId.uuidString.lowercased())
            ]
            try await supabase
                .rpc("unsubscribe_from_channel", params: params)
                .execute()
            logger.info("[Channel] 取消订阅成功")
            await loadSubscribedChannels(userId: userId)
            await loadPublicChannels()
        } catch {
            logger.error("[Channel] 取消订阅失败: \(error.localizedDescription)")
            errorMessage = "取消订阅失败: \(error.localizedDescription)"
        }
    }

    // MARK: - 删除频道

    func deleteChannel(channelId: UUID, userId: UUID) async {
        do {
            try await supabase
                .from("communication_channels")
                .delete()
                .eq("id", value: channelId.uuidString)
                .execute()
            logger.info("[Channel] 删除频道成功")
            await loadPublicChannels()
            await loadSubscribedChannels(userId: userId)
        } catch {
            logger.error("[Channel] 删除频道失败: \(error.localizedDescription)")
            errorMessage = "删除失败: \(error.localizedDescription)"
        }
    }

    // MARK: - 便捷查询（频道）

    func isSubscribed(channelId: UUID) -> Bool {
        mySubscriptions.contains { $0.channelId == channelId }
    }

    // MARK: - 加载历史消息

    func loadChannelMessages(channelId: UUID) async {
        do {
            let messages: [ChannelMessage] = try await supabase
                .from("channel_messages")
                .select()
                .eq("channel_id", value: channelId.uuidString)
                .order("created_at", ascending: true)
                .limit(50)
                .execute()
                .value
            channelMessages[channelId] = messages
            logger.info("[Message] 加载历史消息 \(messages.count) 条")
        } catch {
            logger.error("[Message] 加载消息失败: \(error.localizedDescription)")
            errorMessage = "加载消息失败: \(error.localizedDescription)"
        }
    }

    // MARK: - 发送消息

    func sendChannelMessage(
        channelId: UUID,
        content: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        deviceType: String? = nil
    ) async -> Bool {
        guard !content.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        isSendingMessage = true
        defer { isSendingMessage = false }
        do {
            let params: [String: AnyJSON] = [
                "p_channel_id":  .string(channelId.uuidString),
                "p_content":     .string(content),
                "p_latitude":    latitude.map  { .double($0) } ?? .null,
                "p_longitude":   longitude.map { .double($0) } ?? .null,
                "p_device_type": deviceType.map { .string($0) } ?? .null
            ]
            try await supabase
                .rpc("send_channel_message", params: params)
                .execute()
            logger.info("[Message] 发送成功")
            return true
        } catch {
            logger.error("[Message] 发送失败: \(error.localizedDescription)")
            errorMessage = "发送失败: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Realtime 订阅

    func startRealtimeSubscription() async {
        await stopRealtimeSubscription()

        let channel = await supabase.realtimeV2.channel("channel_messages_realtime")
        realtimeChannel = channel

        let insertions = await channel.postgresChange(InsertAction.self, table: "channel_messages")

        messageSubscriptionTask = Task { [weak self] in
            for await insertion in insertions {
                await self?.handleNewMessage(insertion: insertion)
            }
        }

        await channel.subscribe()
        logger.info("[Realtime] 消息订阅已启动")
    }

    func stopRealtimeSubscription() async {
        messageSubscriptionTask?.cancel()
        messageSubscriptionTask = nil
        if let channel = realtimeChannel {
            await channel.unsubscribe()
            realtimeChannel = nil
        }
        logger.info("[Realtime] 消息订阅已停止")
    }

    private func handleNewMessage(insertion: InsertAction) async {
        do {
            let message = try insertion.decodeRecord(as: ChannelMessage.self, decoder: JSONDecoder())
            guard subscribedChannelIds.contains(message.channelId) else { return }

            // 距离过滤
            guard shouldReceiveMessage(message) else {
                logger.info("[距离过滤] 🚫 丢弃消息: \(message.content.prefix(20))")
                return
            }

            // 去重判断
            if channelMessages[message.channelId] != nil {
                if !(channelMessages[message.channelId]?.contains(where: { $0.id == message.id }) ?? false) {
                    channelMessages[message.channelId]?.append(message)
                }
            } else {
                channelMessages[message.channelId] = [message]
            }
            logger.info("[Realtime] 收到新消息: \(message.content.prefix(20))")
        } catch {
            logger.error("[Realtime] 解析消息失败: \(error)")
        }
    }

    // MARK: - 频道消息订阅管理

    func subscribeToChannelMessages(channelId: UUID) {
        subscribedChannelIds.insert(channelId)
        if realtimeChannel == nil {
            Task { await startRealtimeSubscription() }
        }
    }

    func unsubscribeFromChannelMessages(channelId: UUID) {
        subscribedChannelIds.remove(channelId)
        channelMessages.removeValue(forKey: channelId)
        if subscribedChannelIds.isEmpty {
            Task { await stopRealtimeSubscription() }
        }
    }

    func getMessages(for channelId: UUID) -> [ChannelMessage] {
        channelMessages[channelId] ?? []
    }

    // MARK: - 距离过滤

    /// 保守策略主入口：信息缺失时一律显示消息
    private func shouldReceiveMessage(_ message: ChannelMessage) -> Bool {
        // 无当前设备 → 保守显示
        guard let myDevice = currentDevice?.deviceType else {
            logger.info("[距离过滤] ⚠️ 无当前设备，保守显示")
            return true
        }
        // 收音机接收方 → 无论什么都显示
        if myDevice == .radio {
            logger.info("[距离过滤] ⚠️ 收音机模式，保守显示")
            return true
        }
        // 消息无设备类型 → 向后兼容，保守显示
        guard let senderDevice = message.senderDeviceType else {
            logger.info("[距离过滤] ⚠️ 消息无设备类型，保守显示")
            return true
        }
        // 消息无位置 → 保守显示
        guard let senderLoc = message.senderLocation else {
            logger.info("[距离过滤] ⚠️ 消息无位置，保守显示")
            return true
        }
        // 无当前位置 → 保守显示
        guard let myLoc = getCurrentLocation() else {
            logger.info("[距离过滤] ⚠️ 无当前位置，保守显示")
            return true
        }
        let distance = calculateDistance(from: senderLoc, to: myLoc)
        let result = canReceiveMessage(senderDevice: senderDevice, myDevice: myDevice, distance: distance)
        if result {
            logger.info("[距离过滤] ✅ 通过，距离 \(String(format: "%.1f", distance)) km")
        } else {
            logger.info("[距离过滤] 🚫 距离过远，\(String(format: "%.1f", distance)) km")
        }
        return result
    }

    /// 设备矩阵：根据发送/接收设备类型和距离判断是否可接收
    private func canReceiveMessage(senderDevice: DeviceType, myDevice: DeviceType, distance: Double) -> Bool {
        switch (senderDevice, myDevice) {
        case (.walkieTalkie, .walkieTalkie): return distance <= 3.0
        case (.walkieTalkie, .campRadio):    return distance <= 30.0
        case (.walkieTalkie, .satellite):    return distance <= 100.0
        case (.campRadio,    .walkieTalkie): return distance <= 30.0
        case (.campRadio,    .campRadio):    return distance <= 30.0
        case (.campRadio,    .satellite):    return distance <= 100.0
        case (.satellite,    .walkieTalkie): return distance <= 100.0
        case (.satellite,    .campRadio):    return distance <= 100.0
        case (.satellite,    .satellite):    return distance <= 100.0
        case (.radio,        _):             return false  // radio 不能发送
        default:                             return false
        }
    }

    /// 计算两点距离（公里）
    private func calculateDistance(from: LocationPoint, to: LocationPoint) -> Double {
        let fromLoc = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLoc   = CLLocation(latitude: to.latitude,   longitude: to.longitude)
        return fromLoc.distance(from: toLoc) / 1000.0
    }

    /// 获取当前位置（接入真实 GPS）
    private func getCurrentLocation() -> LocationPoint? {
        guard let coord = LocationManager.shared.userLocation else { return nil }
        return LocationPoint(latitude: coord.latitude, longitude: coord.longitude)
    }
}
