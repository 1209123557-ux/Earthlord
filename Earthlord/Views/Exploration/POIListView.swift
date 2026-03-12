//
//  POIListView.swift
//  Earthlord
//
//  附近兴趣点列表页面
//  数据来源：POISearchManager（MapKit 真实搜索）
//

import SwiftUI
import CoreLocation

// MARK: - 类型颜色映射

private func typeColor(for type: GamePOIType) -> Color {
    switch type {
    case .hospital:   return .red
    case .pharmacy:   return .purple
    case .store:      return .green
    case .gasStation: return .orange
    case .restaurant: return Color(red: 0.9, green: 0.6, blue: 0.2)
    case .cafe:       return Color(red: 0.6, green: 0.4, blue: 0.2)
    case .unknown:    return ApocalypseTheme.primary
    }
}

private func categoryColor(for category: String) -> Color {
    switch category {
    case "医院":   return .red
    case "药店":   return .purple
    case "商店":   return .green
    case "加油站": return .orange
    case "餐厅":   return Color(red: 0.9, green: 0.6, blue: 0.2)
    case "咖啡馆": return Color(red: 0.6, green: 0.4, blue: 0.2)
    default:       return ApocalypseTheme.primary
    }
}

// MARK: - POIListView

struct POIListView: View {

    // MARK: - 状态
    @ObservedObject private var locationManager = LocationManager.shared
    @State private var searchResults: [GamePOI] = []
    @State private var hasSearched    = false
    @State private var searchError: String? = nil
    @State private var isSearching    = false
    @State private var selectedCategory = "全部"
    @State private var listVisible    = false
    @State private var searchScaled   = false

    // MARK: - 配置
    private let categories = ["全部", "医院", "药店", "商店", "加油站", "餐厅", "咖啡馆"]

    private var filteredPOIs: [GamePOI] {
        guard selectedCategory != "全部" else { return searchResults }
        return searchResults.filter { $0.poiType.displayName == selectedCategory }
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
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 13))
                        .foregroundColor(ApocalypseTheme.info)
                    if let coord = locationManager.userLocation {
                        Text(String(format: "%.4f°N  %.4f°E",
                                    coord.latitude, coord.longitude))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    } else {
                        Text("定位中...")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                }

                Spacer()

                HStack(spacing: 5) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 13))
                        .foregroundColor(ApocalypseTheme.primary)
                    Text("附近发现 \(searchResults.count) 个地点")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - 搜索按钮
    private var searchButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) { searchScaled = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { searchScaled = false }
            }
            triggerSearch()
        }) {
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
        .scaleEffect(searchScaled ? 0.94 : 1.0)
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
        let accentColor = categoryColor(for: category)

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
                if let error = searchError {
                    stateView(icon: "exclamationmark.triangle",
                              title: "搜索失败",
                              subtitle: error)
                } else if filteredPOIs.isEmpty {
                    emptyState
                } else {
                    ForEach(Array(filteredPOIs.enumerated()), id: \.element.id) { idx, poi in
                        NavigationLink(destination: POIDetailView(poi: poi)) {
                            GamePOICard(poi: poi)
                        }
                        .buttonStyle(.plain)
                        .opacity(listVisible ? 1 : 0)
                        .offset(y: listVisible ? 0 : 12)
                        .animation(
                            .easeOut(duration: 0.32).delay(Double(min(idx, 5)) * 0.07),
                            value: listVisible
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .onAppear {
            guard !listVisible else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                listVisible = true
            }
        }
        .onChange(of: selectedCategory) { _ in
            listVisible = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                listVisible = true
            }
        }
    }

    // MARK: - 空状态

    @ViewBuilder
    private var emptyState: some View {
        if !hasSearched {
            stateView(icon: "map",
                      title: "还没有搜索记录",
                      subtitle: "点击搜索按钮发现周围的地点")
        } else {
            stateView(icon: "mappin.slash",
                      title: "附近暂无匹配地点",
                      subtitle: "试试扩大范围或切换其他分类")
        }
    }

    private func stateView(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundColor(ApocalypseTheme.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: UIScreen.main.bounds.height * 0.45)
        .padding(.horizontal, 40)
    }

    // MARK: - 搜索逻辑
    private func triggerSearch() {
        guard let coord = locationManager.userLocation else {
            searchError = "无法获取位置，请检查定位权限"
            return
        }
        isSearching = true
        searchError = nil
        Task {
            let results = await POISearchManager.searchNearbyPOIs(center: coord, limit: 20)
            await MainActor.run {
                searchResults = results
                hasSearched = true
                isSearching = false
                listVisible = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    listVisible = true
                }
            }
        }
    }
}

// MARK: - GamePOICard（单条 POI 卡片）

private struct GamePOICard: View {
    let poi: GamePOI

    var body: some View {
        ELCard(padding: EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)) {
            HStack(spacing: 14) {
                typeIcon
                infoColumn
                Spacer()
                lootBadge
            }
        }
    }

    private var color: Color { typeColor(for: poi.poiType) }

    private var typeIcon: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.18))
                .frame(width: 46, height: 46)
            Image(systemName: poi.poiType.systemImage)
                .font(.system(size: 18))
                .foregroundColor(color)
        }
    }

    private var infoColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(poi.name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)
            Text(poi.poiType.displayName)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    private var lootBadge: some View {
        VStack(spacing: 2) {
            Image(systemName: poi.isLooted ? "shippingbox" : "shippingbox.fill")
                .font(.system(size: 13))
                .foregroundColor(poi.isLooted ? ApocalypseTheme.textMuted : ApocalypseTheme.warning)
            Text(poi.isLooted ? "已搜空" : "未搜刮")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(poi.isLooted ? ApocalypseTheme.textMuted : ApocalypseTheme.warning)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        POIListView()
    }
}
