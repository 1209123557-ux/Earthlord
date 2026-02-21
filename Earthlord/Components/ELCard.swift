//
//  ELCard.swift
//  Earthlord
//
//  通用卡片容器组件，统一项目内卡片的背景色、圆角、阴影
//

import SwiftUI

/// 通用卡片容器
/// 用法：ELCard { /* 内部内容 */ }
struct ELCard<Content: View>: View {
    var padding: EdgeInsets
    let content: () -> Content

    init(
        padding: EdgeInsets = EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14),
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.padding = padding
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(14)
            .shadow(color: .black.opacity(0.18), radius: 5, x: 0, y: 2)
    }
}
