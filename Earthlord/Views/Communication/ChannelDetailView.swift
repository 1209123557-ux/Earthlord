import SwiftUI

struct ChannelDetailView: View {
    let channel: CommunicationChannel

    @EnvironmentObject var authManager: AuthManager
    @StateObject private var communicationManager = CommunicationManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirm = false
    @State private var isProcessing = false

    private var isOwner: Bool {
        authManager.currentUser?.id == channel.creatorId
    }

    private var isSubscribed: Bool {
        communicationManager.isSubscribed(channelId: channel.id)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 频道头
                    VStack(spacing: 12) {
                        Image(systemName: channel.channelType.iconName)
                            .font(.system(size: 48))
                            .foregroundColor(ApocalypseTheme.primary)
                            .frame(width: 90, height: 90)
                            .background(ApocalypseTheme.primary.opacity(0.15))
                            .cornerRadius(22)

                        Text(channel.name)
                            .font(.title2).fontWeight(.bold)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        HStack(spacing: 8) {
                            // 频道码
                            Label(channel.channelCode, systemImage: "number")
                                .font(.caption).fontWeight(.medium)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(ApocalypseTheme.cardBackground)
                                .cornerRadius(6)

                            // 成员数
                            Label("\(channel.memberCount) 人", systemImage: "person.2.fill")
                                .font(.caption).fontWeight(.medium)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(ApocalypseTheme.cardBackground)
                                .cornerRadius(6)

                            // 订阅状态
                            if isSubscribed {
                                Label("已订阅", systemImage: "checkmark.circle.fill")
                                    .font(.caption).fontWeight(.medium)
                                    .foregroundColor(ApocalypseTheme.success)
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(ApocalypseTheme.success.opacity(0.12))
                                    .cornerRadius(6)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(16)

                    // 描述
                    if let desc = channel.description, !desc.isEmpty {
                        infoCard {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("频道描述")
                                    .font(.caption).fontWeight(.semibold)
                                    .foregroundColor(ApocalypseTheme.textSecondary)
                                Text(desc)
                                    .font(.subheadline)
                                    .foregroundColor(ApocalypseTheme.textPrimary)
                            }
                        }
                    }

                    // 频道信息
                    infoCard {
                        VStack(spacing: 12) {
                            infoRow(label: "频道类型", value: channel.channelType.displayName,
                                    icon: channel.channelType.iconName)
                            Divider().background(ApocalypseTheme.textSecondary.opacity(0.2))
                            infoRow(label: "创建时间",
                                    value: channel.createdAt.formatted(date: .abbreviated, time: .omitted),
                                    icon: "calendar")
                            if isOwner {
                                Divider().background(ApocalypseTheme.textSecondary.opacity(0.2))
                                infoRow(label: "我的身份", value: "创建者", icon: "crown.fill")
                            }
                        }
                    }

                    // 操作按钮
                    if isOwner {
                        // 创建者：删除
                        Button(action: { showDeleteConfirm = true }) {
                            Label("删除频道", systemImage: "trash.fill")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(ApocalypseTheme.danger)
                                .cornerRadius(12)
                        }
                    } else {
                        // 非创建者：订阅/取消订阅
                        Button(action: toggleSubscription) {
                            Group {
                                if isProcessing {
                                    ProgressView().tint(.white)
                                } else if isSubscribed {
                                    Label("取消订阅", systemImage: "bell.slash.fill")
                                        .fontWeight(.semibold)
                                } else {
                                    Label("订阅频道", systemImage: "bell.badge.fill")
                                        .fontWeight(.semibold)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(isSubscribed ? ApocalypseTheme.textSecondary : ApocalypseTheme.primary)
                            .cornerRadius(12)
                        }
                        .disabled(isProcessing)
                    }
                }
                .padding(16)
            }
            .background(ApocalypseTheme.background.ignoresSafeArea())
            .navigationTitle("频道详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .alert("删除频道", isPresented: $showDeleteConfirm) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) { deleteChannel() }
            } message: {
                Text("确定要删除「\(channel.name)」吗？此操作不可撤销，所有订阅者将自动退出。")
            }
        }
    }

    // MARK: - 辅助视图

    private func infoCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
    }

    private func infoRow(label: String, value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.primary)
                .frame(width: 20)
            Text(label)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline).fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
    }

    // MARK: - 操作逻辑

    private func toggleSubscription() {
        guard let userId = authManager.currentUser?.id else { return }
        isProcessing = true
        Task {
            if isSubscribed {
                await communicationManager.unsubscribeFromChannel(userId: userId, channelId: channel.id)
            } else {
                await communicationManager.subscribeToChannel(userId: userId, channelId: channel.id)
            }
            isProcessing = false
        }
    }

    private func deleteChannel() {
        guard let userId = authManager.currentUser?.id else { return }
        Task {
            await communicationManager.deleteChannel(channelId: channel.id, userId: userId)
            dismiss()
        }
    }
}

#Preview {
    ChannelDetailView(channel: CommunicationChannel(
        id: UUID(),
        creatorId: UUID(),
        channelType: .public,
        channelCode: "PUB-ABC123",
        name: "幸存者广播站",
        description: "分享末日资讯，互相帮助",
        isActive: true,
        memberCount: 42,
        createdAt: Date()
    ))
    .environmentObject(AuthManager.shared)
}
