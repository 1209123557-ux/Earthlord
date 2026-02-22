//
//  MainTabView.swift
//  Earthlord
//
//  Created by 许意晗 on 2026/2/8.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    // ⭐ 提升到 MainTabView 层级，所有 Tab 共享同一个实例
    @StateObject private var locationManager = LocationManager()
    // 背包数据：使用单例，MapTabView.stopExploring() 写入后此处自动刷新
    private let inventoryManager = InventoryManager.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            MapTabView()
                .tabItem {
                    Image(systemName: "map.fill")
                    Text("地图")
                }
                .tag(0)

            TerritoryTabView()
                .tabItem {
                    Image(systemName: "flag.fill")
                    Text("领地")
                }
                .tag(1)

            ResourcesTabView()
                .tabItem {
                    Image(systemName: "backpack.fill")
                    Text("资源")
                }
                .tag(2)

            ProfileTabView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("个人")
                }
                .tag(3)

            MoreTabView()
                .tabItem {
                    Image(systemName: "ellipsis")
                    Text("更多")
                }
                .tag(4)
        }
        .tint(ApocalypseTheme.primary)
        // 注入到所有子视图
        .environmentObject(locationManager)
        .environmentObject(inventoryManager)
    }
}

#Preview {
    MainTabView()
}
