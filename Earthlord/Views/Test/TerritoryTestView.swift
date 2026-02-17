//
//  TerritoryTestView.swift
//  Earthlord
//
//  圈地功能测试界面 - 显示实时调试日志
//  ⚠️ 不套 NavigationStack，由父级 NavigationView 提供导航栈
//

import SwiftUI

struct TerritoryTestView: View {
    // MARK: - Dependencies
    @EnvironmentObject var locationManager: LocationManager
    @ObservedObject var logger = TerritoryLogger.shared

    var body: some View {
        VStack(spacing: 0) {
            // 追踪状态指示器
            statusIndicator
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.secondarySystemBackground))

            Divider()

            // 日志滚动区域
            logScrollView

            Divider()

            // 底部操作按钮
            bottomButtons
                .padding()
        }
        .navigationTitle("圈地测试")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(UIColor.systemBackground))
    }

    // MARK: - Status Indicator
    /// 追踪状态指示器
    private var statusIndicator: some View {
        HStack(spacing: 8) {
            // 状态圆点
            Circle()
                .fill(locationManager.isTracking ? Color.green : Color.gray)
                .frame(width: 12, height: 12)

            // 状态文字
            Text(locationManager.isTracking ? "追踪中" : "未追踪")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(locationManager.isTracking ? .green : .secondary)

            Spacer()

            // 路径点数（追踪时显示）
            if locationManager.isTracking {
                Text("已记录 \(locationManager.pathCoordinates.count) 个点")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            // 闭环标识
            if locationManager.isPathClosed {
                Label("已闭环", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.green)
            }
        }
    }

    // MARK: - Log Scroll View
    /// 日志滚动区域，自动滚动到底部
    private var logScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(logger.logText.isEmpty ? "暂无日志\n\n开始圈地追踪后，日志将实时显示在这里。" : logger.logText)
                    .font(.system(size: 12, design: .monospaced))  // 等宽字体
                    .foregroundColor(logger.logText.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .id("logBottom")
            }
            // 日志更新时自动滚动到底部
            .onChange(of: logger.logText) { _ in
                withAnimation {
                    proxy.scrollTo("logBottom", anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Bottom Buttons
    /// 底部清空和导出按钮
    private var bottomButtons: some View {
        HStack(spacing: 16) {
            // 清空按钮
            Button(action: {
                logger.clear()
            }) {
                Label("清空日志", systemImage: "trash")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.gray.opacity(0.8))
                    .cornerRadius(8)
            }

            // 导出按钮（使用 ShareLink）
            ShareLink(item: logger.export()) {
                Label("导出日志", systemImage: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(8)
            }
        }
    }
}

#Preview {
    NavigationView {
        TerritoryTestView()
            .environmentObject(LocationManager())
    }
}
