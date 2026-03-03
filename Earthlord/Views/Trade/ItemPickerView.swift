//
//  ItemPickerView.swift
//  Earthlord
//
//  物品选择器 Sheet，供 CreateOfferView 中"我要出"和"我想要"两种场景复用。
//

import SwiftUI

// MARK: - 选择模式

enum ItemPickerMode {
    case fromInventory   // 只显示库存中有的物品，数量上限=库存数量
    case allItems        // 显示全部 15 种物品，数量无上限
}

// MARK: - ItemPickerView

struct ItemPickerView: View {

    let mode: ItemPickerMode
    let onSelect: (String, Int) -> Void   // (itemId, quantity)

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var inventoryManager: InventoryManager

    @State private var searchText = ""
    @State private var selectedCategory = "全部"
    @State private var quantityTarget: ItemDefinition? = nil
    @State private var quantityMax: Int = 99
    @State private var quantity: Int = 1

    private let filterCategories: [(label: String, icon: String)] = [
        ("全部",   "square.grid.2x2.fill"),
        ("食物",   "fork.knife"),
        ("水",     "drop.fill"),
        ("材料",   "cube.fill"),
        ("工具",   "wrench.fill"),
        ("医疗",   "cross.fill"),
    ]

    // 根据模式决定显示哪些物品
    private var displayItems: [ItemDefinition] {
        switch mode {
        case .allItems:
            return MockItemDefinitions.table
        case .fromInventory:
            return inventoryManager.items.compactMap { inv in
                MockItemDefinitions.find(inv.itemId)
            }
        }
    }

    private var filteredItems: [ItemDefinition] {
        displayItems.filter { def in
            let categoryOK = selectedCategory == "全部"
                || def.category.rawValue == selectedCategory
            let searchOK = searchText.isEmpty
                || def.displayName.localizedCaseInsensitiveContains(searchText)
            return categoryOK && searchOK
        }
    }

    // 从库存查找某物品的库存数量
    private func inventoryQuantity(for itemId: String) -> Int {
        inventoryManager.items.first(where: { $0.itemId == itemId })?.quantity ?? 0
    }

    var body: some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部标题栏
                HStack {
                    Text(mode == .fromInventory ? "选择出售物品" : "选择想要物品")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Spacer()
                    Button("取消") { dismiss() }
                        .font(.system(size: 15))
                        .foregroundColor(ApocalypseTheme.primary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 12)

                // 搜索框
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)

                // 分类筛选
                categoryFilterBar
                    .padding(.bottom, 10)

                // 物品网格
                itemGrid
            }

            // 数量选择弹窗
            if let def = quantityTarget {
                quantityPopup(for: def)
            }
        }
    }

    // MARK: - 搜索框

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textMuted)
            TextField("", text: $searchText,
                      prompt: Text("搜索物品").foregroundColor(ApocalypseTheme.textMuted))
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 分类筛选栏

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filterCategories, id: \.label) { cat in
                    categoryChip(label: cat.label, icon: cat.icon)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func categoryChip(label: String, icon: String) -> some View {
        let isSelected = selectedCategory == label
        let accentColor: Color = {
            switch label {
            case "食物": return .orange
            case "水":   return .blue
            case "材料": return Color(red: 0.6, green: 0.45, blue: 0.3)
            case "工具": return .yellow
            case "医疗": return .red
            default:     return ApocalypseTheme.primary
            }
        }()
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) { selectedCategory = label }
        }) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11))
                Text(label).font(.system(size: 12, weight: isSelected ? .semibold : .regular))
            }
            .foregroundColor(isSelected ? .white : ApocalypseTheme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? accentColor : ApocalypseTheme.cardBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? accentColor : Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 物品网格（3 列）

    private var itemGrid: some View {
        ScrollView {
            if filteredItems.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(filteredItems) { def in
                        itemCell(def)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }

    private func itemCell(_ def: ItemDefinition) -> some View {
        let (icon, color) = categoryIconColor(def.category)
        let invQty = inventoryQuantity(for: def.id)
        let isDisabled = mode == .fromInventory && invQty == 0

        return Button(action: {
            guard !isDisabled else { return }
            quantityMax = mode == .fromInventory ? invQty : 999
            quantity = 1
            quantityTarget = def
        }) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(color.opacity(isDisabled ? 0.06 : 0.18))
                        .frame(width: 46, height: 46)
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(isDisabled ? ApocalypseTheme.textMuted : color)
                }
                Text(def.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isDisabled ? ApocalypseTheme.textMuted : ApocalypseTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                if mode == .fromInventory {
                    Text("库存 \(invQty)")
                        .font(.system(size: 10))
                        .foregroundColor(invQty > 0 ? ApocalypseTheme.textSecondary : ApocalypseTheme.textMuted)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isDisabled ? Color.clear : Color.white.opacity(0.07), lineWidth: 1)
            )
            .opacity(isDisabled ? 0.45 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    // MARK: - 数量选择弹窗

    private func quantityPopup(for def: ItemDefinition) -> some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { quantityTarget = nil }

            VStack(spacing: 16) {
                Text("选择数量")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(def.displayName)
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                if mode == .fromInventory {
                    Text("库存: \(quantityMax)")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }

                // 数量调节行
                HStack(spacing: 20) {
                    Button(action: { if quantity > 1 { quantity -= 1 } }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(quantity > 1 ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                    }
                    .buttonStyle(.plain)

                    Text("\(quantity)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .frame(minWidth: 50)

                    Button(action: { if quantity < quantityMax { quantity += 1 } }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(quantity < quantityMax ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 12) {
                    Button("取消") {
                        quantityTarget = nil
                    }
                    .font(.system(size: 15))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(10)
                    .buttonStyle(.plain)

                    Button("确定") {
                        onSelect(def.id, quantity)
                        quantityTarget = nil
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(10)
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(18)
            .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 8)
            .padding(.horizontal, 40)
        }
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "cube.transparent")
                .font(.system(size: 48))
                .foregroundColor(ApocalypseTheme.textMuted)
            Text(searchText.isEmpty ? "没有可选物品" : "没有找到相关物品")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 300)
    }

    // MARK: - Helper

    private func categoryIconColor(_ category: ItemCategory) -> (String, Color) {
        switch category {
        case .water:    return ("drop.fill",   .blue)
        case .food:     return ("fork.knife",  .orange)
        case .medical:  return ("cross.fill",  .red)
        case .material: return ("cube.fill",   Color(red: 0.6, green: 0.45, blue: 0.3))
        case .tool:     return ("wrench.fill", .yellow)
        }
    }
}
