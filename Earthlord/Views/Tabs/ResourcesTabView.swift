//
//  ResourcesTabView.swift
//  Earthlord
//
//  资源模块主入口 Tab
//  分段选择器：POI / 背包 / 商城 / 邮箱 / 领地 / 交易
//

import SwiftUI

struct ResourcesTabView: View {

    // MARK: - 状态
    @State private var selectedSegment = 0
    @EnvironmentObject private var inventoryManager: InventoryManager

    // MARK: - 分段定义
    private let segments = ["POI", "背包", "商城", "邮箱", "领地", "交易"]
    @StateObject private var mailboxManager = MailboxManager.shared

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    segmentedPicker
                    sectionDivider
                    segmentContent
                }
            }
            // 默认标题：当 POI / 背包 子页面设置自己的 navigationTitle 时会覆盖此值
            .navigationTitle("资源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task { await mailboxManager.fetchMailbox() }
        }
    }

    // MARK: - 分段选择器

    private var segmentedPicker: some View {
        Picker("", selection: $selectedSegment) {
            ForEach(0..<segments.count, id: \.self) { idx in
                // 邮箱 tab（index 3）有未读时在文字后加红点
                if idx == 3 && mailboxManager.unclaimedCount > 0 {
                    Text("邮箱 ●").tag(idx)
                } else {
                    Text(segments[idx]).tag(idx)
                }
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(ApocalypseTheme.background)
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(height: 1)
    }

    // MARK: - 内容区域

    @ViewBuilder
    private var segmentContent: some View {
        switch selectedSegment {
        case 0:
            POIListView()
        case 1:
            BackpackView()
        case 2:
            StoreView()
        case 3:
            MailboxView()
        case 5:
            TradeMainView()
                .environmentObject(inventoryManager)
        default:
            placeholderView(title: segments[selectedSegment])
        }
    }

    // MARK: - 占位视图（已购 / 领地 / 交易）

    private func placeholderView(title: String) -> some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 46))
                    .foregroundColor(ApocalypseTheme.textMuted)

                Text("功能开发中")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("「\(title)」模块即将上线，敬请期待")
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textMuted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

}

// MARK: - Preview

#Preview {
    ResourcesTabView()
}
