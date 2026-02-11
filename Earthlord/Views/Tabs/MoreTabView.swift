//
//  MoreTabView.swift
//  Earthlord
//
//  Created by 许意晗 on 2026/2/8.
//

import SwiftUI

struct MoreTabView: View {
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("开发工具")) {
                    NavigationLink(destination: SupabaseTestView()) {
                        HStack {
                            Image(systemName: "externaldrive.badge.checkmark")
                                .foregroundColor(.blue)
                                .frame(width: 30)
                            Text("Supabase 连接测试")
                        }
                    }
                }
            }
            .navigationTitle("更多")
        }
    }
}

#Preview {
    MoreTabView()
}
