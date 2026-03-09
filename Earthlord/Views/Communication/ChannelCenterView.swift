import SwiftUI
import Supabase

struct ChannelCenterView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var communicationManager = CommunicationManager.shared

    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var showCreateSheet = false
    @State private var selectedChannel: CommunicationChannel?

    private var filteredChannels: [CommunicationChannel] {
        if searchText.isEmpty { return communicationManager.channels }
        return communicationManager.channels.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.channelCode.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab 切换栏 + 创建按钮
            HStack(spacing: 0) {
                tabButton(title: "我的频道", index: 0)
                tabButton(title: "发现频道", index: 1)
                Button(action: { showCreateSheet = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(ApocalypseTheme.primary)
                }
                .padding(.leading, 8)
            }
            .padding(.horizontal, 16).padding(.vertical, 8)

            Divider().background(ApocalypseTheme.textSecondary.opacity(0.3))

            if selectedTab == 0 {
                myChannelsContent
            } else {
                discoverContent
            }
        }
        .background(ApocalypseTheme.background)
        .sheet(isPresented: $showCreateSheet) {
            CreateChannelSheet()
                .environmentObject(authManager)
                .onDisappear {
                    if let userId = authManager.currentUser?.id {
                        Task {
                            await communicationManager.loadPublicChannels()
                            await communicationManager.loadSubscribedChannels(userId: userId)
                        }
                    }
                }
        }
        .sheet(item: $selectedChannel) { channel in
            if channel.channelType == .official {
                OfficialChannelDetailView(channel: channel)
                    .environmentObject(authManager)
            } else {
                ChannelDetailView(channel: channel)
                    .environmentObject(authManager)
                    .onDisappear {
                        if let userId = authManager.currentUser?.id {
                            Task {
                                await communicationManager.loadPublicChannels()
                                await communicationManager.loadSubscribedChannels(userId: userId)
                            }
                        }
                    }
            }
        }
        .onAppear {
            if let userId = authManager.currentUser?.id {
                Task {
                    await communicationManager.loadPublicChannels()
                    await communicationManager.loadSubscribedChannels(userId: userId)
                    await communicationManager.ensureOfficialChannelSubscribed(userId: userId)
                }
            }
        }
    }

    // MARK: - 我的频道

    private var myChannelsContent: some View {
        Group {
            if communicationManager.subscribedChannels.isEmpty {
                emptyView(icon: "dot.radiowaves.left.and.right", message: "还没有订阅任何频道", sub: "去「发现频道」探索并加入")
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(communicationManager.subscribedChannels) { item in
                            ChannelRow(channel: item.channel, isSubscribed: true)
                                .onTapGesture { selectedChannel = item.channel }
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    // MARK: - 发现频道

    private var discoverContent: some View {
        VStack(spacing: 0) {
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(ApocalypseTheme.textSecondary)
                TextField("搜索频道名称或编码", text: $searchText)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .tint(ApocalypseTheme.primary)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
            }
            .padding(10)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(10)
            .padding(.horizontal, 16).padding(.vertical, 8)

            if communicationManager.isLoading {
                Spacer()
                ProgressView().tint(ApocalypseTheme.primary)
                Spacer()
            } else if filteredChannels.isEmpty {
                emptyView(icon: "globe", message: "暂无公开频道", sub: "点击右上角「+」创建第一个频道")
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredChannels) { channel in
                            ChannelRow(
                                channel: channel,
                                isSubscribed: communicationManager.isSubscribed(channelId: channel.id)
                            )
                            .onTapGesture { selectedChannel = channel }
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    // MARK: - 辅助

    private func tabButton(title: String, index: Int) -> some View {
        Button(action: { selectedTab = index }) {
            Text(title)
                .font(.subheadline).fontWeight(.medium)
                .foregroundColor(selectedTab == index ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(selectedTab == index ? ApocalypseTheme.primary.opacity(0.15) : Color.clear)
                .cornerRadius(8)
        }
    }

    private func emptyView(icon: String, message: String, sub: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))
            Text(message)
                .font(.subheadline).fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.textPrimary)
            Text(sub)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 频道行

private struct ChannelRow: View {
    let channel: CommunicationChannel
    let isSubscribed: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: channel.channelType.iconName)
                .font(.system(size: 20))
                .foregroundColor(ApocalypseTheme.primary)
                .frame(width: 40, height: 40)
                .background(ApocalypseTheme.primary.opacity(0.15))
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(channel.name)
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Text(channel.channelType.displayName)
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(4)
                }
                Text(channel.channelCode)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if isSubscribed {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(ApocalypseTheme.success)
                }
                HStack(spacing: 2) {
                    Image(systemName: "person.2.fill")
                        .font(.caption2)
                    Text("\(channel.memberCount)")
                        .font(.caption2)
                }
                .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        .padding(12)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }
}

#Preview {
    ChannelCenterView()
        .environmentObject(AuthManager.shared)
        .background(ApocalypseTheme.background)
}
