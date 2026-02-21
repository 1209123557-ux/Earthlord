//
//  POIListView.swift
//  Earthlord
//
//  附近兴趣点列表页面
//  数据来源：MockExplorationData（假数据，待后端接入后替换）
//

import SwiftUI

// MARK: - POI 类型样式（图标 + 颜色）

private struct POITypeStyle {
    let color: Color
    let icon: String
}

private func typeStyle(for type: String) -> POITypeStyle {
    switch type {
    case "医院":   return POITypeStyle(color: .red,    icon: "cross.case.fill")
    case "超市":   return POITypeStyle(color: .green,  icon: "cart.fill")
    case "工厂":   return POITypeStyle(color: .gray,   icon: "building.2.fill")
    case "药店":   return POITypeStyle(color: .purple, icon: "pills.fill")
    case "加油站": return POITypeStyle(color: .orange, icon: "fuelpump.fill")
    default:       return POITypeStyle(color: ApocalypseTheme.primary, icon: "mappin.fill")
    }
}

// MARK: - POIListView

struct POIListView: View {

    // MARK: - 状态
    @State private var isSearching = false
    @State private var selectedCategory = "全部"

    // MARK: - 假数据
    /// 模拟 GPS 坐标（真实接入后改为 locationManager.userLocation）
    private let mockLatitude  = 22.54
    private let mockLongitude = 114.06

    /// 筛选分类列表
    private let categories = ["全部", "医院", "超市", "工厂", "药店", "加油站"]

    /// 已发现的 POI 数量（状态不为 undiscovered）
    private var discoveredCount: Int {
        MockPOIData.list.filter { $0.status != .undiscovered }.count
    }

    /// 当前分类筛选后的 POI 列表
    private var filteredPOIs: [POI] {
        guard selectedCategory != "全部" else { return MockPOIData.list }
        return MockPOIData.list.filter { $0.type == selectedCategory }
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            VStack(spacing: 12) {
                statusBar
                searchButton
                filterBar
                poiScrollList
            }
            .padding(.top, 12)
        }
        .navigationTitle("附近探索")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - 状态栏（GPS + 发现数量）
    private var statusBar: some View {
        ELCard(padding: EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)) {
            HStack {
                // GPS 坐标
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 13))
                        .foregroundColor(ApocalypseTheme.info)
                    Text(String(format: "%.2f°N  %.2f°E", mockLatitude, mockLongitude))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                Spacer()

                // 发现数量
                HStack(spacing: 5) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 13))
                        .foregroundColor(ApocalypseTheme.primary)
                    Text("附近发现 \(discoveredCount) 个地点")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - 搜索按钮
    private var searchButton: some View {
        Button(action: triggerSearch) {
            HStack(spacing: 10) {
                if isSearching {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.85)
                    Text("搜索中...")
                        .font(.system(size: 15, weight: .semibold))
                } else {
                    Image(systemName: "radar")
                        .font(.system(size: 16))
                    Text("搜索附近 POI")
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                isSearching
                    ? ApocalypseTheme.primary.opacity(0.6)
                    : ApocalypseTheme.primary
            )
            .cornerRadius(14)
            .shadow(color: ApocalypseTheme.primary.opacity(0.35), radius: 6, x: 0, y: 3)
        }
        .disabled(isSearching)
        .padding(.horizontal, 16)
    }

    // MARK: - 筛选工具栏（横向滚动）
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { category in
                    filterChip(category)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func filterChip(_ category: String) -> some View {
        let isSelected = selectedCategory == category
        // 分类对应颜色（全部用主题橙色）
        let accentColor: Color = category == "全部"
            ? ApocalypseTheme.primary
            : typeStyle(for: category).color

        return Button(action: { selectedCategory = category }) {
            Text(category)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : ApocalypseTheme.textSecondary)
                .padding(.horizontal, 14)
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

    // MARK: - POI 列表
    private var poiScrollList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if filteredPOIs.isEmpty {
                    emptyState
                } else {
                    ForEach(filteredPOIs) { poi in
                        NavigationLink(destination: POIDetailView(poi: poi)) {
                            POICard(poi: poi)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    // MARK: - 空状态
    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 44))
                .foregroundColor(ApocalypseTheme.textMuted)
            Text("该分类暂无地点")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - 搜索逻辑（1.5 秒模拟）
    private func triggerSearch() {
        isSearching = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isSearching = false
        }
    }
}

// MARK: - POICard（单条 POI 卡片）

private struct POICard: View {
    let poi: POI

    var body: some View {
        ELCard(padding: EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)) {
            HStack(spacing: 14) {
                typeIcon
                infoColumn
                Spacer()
                rightBadge
            }
        }
    }

    // 左侧类型图标
    private var typeIcon: some View {
        let style = typeStyle(for: poi.type)
        return ZStack {
            Circle()
                .fill(style.color.opacity(poi.status == .undiscovered ? 0.12 : 0.18))
                .frame(width: 46, height: 46)
            Image(systemName: poi.status == .undiscovered ? "questionmark" : style.icon)
                .font(.system(size: 18))
                .foregroundColor(poi.status == .undiscovered ? ApocalypseTheme.textMuted : style.color)
        }
    }

    // 中间信息列
    private var infoColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 名称
            Text(poi.status == .undiscovered ? "???" : poi.name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(poi.status == .undiscovered
                    ? ApocalypseTheme.textMuted
                    : ApocalypseTheme.textPrimary)

            // 类型 + 发现状态
            HStack(spacing: 6) {
                Text(poi.status == .undiscovered ? "未知地点" : poi.type)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                if poi.status != .undiscovered {
                    Text("·")
                        .foregroundColor(ApocalypseTheme.textMuted)
                    statusLabel
                }
            }
        }
    }

    // 发现状态标签
    private var statusLabel: some View {
        switch poi.status {
        case .undiscovered:
            return Text("").font(.caption).foregroundColor(.clear)
        case .discovered:
            return Text("已发现")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.success)
        case .looted:
            return Text("已搜空")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)
        }
    }

    // 右侧物资/箭头徽章
    @ViewBuilder
    private var rightBadge: some View {
        if poi.status == .undiscovered {
            Image(systemName: "lock.fill")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textMuted)
        } else if poi.hasLoot {
            VStack(spacing: 2) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.warning)
                Text("有物资")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(ApocalypseTheme.warning)
            }
        } else {
            VStack(spacing: 2) {
                Image(systemName: "shippingbox")
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textMuted)
                Text("已搜空")
                    .font(.system(size: 10))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        POIListView()
    }
}
