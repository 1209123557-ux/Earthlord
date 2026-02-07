//
//  TestView.swift
//  Earthlord
//
//  Created by 许意晗 on 2026/2/6.
//

import SwiftUI

struct TestView: View {
    var body: some View {
        ZStack {
            Color(.systemBlue).opacity(0.2)
                .ignoresSafeArea()
            Text("这里是分支宇宙的测试页")
                .font(.largeTitle)
                .fontWeight(.bold)
        }
    }
}

#Preview {
    TestView()
}
