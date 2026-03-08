import SwiftUI
import Supabase

struct ChannelChatView: View {
    let channel: CommunicationChannel

    @EnvironmentObject var authManager: AuthManager
    @StateObject private var communicationManager = CommunicationManager.shared

    @State private var inputText = ""
    @State private var isSending = false

    private var messages: [ChannelMessage] {
        communicationManager.getMessages(for: channel.id)
    }

    private var canSend: Bool {
        communicationManager.canSendMessage()
    }

    private var currentUserId: UUID? {
        authManager.currentUser?.id
    }

    var body: some View {
        VStack(spacing: 0) {
            // 频道信息栏
            channelInfoBar

            Divider().background(ApocalypseTheme.textSecondary.opacity(0.3))

            // 消息列表
            messageList

            Divider().background(ApocalypseTheme.textSecondary.opacity(0.3))

            // 输入区域
            if canSend {
                inputBar
            } else {
                radioModeNotice
            }
        }
        .background(ApocalypseTheme.background)
        .navigationTitle(channel.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            communicationManager.subscribeToChannelMessages(channelId: channel.id)
            Task {
                await communicationManager.loadChannelMessages(channelId: channel.id)
                await communicationManager.startRealtimeSubscription()
            }
        }
        .onDisappear {
            communicationManager.unsubscribeFromChannelMessages(channelId: channel.id)
            Task { await communicationManager.stopRealtimeSubscription() }
        }
    }

    // MARK: - 频道信息栏

    private var channelInfoBar: some View {
        HStack(spacing: 10) {
            Image(systemName: channel.channelType.iconName)
                .font(.system(size: 16))
                .foregroundColor(ApocalypseTheme.primary)

            VStack(alignment: .leading, spacing: 1) {
                Text(channel.channelCode)
                    .font(.caption).fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "person.2.fill")
                    .font(.caption2)
                Text("\(channel.memberCount)")
                    .font(.caption)
            }
            .foregroundColor(ApocalypseTheme.textSecondary)

            // 当前设备
            HStack(spacing: 4) {
                Image(systemName: communicationManager.getCurrentDeviceType().iconName)
                    .font(.caption2)
                Text(communicationManager.getCurrentDeviceType().rangeText)
                    .font(.caption2)
            }
            .foregroundColor(ApocalypseTheme.primary)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(ApocalypseTheme.primary.opacity(0.15))
            .cornerRadius(6)
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - 消息列表

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    if messages.isEmpty {
                        emptyMessagesView
                    } else {
                        ForEach(messages) { message in
                            MessageBubbleView(
                                message: message,
                                isOwn: message.senderId == currentUserId
                            )
                            .id(message.id)
                        }
                    }
                }
                .padding(.vertical, 12)
            }
            .background(ApocalypseTheme.background)
            .onChange(of: messages.count) { _ in
                if let last = messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                if let last = messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private var emptyMessagesView: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 80)
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.4))
            Text("还没有消息")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
            Text("发送第一条消息开始对话")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.6))
            Spacer(minLength: 80)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 输入框

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("输入消息...", text: $inputText, axis: .vertical)
                .lineLimit(1...4)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .tint(ApocalypseTheme.primary)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(20)

            Button(action: sendMessage) {
                Group {
                    if isSending {
                        ProgressView().tint(.white)
                            .frame(width: 20, height: 20)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16))
                    }
                }
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(inputText.trimmingCharacters(in: .whitespaces).isEmpty
                    ? ApocalypseTheme.textSecondary.opacity(0.3)
                    : ApocalypseTheme.primary)
                .clipShape(Circle())
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - 收音机提示

    private var radioModeNotice: some View {
        HStack(spacing: 8) {
            Image(systemName: "radio")
                .foregroundColor(ApocalypseTheme.warning)
            Text("收音机模式：只能收听，无法发送消息")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - 发送逻辑

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        isSending = true
        let deviceType = communicationManager.getCurrentDeviceType().rawValue
        let coord = LocationManager.shared.userLocation
        Task {
            let success = await communicationManager.sendChannelMessage(
                channelId: channel.id,
                content: text,
                latitude: coord?.latitude,
                longitude: coord?.longitude,
                deviceType: deviceType
            )
            if success { inputText = "" }
            isSending = false
        }
    }
}

// MARK: - 消息气泡

private struct MessageBubbleView: View {
    let message: ChannelMessage
    let isOwn: Bool

    private func deviceIcon(_ type: String?) -> String {
        switch type {
        case "radio":                          return "radio"
        case "walkie_talkie", "walkieTalkie":  return "phone.badge.waveform"
        case "camp_radio",   "campRadio":      return "antenna.radiowaves.left.and.right"
        case "satellite":                      return "antenna.radiowaves.left.and.right.circle"
        default:                               return "iphone"
        }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isOwn { Spacer(minLength: 60) }

            VStack(alignment: isOwn ? .trailing : .leading, spacing: 4) {
                // 他人消息显示呼号 + 设备
                if !isOwn {
                    HStack(spacing: 4) {
                        Text(message.senderCallsign ?? "匿名幸存者")
                            .font(.caption2).fontWeight(.semibold)
                            .foregroundColor(ApocalypseTheme.primary)
                        if let dt = message.deviceType {
                            Image(systemName: deviceIcon(dt))
                                .font(.system(size: 10))
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }
                    }
                    .padding(.horizontal, 4)
                }

                // 消息气泡
                VStack(alignment: isOwn ? .trailing : .leading, spacing: 2) {
                    Text(message.content)
                        .font(.subheadline)
                        .foregroundColor(isOwn ? .white : ApocalypseTheme.textPrimary)
                        .multilineTextAlignment(isOwn ? .trailing : .leading)

                    HStack(spacing: 4) {
                        if isOwn, let dt = message.deviceType {
                            Image(systemName: deviceIcon(dt))
                                .font(.system(size: 9))
                                .foregroundColor(isOwn ? .white.opacity(0.6) : ApocalypseTheme.textSecondary)
                        }
                        Text(message.timeAgo)
                            .font(.system(size: 10))
                            .foregroundColor(isOwn ? .white.opacity(0.6) : ApocalypseTheme.textSecondary)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(isOwn
                    ? ApocalypseTheme.primary
                    : ApocalypseTheme.cardBackground)
                .cornerRadius(16)
                .cornerRadius(isOwn ? 4 : 16, corners: isOwn ? .bottomRight : .bottomLeft)
            }

            if !isOwn { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 16).padding(.vertical, 2)
    }
}

// MARK: - 圆角辅助

private extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

private struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect,
                                byRoundingCorners: corners,
                                cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

#Preview {
    NavigationStack {
        ChannelChatView(channel: CommunicationChannel(
            id: UUID(),
            creatorId: UUID(),
            channelType: .public,
            channelCode: "PUB-ABC123",
            name: "幸存者广播站",
            description: nil,
            isActive: true,
            memberCount: 12,
            createdAt: Date()
        ))
        .environmentObject(AuthManager.shared)
    }
}
