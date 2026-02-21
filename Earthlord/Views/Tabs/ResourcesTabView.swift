//
//  ResourcesTabView.swift
//  Earthlord
//
//  资源模块主入口 Tab
//  分段选择器：POI / 背包 / 已购 / 领地 / 交易
//  POI 和 背包 分段显示对应子页面，其余显示占位文字
//

import SwiftUI

struct ResourcesTabView: View {

    // MARK: - 状态
    @State private var selectedSegment = 0
    @State private var tradeEnabled    = false   // 交易开关（假数据，待后端）

    // MARK: - 分段定义
    private let segments = ["POI", "背包", "已购", "领地", "交易"]

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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    tradeToggle
                }
            }
        }
    }

    // MARK: - 分段选择器

    private var segmentedPicker: some View {
        Picker("", selection: $selectedSegment) {
            ForEach(0..<segments.count, id: \.self) { idx in
                Text(segments[idx]).tag(idx)
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

    // MARK: - 交易开关（右上角）

    private var tradeToggle: some View {
        HStack(spacing: 6) {
            Text("交易")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(tradeEnabled
                    ? ApocalypseTheme.primary
                    : ApocalypseTheme.textMuted)
            Toggle("", isOn: $tradeEnabled)
                .labelsHidden()
                .tint(ApocalypseTheme.primary)
        }
    }
}

// MARK: - Preview

#Preview {
    ResourcesTabView()
}
