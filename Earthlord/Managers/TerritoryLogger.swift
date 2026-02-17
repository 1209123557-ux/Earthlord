//
//  TerritoryLogger.swift
//  Earthlord
//
//  圈地功能调试日志管理器
//  真机测试时在 App 内查看运行日志，脱离 Xcode 也能使用
//

import Foundation
import Combine  // ⚠️ @Published 和 ObservableObject 需要这个框架

// MARK: - LogType
/// 日志类型枚举
enum LogType: String {
    case info    = "INFO"
    case success = "SUCCESS"
    case warning = "WARNING"
    case error   = "ERROR"
}

// MARK: - LogEntry
/// 日志条目
struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let type: LogType
}

// MARK: - TerritoryLogger
/// 圈地日志管理器（单例）
class TerritoryLogger: ObservableObject {

    // MARK: - Singleton
    static let shared = TerritoryLogger()
    private init() {}

    // MARK: - Published Properties
    @Published var logs: [LogEntry] = []
    @Published var logText: String = ""

    // MARK: - Constants
    private let maxLogCount = 200  // 最大条数，防止内存溢出

    // MARK: - Formatters
    private let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    private let exportFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    // MARK: - Public Methods

    /// 添加日志
    /// - Parameters:
    ///   - message: 日志内容
    ///   - type: 日志类型（默认 info）
    func log(_ message: String, type: LogType = .info) {
        // 确保在主线程更新 UI
        DispatchQueue.main.async {
            let entry = LogEntry(timestamp: Date(), message: message, type: type)

            // 添加新日志
            self.logs.append(entry)

            // 超出最大条数时移除最旧的日志
            if self.logs.count > self.maxLogCount {
                self.logs.removeFirst(self.logs.count - self.maxLogCount)
            }

            // 更新格式化文本（用于 UI 显示）
            self.updateLogText(entry: entry)
        }
    }

    /// 清空所有日志
    func clear() {
        DispatchQueue.main.async {
            self.logs.removeAll()
            self.logText = ""
        }
    }

    /// 导出日志为文本
    /// - Returns: 包含头信息的完整日志文本
    func export() -> String {
        let now = exportFormatter.string(from: Date())
        var result = """
        === 圈地功能测试日志 ===
        导出时间: \(now)
        日志条数: \(logs.count)

        """

        for entry in logs {
            let time = exportFormatter.string(from: entry.timestamp)
            result += "[\(time)] [\(entry.type.rawValue)] \(entry.message)\n"
        }

        return result
    }

    // MARK: - Private Methods

    /// 更新格式化日志文本
    private func updateLogText(entry: LogEntry) {
        let time = displayFormatter.string(from: entry.timestamp)
        let line = "[\(time)] [\(entry.type.rawValue)] \(entry.message)\n"
        logText += line
    }
}
