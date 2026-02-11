//
//  RootView.swift
//  Earthlord
//
//  Created by 许意晗 on 2026/2/8.
//

import SwiftUI

/// 根视图：控制启动页 → 认证页/主界面的切换
struct RootView: View {
    /// 启动页是否完成
    @State private var splashFinished = false

    /// 认证管理器
    @StateObject private var authManager = AuthManager.shared

    var body: some View {
        ZStack {
            if !splashFinished {
                // 启动页
                SplashView(isFinished: $splashFinished)
                    .transition(.opacity)
            } else if authManager.isAuthenticated {
                // 已登录 → 主界面
                MainTabView()
                    .transition(.opacity)
            } else {
                // 未登录 → 认证页
                AuthView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: splashFinished)
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
        .task {
            // 启动时检查现有会话
            await authManager.checkSession()
        }
    }
}

#Preview {
    RootView()
}
