//
//  ExplorationTestView.swift
//  Earthlord
//
//  探索功能测试界面 - 显示实时调试日志
//  ⚠️ 不套 NavigationStack，由父级 NavigationView 提供导航栈
//

import SwiftUI

struct ExplorationTestView: View {

    @ObservedObject private var logger = ExplorationLogger.shared

    var body: some View {
        VStack(spacing: 0) {
            // 日志条数状态栏
            statusBar
                .padding(.horizontal)
                .padding(.vertical, 10)
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
        .navigationTitle("探索测试")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(UIColor.systemBackground))
        .onAppear {
            ExplorationLogger.shared.log("测试界面已打开")
        }
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(logger.logs.isEmpty ? Color.gray : Color.green)
                .frame(width: 12, height: 12)

            Text(logger.logs.isEmpty ? "暂无日志" : "已记录 \(logger.logs.count) 条")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(logger.logs.isEmpty ? .secondary : .primary)

            Spacer()

            if let last = logger.logs.last {
                Text("最新: \(timeString(last.timestamp))")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Log Scroll View

    private var logScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(logger.logText.isEmpty
                     ? "暂无日志\n\n开始探索后，日志将实时显示在这里。"
                     : logger.logText)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(logger.logText.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .id("logBottom")
            }
            .onChange(of: logger.logText) { _ in
                withAnimation {
                    proxy.scrollTo("logBottom", anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Bottom Buttons

    private var bottomButtons: some View {
        HStack(spacing: 16) {
            Button(action: { logger.clear() }) {
                Label("清空日志", systemImage: "trash")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(8)
            }

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

    // MARK: - Helper

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }
}

#Preview {
    NavigationView {
        ExplorationTestView()
    }
}
