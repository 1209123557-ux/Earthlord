//
//  TerritoryToolbarView.swift
//  Earthlord
//
//  领地详情页顶部悬浮工具栏
//  HStack：[← 关闭] [Spacer] [🔨 建造] [ℹ 信息]
//

import SwiftUI

struct TerritoryToolbarView: View {
    let onDismiss: () -> Void
    let onBuildingBrowser: () -> Void
    @Binding var showInfoPanel: Bool

    var body: some View {
        HStack(spacing: 12) {
            // 关闭按钮
            Button(action: onDismiss) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("关闭")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.55))
                .cornerRadius(20)
            }

            Spacer()

            // 建造按钮
            Button(action: onBuildingBrowser) {
                HStack(spacing: 6) {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 14))
                    Text("建造")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(ApocalypseTheme.primary.opacity(0.9))
                .cornerRadius(20)
            }

            // 信息面板切换按钮
            Button(action: { withAnimation(.easeInOut(duration: 0.25)) { showInfoPanel.toggle() } }) {
                Image(systemName: showInfoPanel ? "info.circle.fill" : "info.circle")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .background(Color.black.opacity(0.55))
                    .cornerRadius(21)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 56)
        .padding(.bottom, 12)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.6), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
