//
//  EarthlordApp.swift
//  Earthlord
//
//  Created by 许意晗 on 2026/2/6.
//

import SwiftUI

@main
struct EarthlordApp: App {
    @StateObject private var languageManager = LanguageManager.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.locale, languageManager.currentLocale)
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .background {
                Task { await PlayerLocationManager.shared.markOffline() }
            }
        }
    }
}
