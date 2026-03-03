//
//  TradeMainView.swift
//  Earthlord
//
//  交易系统总入口，被 ResourcesTabView segment 4 显示。
//  顶部分段选择器切换：我的挂单 / 市场 / 历史
//  无需 NavigationStack（ResourcesTabView 已提供）。
//

import SwiftUI

struct TradeMainView: View {

    @EnvironmentObject private var inventoryManager: InventoryManager
    @State private var selectedTab = 0

    private let tabs = ["我的挂单", "市场", "历史"]

    var body: some View {
        VStack(spacing: 0) {
            // 子分段选择器
            Picker("", selection: $selectedTab) {
                ForEach(0..<tabs.count, id: \.self) { idx in
                    Text(tabs[idx]).tag(idx)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(ApocalypseTheme.background)

            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 1)

            // 内容区
            tabContent
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0:
            MyOffersView()
                .environmentObject(inventoryManager)
        case 1:
            TradeMarketView()
                .environmentObject(inventoryManager)
        default:
            TradeHistoryView()
        }
    }
}
