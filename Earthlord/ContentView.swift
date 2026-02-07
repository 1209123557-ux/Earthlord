//
//  ContentView.swift
//  Earthlord
//
//  Created by 许意晗 on 2026/2/6.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            Text("Developed by 许意晗")
                .font(.title2)
                .fontWeight(.bold)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
