import SwiftUI

struct OfficialChannelDetailView: View {
    let channel: CommunicationChannel

    @StateObject private var communicationManager = CommunicationManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: MessageCategory? = nil

    private var messages: [ChannelMessage] {
        communicationManager.getMessages(for: channel.id)
    }

    private var filteredMessages: [ChannelMessage] {
        guard let cat = selectedCategory else { return messages }
        return messages.filter { $0.category == cat }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 分类过滤器
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        CategoryChip(title: "全部", color: ApocalypseTheme.primary,
                                     isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                        }
                        ForEach(MessageCategory.allCases, id: \.self) { cat in
                            CategoryChip(title: cat.displayName, color: cat.color,
                                         isSelected: selectedCategory == cat) {
                                selectedCategory = selectedCategory == cat ? nil : cat
                            }
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                }
                .background(ApocalypseTheme.cardBackground)

                Divider().background(ApocalypseTheme.textSecondary.opacity(0.2))

                if filteredMessages.isEmpty {
                    Spacer()
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.4))
                    Text("暂无公告")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .padding(.top, 8)
                    Spacer()
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredMessages) { msg in
                                    OfficialMessageBubble(message: msg)
                                        .id(msg.id)
                                }
                            }
                            .padding(16)
                        }
                        .onAppear {
                            if let last = filteredMessages.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .background(ApocalypseTheme.background.ignoresSafeArea())
            .navigationTitle(channel.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .onAppear {
                communicationManager.subscribeToChannelMessages(channelId: channel.id)
                Task { await communicationManager.loadChannelMessages(channelId: channel.id) }
            }
            .onDisappear {
                communicationManager.unsubscribeFromChannelMessages(channelId: channel.id)
            }
        }
    }
}

// MARK: - 分类过滤 Chip

private struct CategoryChip: View {
    let title: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption).fontWeight(.medium)
                .foregroundColor(isSelected ? .white : color)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(isSelected ? color : color.opacity(0.15))
                .cornerRadius(20)
        }
    }
}

// MARK: - 官方消息气泡

private struct OfficialMessageBubble: View {
    let message: ChannelMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 分类 badge + 时间
            HStack(spacing: 6) {
                if let cat = message.category {
                    HStack(spacing: 4) {
                        Image(systemName: cat.iconName)
                            .font(.system(size: 10))
                        Text(cat.displayName)
                            .font(.caption2).fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(cat.color)
                    .cornerRadius(10)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "megaphone.fill")
                            .font(.system(size: 10))
                        Text("官方公告")
                            .font(.caption2).fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(10)
                }
                Spacer()
                Text(message.timeAgo)
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 正文
            Text(message.content)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ApocalypseTheme.primary.opacity(0.3), lineWidth: 1)
        )
    }
}
