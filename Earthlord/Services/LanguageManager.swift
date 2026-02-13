//
//  LanguageManager.swift
//  Earthlord
//
//  Created by 许意晗 on 2026/2/13.
//

import Foundation
import Combine

/// App 内语言选项
enum AppLanguage: String, CaseIterable {
    case system = "system"
    case zhHans = "zh-Hans"
    case en = "en"

    /// 显示名称（固定不翻译，方便用户识别）
    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .zhHans: return "简体中文"
        case .en: return "English"
        }
    }
}

/// 语言管理器：管理 App 内语言切换，持久化用户选择
@MainActor
class LanguageManager: ObservableObject {

    // MARK: - 单例

    static let shared = LanguageManager()

    // MARK: - 持久化 key

    private let storageKey = "appLanguage"

    // MARK: - 发布属性

    @Published var currentLanguage: AppLanguage = .system

    // MARK: - 计算属性

    /// 根据用户选择返回对应的 Locale
    var currentLocale: Locale {
        switch currentLanguage {
        case .system:
            return Locale.current
        case .zhHans:
            return Locale(identifier: "zh-Hans")
        case .en:
            return Locale(identifier: "en")
        }
    }

    // MARK: - 初始化

    private init() {
        // 从 UserDefaults 恢复上次选择
        if let raw = UserDefaults.standard.string(forKey: storageKey),
           let saved = AppLanguage(rawValue: raw) {
            currentLanguage = saved
        }
    }

    // MARK: - 方法

    /// 切换语言
    func setLanguage(_ language: AppLanguage) {
        currentLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: storageKey)
    }
}
