//
//  CategoryButton.swift
//  Earthlord
//
//  建筑分类选择按钮（nil = 全部）
//

import SwiftUI

struct CategoryButton: View {
    let category: BuildingCategory?
    let isSelected: Bool
    let onTap: () -> Void

    var label: String {
        category?.displayName ?? "全部"
    }

    var icon: String {
        category?.icon ?? "square.grid.2x2.fill"
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : ApocalypseTheme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? ApocalypseTheme.primary : Color.white.opacity(0.08))
            .cornerRadius(18)
        }
    }
}
