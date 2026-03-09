import SwiftUI
import CoreLocation
import Supabase

struct PTTCallView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @StateObject private var communicationManager = CommunicationManager.shared
    @ObservedObject private var locationManager = LocationManager.shared

    @State private var messageText = ""
    @State private var isPressing = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastIsError = false

    private var currentDevice: DeviceType {
        communicationManager.getCurrentDeviceType()
    }

    private var canSend: Bool {
        communicationManager.canSendMessage() && !messageText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // 找一个可发送消息的频道（非官方频道，取第一个已订阅）
    private var targetChannel: CommunicationChannel? {
        communicationManager.subscribedChannels.first(where: {
            $0.channel.channelType != .official
        })?.channel
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 当前设备状态
                deviceStatusCard

                // 消息输入区
                messageInputCard

                // PTT 发送按钮
                pttButton

                // 频道信息
                channelInfoCard
            }
            .padding(16)
        }
        .background(ApocalypseTheme.background.ignoresSafeArea())
        .overlay(alignment: .top) {
            if showToast {
                toastView
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showToast)
    }

    // MARK: - 设备状态卡片

    private var deviceStatusCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(currentDevice.canSend
                          ? ApocalypseTheme.primary.opacity(0.2)
                          : ApocalypseTheme.textSecondary.opacity(0.15))
                    .frame(width: 64, height: 64)
                Image(systemName: currentDevice.iconName)
                    .font(.system(size: 28))
                    .foregroundColor(currentDevice.canSend
                        ? ApocalypseTheme.primary
                        : ApocalypseTheme.textSecondary)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(currentDevice.displayName)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Text("覆盖: \(currentDevice.rangeText)")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                HStack(spacing: 4) {
                    Circle()
                        .fill(currentDevice.canSend ? ApocalypseTheme.success : ApocalypseTheme.warning)
                        .frame(width: 8, height: 8)
                    Text(currentDevice.canSend ? "可发送" : "仅接收模式")
                        .font(.caption)
                        .foregroundColor(currentDevice.canSend ? ApocalypseTheme.success : ApocalypseTheme.warning)
                }
            }
            Spacer()
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(14)
    }

    // MARK: - 消息输入卡片

    private var messageInputCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("发送内容")
                .font(.caption).fontWeight(.semibold)
                .foregroundColor(ApocalypseTheme.textSecondary)

            ZStack(alignment: .topLeading) {
                if messageText.isEmpty {
                    Text("输入要广播的内容…")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.6))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                }
                TextEditor(text: $messageText)
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 80, maxHeight: 120)
                    .disabled(!currentDevice.canSend)
            }
            .padding(10)
            .background(ApocalypseTheme.background)
            .cornerRadius(10)

            if !currentDevice.canSend {
                Label("收音机只能接收，无法发送消息", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.warning)
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(14)
    }

    // MARK: - PTT 按钮

    private var pttButton: some View {
        VStack(spacing: 10) {
            Text(isPressing ? "松开发送" : "长按发送")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)

            ZStack {
                Circle()
                    .fill(buttonColor.opacity(isPressing ? 0.3 : 0.15))
                    .frame(width: 120, height: 120)
                Circle()
                    .fill(buttonColor)
                    .frame(width: isPressing ? 90 : 100, height: isPressing ? 90 : 100)
                    .animation(.spring(response: 0.2), value: isPressing)
                Image(systemName: "mic.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.white)
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.3)
                    .onChanged { _ in
                        guard canSend else { return }
                        if !isPressing {
                            isPressing = true
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }
                    }
                    .onEnded { _ in
                        guard isPressing else { return }
                        isPressing = false
                        sendMessage()
                    }
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { _ in
                        if isPressing {
                            isPressing = false
                            sendMessage()
                        }
                    }
            )
            .opacity(canSend ? 1.0 : 0.4)
            .disabled(!canSend)
        }
    }

    private var buttonColor: Color {
        isPressing ? ApocalypseTheme.success : ApocalypseTheme.primary
    }

    // MARK: - 频道信息卡片

    private var channelInfoCard: some View {
        Group {
            if let channel = targetChannel {
                HStack(spacing: 10) {
                    Image(systemName: channel.channelType.iconName)
                        .font(.system(size: 16))
                        .foregroundColor(ApocalypseTheme.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("发送至频道")
                            .font(.caption2)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                        Text(channel.name)
                            .font(.caption).fontWeight(.medium)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }
                    Spacer()
                    Text(channel.channelCode)
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(ApocalypseTheme.background)
                        .cornerRadius(6)
                }
                .padding(12)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(12)
            } else {
                Label("未订阅任何频道", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.warning)
                    .padding(12)
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(12)
            }
        }
    }

    // MARK: - Toast

    private var toastView: some View {
        HStack(spacing: 8) {
            Image(systemName: toastIsError ? "xmark.circle.fill" : "checkmark.circle.fill")
                .foregroundColor(toastIsError ? ApocalypseTheme.danger : ApocalypseTheme.success)
            Text(toastMessage)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(20)
        .shadow(radius: 8)
    }

    // MARK: - 发送逻辑

    private func sendMessage() {
        guard let channel = targetChannel else {
            showToastMessage("未订阅任何频道", isError: true)
            return
        }
        let content = messageText.trimmingCharacters(in: .whitespaces)
        guard !content.isEmpty else { return }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        Task {
            let lat = locationManager.userLocation?.latitude
            let lon = locationManager.userLocation?.longitude
            let success = await communicationManager.sendChannelMessage(
                channelId: channel.id,
                content: content,
                latitude: lat,
                longitude: lon,
                deviceType: currentDevice.rawValue
            )
            if success {
                messageText = ""
                showToastMessage("消息已发送", isError: false)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } else {
                showToastMessage("发送失败，请重试", isError: true)
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    private func showToastMessage(_ message: String, isError: Bool) {
        toastMessage = message
        toastIsError = isError
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { showToast = false }
        }
    }
}
