//
//  ContentView.swift
//  Earthlord
//
//  Created by 许意晗 on 2026/2/6.
//

import SwiftUI

struct ContentView: View {
    @State private var showTestView = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("Hello, world!")
                Text("Developed by 许意晗")
                    .font(.title2)
                    .fontWeight(.bold)
                NavigationLink("进入测试页", destination: TestView())
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
