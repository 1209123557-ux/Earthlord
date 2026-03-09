import SwiftUI
import Supabase

struct MessageCenterView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @StateObject private var communicationManager = CommunicationManager.shared

    @State private var selectedChannel: CommunicationChannel? = nil
    @State private var navigateToChannel = false

    private var summaries: [CommunicationManager.ChannelSummary] {
        communicationManager.getChannelSummaries()
    }

    var body: some View {
        NavigationStack {
            Group {
                if summaries.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(summaries) { summary in
                                MessageRowView(summary: summary)
                                    .onTapGesture { selectedChannel = summary.channel }
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .background(ApocalypseTheme.background.ignoresSafeArea())
            .navigationTitle("消息中心")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedChannel) { channel in
                if channel.channelType == .official {
                    OfficialChannelDetailView(channel: channel)
                } else {
                    ChannelChatView(channel: channel)
                        .environmentObject(authManager)
                }
            }
            .onAppear {
                guard let userId = authManager.currentUser?.id else { return }
                Task {
                    await communicationManager.loadSubscribedChannels(userId: userId)
                    await communicationManager.loadAllChannelLatestMessages()
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "bell.slash")
                .font(.system(size: 44))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.4))
            Text("还没有订阅任何频道")
                .font(.subheadline).fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.textPrimary)
            Text("前往「频道」页面订阅感兴趣的频道")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
