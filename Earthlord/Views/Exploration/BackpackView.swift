//
//  BackpackView.swift
//  Earthlord
//
//  背包管理页面
//  数据来源：MockExplorationData（假数据，待后端接入后替换）
//

import SwiftUI

// MARK: - 背包物品样式辅助

/// 根据物品分类返回图标名称和颜色
private func categoryStyle(for category: ItemCategory) -> (icon: String, color: Color) {
    switch category {
    case .water:    return ("drop.fill",    .blue)
    case .food:     return ("fork.knife",   .orange)
    case .medical:  return ("cross.fill",   .red)
    case .material: return ("cube.fill",    Color(red: 0.6, green: 0.45, blue: 0.3))
    case .tool:     return ("wrench.fill",  .yellow)
    }
}

/// 根据稀有度返回标签文字和颜色
private func rarityStyle(for rarity: ItemRarity) -> (label: String, color: Color) {
    switch rarity {
    case .common:   return ("普通", Color(white: 0.5))
    case .uncommon: return ("优秀", ApocalypseTheme.success)
    case .rare:     return ("稀有", ApocalypseTheme.info)
    // 史诗（紫色）：当前 mock 数据暂未使用，颜色预留
    }
}

// MARK: - BackpackView

struct BackpackView: View {

    // MARK: - 状态
    @State private var searchText = ""
    @State private var selectedCategory = "全部"

    // MARK: - Mock 容量（真实接入后改为从背包模型读取）
    private let mockMax     = 100
    private let mockCurrent = 64

    // MARK: - 筛选分类（标签 + 图标）
    private let filterCategories: [(label: String, icon: String)] = [
        ("全部",   "square.grid.2x2.fill"),
        ("食物",   "fork.knife"),
        ("水",     "drop.fill"),
        ("材料",   "cube.fill"),
        ("工具",   "wrench.fill"),
        ("医疗",   "cross.fill"),
    ]

    // MARK: - 筛选后的物品列表
    private var filteredItems: [InventoryItem] {
        MockInventoryData.items.filter { item in
            let def = MockItemDefinitions.find(item.itemId)

            // 分类筛选：全部 = 不过滤
            let categoryOK = selectedCategory == "全部"
                || def?.category.rawValue == selectedCategory

            // 搜索筛选：空字符串 = 不过滤
            let searchOK = searchText.isEmpty
                || item.displayName.localizedCaseInsensitiveContains(searchText)

            return categoryOK && searchOK
        }
    }

    // MARK: - 容量相关
    private var capacityPercent: Double {
        Double(mockCurrent) / Double(mockMax)
    }

    private var capacityBarColor: Color {
        if capacityPercent < 0.7 { return ApocalypseTheme.success }
        if capacityPercent < 0.9 { return ApocalypseTheme.warning }
        return ApocalypseTheme.danger
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            VStack(spacing: 12) {
                capacityCard
                searchSection
                categoryFilterBar
                itemScrollList
            }
            .padding(.top, 12)
        }
        .navigationTitle("背包")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - 容量状态卡

    private var capacityCard: some View {
        ELCard(padding: EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)) {
            VStack(spacing: 10) {
                // 标题行
                HStack {
                    Label("背包容量", systemImage: "backpack.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    Spacer()
                    Text("\(mockCurrent) / \(mockMax)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(capacityBarColor)
                }

                // 进度条
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // 背景轨道
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 8)
                        // 填充
                        RoundedRectangle(cornerRadius: 4)
                            .fill(capacityBarColor)
                            .frame(width: geo.size.width * capacityPercent, height: 8)
                            .animation(.easeOut(duration: 0.4), value: capacityPercent)
                    }
                }
                .frame(height: 8)

                // 超过 90% 时显示警告
                if capacityPercent >= 0.9 {
                    HStack(spacing: 5) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                        Text("背包快满了！")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(ApocalypseTheme.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - 搜索框

    private var searchSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textMuted)

            TextField("", text: $searchText,
                      prompt: Text("搜索物品名称").foregroundColor(ApocalypseTheme.textMuted))
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
        .padding(.horizontal, 16)
    }

    // MARK: - 分类筛选栏（横向滚动，带图标）

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
        // 选中时用该分类对应颜色，未选中统一用 textMuted
        let accentColor: Color = {
            switch label {
            case "食物":  return .orange
            case "水":    return .blue
            case "材料":  return Color(red: 0.6, green: 0.45, blue: 0.3)
            case "工具":  return .yellow
            case "医疗":  return .red
            default:      return ApocalypseTheme.primary
            }
        }()

        return Button(action: {
            withAnimation(.easeInOut(duration: 0.22)) { selectedCategory = label }
        }) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
            }
            .foregroundColor(isSelected ? .white : ApocalypseTheme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? accentColor : ApocalypseTheme.cardBackground)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? accentColor : Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 物品列表

    private var itemScrollList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if filteredItems.isEmpty {
                    emptyState
                        .transition(.opacity)
                } else {
                    ForEach(filteredItems) { item in
                        BackpackItemRow(item: item)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                removal:   .opacity
                            ))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            // 整体动画：分类切换时平滑过渡
            .animation(.easeInOut(duration: 0.22), value: selectedCategory)
        }
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "bag.slash")
                .font(.system(size: 44))
                .foregroundColor(ApocalypseTheme.textMuted)
            Text(searchText.isEmpty ? "该分类暂无物品" : "未找到「\(searchText)」")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

// MARK: - BackpackItemRow（单条物品行）

private struct BackpackItemRow: View {
    let item: InventoryItem

    private var definition: ItemDefinition? {
        MockItemDefinitions.find(item.itemId)
    }

    var body: some View {
        ELCard(padding: EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)) {
            HStack(spacing: 12) {
                itemIcon
                infoColumn
                Spacer(minLength: 6)
                actionButtons
            }
        }
    }

    // 左侧：分类图标圆形背景
    private var itemIcon: some View {
        let (icon, color) = definition.map { categoryStyle(for: $0.category) }
            ?? ("questionmark", ApocalypseTheme.textMuted)

        return ZStack {
            Circle()
                .fill(color.opacity(0.18))
                .frame(width: 44, height: 44)
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
        }
    }

    // 中间：物品详情
    private var infoColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 第一行：名称 + 数量
            HStack(spacing: 6) {
                Text(item.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Text("×\(item.quantity)")
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 第二行：重量 + 品质
            HStack(spacing: 8) {
                if let def = definition {
                    Text(String(format: "%.1fkg", def.weightKg * Double(item.quantity)))
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
                if let quality = item.qualityPercent {
                    qualityBadge(quality)
                }
            }

            // 第三行：稀有度标签
            if let def = definition {
                let (label, color) = rarityStyle(for: def.rarity)
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(color)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(color.opacity(0.15))
                    .cornerRadius(5)
            }
        }
    }

    // 品质标签（带颜色渐变：绿→黄→红）
    private func qualityBadge(_ percent: Int) -> some View {
        let color: Color = percent >= 70 ? ApocalypseTheme.success
                         : percent >= 40 ? ApocalypseTheme.warning
                         : ApocalypseTheme.danger
        return Text("品质 \(percent)%")
            .font(.caption)
            .foregroundColor(color)
    }

    // 右侧：操作按钮
    private var actionButtons: some View {
        VStack(spacing: 6) {
            actionButton(title: "使用", color: ApocalypseTheme.primary) {
                print("使用物品：\(item.displayName)（id: \(item.itemId)）")
            }
            actionButton(title: "存储", color: ApocalypseTheme.info) {
                print("存储物品：\(item.displayName)（id: \(item.itemId)）")
            }
        }
    }

    private func actionButton(title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 44, height: 26)
                .background(color)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BackpackView()
    }
}
