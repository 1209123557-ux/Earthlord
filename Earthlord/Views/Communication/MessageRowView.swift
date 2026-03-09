import SwiftUI

struct MessageRowView: View {
    let summary: CommunicationManager.ChannelSummary

    private var channelColor: Color {
        switch summary.channel.channelType {
        case .official:  return ApocalypseTheme.primary
        case .public:    return ApocalypseTheme.info
        case .walkie:    return ApocalypseTheme.success
        case .camp:      return ApocalypseTheme.warning
        case .satellite: return Color.purple
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // 频道图标
            Image(systemName: summary.channel.channelType.iconName)
                .font(.system(size: 20))
                .foregroundColor(channelColor)
                .frame(width: 46, height: 46)
                .background(channelColor.opacity(0.15))
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(summary.channel.name)
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .lineLimit(1)
                    if summary.channel.channelType == .official {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.primary)
                    }
                    Spacer()
                    if let msg = summary.lastMessage {
                        Text(msg.timeAgo)
                            .font(.caption2)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }

                if let msg = summary.lastMessage {
                    Text(msg.content)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .lineLimit(1)
                } else {
                    Text("暂无消息")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.6))
                }
            }
        }
        .padding(12)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }
}
