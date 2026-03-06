import SwiftUI

struct CreateChannelSheet: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var communicationManager = CommunicationManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedType: ChannelType = .public
    @State private var channelName = ""
    @State private var channelDescription = ""
    @State private var isCreating = false

    private var isValid: Bool {
        channelName.count >= 2 && channelName.count <= 50
    }

    private var creatableTypes: [ChannelType] {
        ChannelType.allCases.filter { $0.canUserCreate }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 类型选择
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader("频道类型")
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(creatableTypes, id: \.self) { type in
                                typeCard(type)
                            }
                        }
                    }

                    // 频道名称
                    VStack(alignment: .leading, spacing: 8) {
                        sectionHeader("频道名称")
                        HStack {
                            TextField("2-50 个字符", text: $channelName)
                                .foregroundColor(ApocalypseTheme.textPrimary)
                                .tint(ApocalypseTheme.primary)
                            Spacer()
                            Text("\(channelName.count)/50")
                                .font(.caption)
                                .foregroundColor(channelName.count > 50
                                    ? ApocalypseTheme.danger
                                    : ApocalypseTheme.textSecondary)
                        }
                        .padding(12)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    channelName.count > 50 ? ApocalypseTheme.danger : Color.clear,
                                    lineWidth: 1
                                )
                        )
                    }

                    // 频道描述（可选）
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            sectionHeader("频道描述")
                            Text("（可选）")
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }
                        TextField("简短描述这个频道的用途...", text: $channelDescription, axis: .vertical)
                            .lineLimit(3...5)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                            .tint(ApocalypseTheme.primary)
                            .padding(12)
                            .background(ApocalypseTheme.cardBackground)
                            .cornerRadius(10)
                    }

                    // 选中类型说明
                    HStack(spacing: 10) {
                        Image(systemName: selectedType.iconName)
                            .foregroundColor(ApocalypseTheme.primary)
                        Text(selectedType.description)
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ApocalypseTheme.primary.opacity(0.08))
                    .cornerRadius(10)

                    // 创建按钮
                    Button(action: createChannel) {
                        HStack {
                            if isCreating {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "plus.circle.fill")
                                Text("创建频道")
                                    .fontWeight(.semibold)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isValid ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary.opacity(0.3))
                        .cornerRadius(12)
                    }
                    .disabled(!isValid || isCreating)
                }
                .padding(16)
            }
            .background(ApocalypseTheme.background.ignoresSafeArea())
            .navigationTitle("创建频道")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
    }

    // MARK: - 类型卡片

    private func typeCard(_ type: ChannelType) -> some View {
        let isSelected = selectedType == type
        return Button(action: { selectedType = type }) {
            VStack(spacing: 8) {
                Image(systemName: type.iconName)
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)
                Text(type.displayName)
                    .font(.caption).fontWeight(.medium)
                    .foregroundColor(isSelected ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isSelected
                ? ApocalypseTheme.primary.opacity(0.15)
                : ApocalypseTheme.cardBackground)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? ApocalypseTheme.primary : Color.clear, lineWidth: 1.5)
            )
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline).fontWeight(.semibold)
            .foregroundColor(ApocalypseTheme.textPrimary)
    }

    // MARK: - 创建逻辑

    private func createChannel() {
        guard let userId = authManager.currentUser?.id, isValid else { return }
        isCreating = true
        Task {
            await communicationManager.createChannel(
                userId: userId,
                type: selectedType,
                name: channelName.trimmingCharacters(in: .whitespacesAndNewlines),
                description: channelDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil
                    : channelDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            isCreating = false
            if communicationManager.errorMessage == nil {
                dismiss()
            }
        }
    }
}

#Preview {
    CreateChannelSheet()
        .environmentObject(AuthManager.shared)
}
