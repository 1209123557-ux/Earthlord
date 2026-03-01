//
//  ResourceRow.swift
//  Earthlord
//
//  建造资源需求行：显示物品名、需求量、库存量（足够=绿，不足=红）
//

import SwiftUI

struct ResourceRow: View {
    let itemId: String
    let required: Int
    let available: Int

    private var isSufficient: Bool { available >= required }

    private var displayName: String {
        MockItemDefinitions.find(itemId)?.displayName ?? itemId
    }

    var body: some View {
        HStack(spacing: 12) {
            // 物品图标
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSufficient ? ApocalypseTheme.success.opacity(0.15) : ApocalypseTheme.danger.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: "cube.fill")
                    .font(.system(size: 14))
                    .foregroundColor(isSufficient ? ApocalypseTheme.success : ApocalypseTheme.danger)
            }

            // 物品名
            Text(displayName)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            // 数量：现有 / 需要
            HStack(spacing: 4) {
                Text("\(available)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSufficient ? ApocalypseTheme.success : ApocalypseTheme.danger)
                Text("/")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textMuted)
                Text("\(required)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 状态图标
            Image(systemName: isSufficient ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(isSufficient ? ApocalypseTheme.success : ApocalypseTheme.danger)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
