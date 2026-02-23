//
//  ExplorationLogger.swift
//  Earthlord
//
//  探索功能调试日志管理器
//  真机测试时在 App 内查看运行日志，脱离 Xcode 也能使用
//

import Foundation
import Combine

// MARK: - ExplorationLogger

/// 探索日志管理器（单例）
class ExplorationLogger: ObservableObject {

    // MARK: - Singleton
    static let shared = ExplorationLogger()
    private init() {}

    // MARK: - Published Properties
    @Published var logs: [LogEntry] = []
    @Published var logText: String = ""

    // MARK: - Constants
    private let maxLogCount = 300

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
    func log(_ message: String, type: LogType = .info) {
        DispatchQueue.main.async {
            let entry = LogEntry(timestamp: Date(), message: message, type: type)
            self.logs.append(entry)
            if self.logs.count > self.maxLogCount {
                self.logs.removeFirst(self.logs.count - self.maxLogCount)
            }
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
    func export() -> String {
        let now = exportFormatter.string(from: Date())
        var result = """
        === 探索功能测试日志 ===
        导出时间: \(now)
        日志条数: \(logs.count)

        """
        for entry in logs {
            let time = exportFormatter.string(from: entry.timestamp)
            result += "[\(time)] [\(entry.type.rawValue)] \(entry.message)\n"
        }
        return result
    }

    // MARK: - Private

    private func updateLogText(entry: LogEntry) {
        let time = displayFormatter.string(from: entry.timestamp)
        let line = "[\(time)] [\(entry.type.rawValue)] \(entry.message)\n"
        logText += line
    }
}
