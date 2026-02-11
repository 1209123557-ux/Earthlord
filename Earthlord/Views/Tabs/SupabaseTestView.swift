//
//  SupabaseTestView.swift
//  Earthlord
//
//  Created by 许意晗 on 2026/2/10.
//

import SwiftUI
import Supabase

struct SupabaseTestView: View {
    @State private var connectionStatus: ConnectionStatus = .idle
    @State private var logMessage: String = "点击按钮开始测试连接..."

    enum ConnectionStatus {
        case idle
        case testing
        case success
        case failure
    }

    var body: some View {
        VStack(spacing: 24) {
            // 标题
            Text("Supabase 连接测试")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top, 40)

            // 状态图标
            statusIcon
                .font(.system(size: 80))
                .padding(.vertical, 20)

            // 日志文本框
            ScrollView {
                Text(logMessage)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
            .frame(height: 300)
            .padding(.horizontal)

            // 测试连接按钮
            Button(action: testConnection) {
                HStack {
                    if connectionStatus == .testing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    Text(connectionStatus == .testing ? "测试中..." : "测试连接")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(connectionStatus == .testing ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(connectionStatus == .testing)
            .padding(.horizontal)

            Spacer()
        }
        .navigationTitle("Supabase 测试")
        .navigationBarTitleDisplayMode(.inline)
    }

    // 状态图标
    @ViewBuilder
    private var statusIcon: some View {
        switch connectionStatus {
        case .idle:
            Image(systemName: "network")
                .foregroundColor(.gray)
        case .testing:
            ProgressView()
                .scaleEffect(2)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .failure:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
        }
    }

    // 测试连接逻辑
    private func testConnection() {
        connectionStatus = .testing
        logMessage = "正在测试连接...\n\n"

        Task {
            do {
                logMessage += "尝试连接到: https://pxcogttskwqgdwwrarox.supabase.co\n"
                logMessage += "查询不存在的表以验证连接...\n\n"

                // 使用 v2.0 语法：故意查询一个不存在的表
                let _: [String] = try await supabase
                    .from("non_existent_table")
                    .select()
                    .execute()
                    .value

                // 如果没有错误,说明表存在(不应该发生)
                logMessage += "意外：查询成功，但应该失败\n"
                connectionStatus = .failure

            } catch {
                // 捕获错误并分析
                let errorMessage = error.localizedDescription
                logMessage += "收到错误响应:\n\(errorMessage)\n\n"

                // 判断错误类型
                if errorMessage.contains("PGRST") ||
                   errorMessage.contains("PGRST205") ||
                   errorMessage.contains("Could not find the table") ||
                   errorMessage.contains("relation") && errorMessage.contains("does not exist") {
                    // 这些错误说明连接成功，只是表不存在
                    logMessage += "✅ 连接成功（服务器已响应）\n"
                    logMessage += "服务器能够处理请求，说明配置正确！\n"
                    connectionStatus = .success

                } else if errorMessage.contains("hostname") ||
                          errorMessage.contains("URL") ||
                          errorMessage.contains("NSURLErrorDomain") {
                    // 网络或 URL 错误
                    logMessage += "❌ 连接失败：URL 错误或无网络\n"
                    logMessage += "请检查网络连接或 Supabase URL 配置\n"
                    connectionStatus = .failure

                } else {
                    // 其他未知错误
                    logMessage += "⚠️ 其他错误:\n\(errorMessage)\n"
                    connectionStatus = .failure
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        SupabaseTestView()
    }
}
