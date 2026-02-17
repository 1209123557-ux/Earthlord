//
//  TestMenuView.swift
//  Earthlord
//
//  开发测试菜单 - 汇总所有测试入口
//

import SwiftUI

struct TestMenuView: View {
    @EnvironmentObject var locationManager: LocationManager

    var body: some View {
        List {
            Section(header: Text("开发工具")) {
                // Supabase 连接测试
                NavigationLink(destination: SupabaseTestView()) {
                    HStack {
                        Image(systemName: "externaldrive.badge.checkmark")
                            .foregroundColor(.blue)
                            .frame(width: 30)
                        Text("Supabase 连接测试")
                    }
                }

                // 圈地功能测试
                NavigationLink(destination: TerritoryTestView().environmentObject(locationManager)) {
                    HStack {
                        Image(systemName: "map.fill")
                            .foregroundColor(ApocalypseTheme.primary)
                            .frame(width: 30)
                        Text("圈地功能测试")
                    }
                }
            }
        }
        .navigationTitle("开发测试")
    }
}

#Preview {
    NavigationView {
        TestMenuView()
    }
}
