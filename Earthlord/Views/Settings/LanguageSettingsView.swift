//
//  LanguageSettingsView.swift
//  Earthlord
//
//  Created by 许意晗 on 2026/2/13.
//

import SwiftUI

/// 语言设置页面：选择 App 显示语言
struct LanguageSettingsView: View {
    @ObservedObject private var languageManager = LanguageManager.shared

    var body: some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Button {
                            languageManager.setLanguage(language)
                        } label: {
                            HStack {
                                Text(language.displayName)
                                    .font(.system(size: 15))
                                    .foregroundColor(ApocalypseTheme.textPrimary)

                                Spacer()

                                if languageManager.currentLanguage == language {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(ApocalypseTheme.primary)
                                        .font(.system(size: 14, weight: .semibold))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }

                        if language != AppLanguage.allCases.last {
                            Divider().background(Color.white.opacity(0.06))
                        }
                    }
                }
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
        .navigationTitle("语言设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        LanguageSettingsView()
    }
}
