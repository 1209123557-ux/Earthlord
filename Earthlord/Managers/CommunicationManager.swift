import Foundation
import Combine
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
}
