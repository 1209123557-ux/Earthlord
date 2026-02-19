//
//  TerritoryTabView.swift
//  Earthlord
//
//  领地 Tab - 展示当前用户的所有领地，支持查看详情和删除
//

import SwiftUI

struct TerritoryTabView: View {
    // MARK: - State
    @State private var territories: [Territory] = []
    @State private var isLoading = false
    @State private var loadError: String? = nil

    // MARK: - 统计
    private var totalArea: Double {
        territories.reduce(0) { $0 + $1.area }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                if isLoading && territories.isEmpty {
                    loadingView
                } else if let error = loadError {
                    errorView(message: error)
                } else if territories.isEmpty {
                    emptyStateView
                } else {
                    territoryList
                }
            }
            .navigationTitle("我的领地")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onAppear {
            Task { await loadTerritories() }
        }
    }

    // MARK: - Territory List
    private var territoryList: some View {
        ScrollView {
            VStack(spacing: 12) {
                statsHeader
                    .padding(.top, 8)

                ForEach(territories) { territory in
                    NavigationLink(destination: TerritoryDetailView(
                        territory: territory,
                        onDeleted: { Task { await loadTerritories() } }
                    )) {
                        TerritoryCard(territory: territory)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .refreshable {
            await loadTerritories()
        }
    }

    // MARK: - Stats Header
    private var statsHeader: some View {
        HStack(spacing: 12) {
            statItem(
                icon: "flag.2.crossed.fill",
                iconColor: ApocalypseTheme.primary,
                title: "已圈领地",
                value: "\(territories.count) 块"
            )

            Rectangle()
                .fill(ApocalypseTheme.textMuted.opacity(0.4))
                .frame(width: 1, height: 40)

            statItem(
                icon: "map.fill",
                iconColor: ApocalypseTheme.success,
                title: "总面积",
                value: formattedTotalArea
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
    }

    private var formattedTotalArea: String {
        if totalArea >= 1_000_000 {
            return String(format: "%.2f km²", totalArea / 1_000_000)
        }
        return String(format: "%.0f m²", totalArea)
    }

    private func statItem(icon: String, iconColor: Color, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                Text(value)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                .scaleEffect(1.3)
            Text("加载领地中...")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    // MARK: - Error View
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.warning)
            Text("加载失败")
                .font(.title3).fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)
            Text(message)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button(action: { Task { await loadTerritories() } }) {
                Text("重试")
                    .font(.headline).foregroundColor(.white)
                    .padding(.horizontal, 32).padding(.vertical, 10)
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(20)
            }
        }
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "flag.slash.fill")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)
            Text("还没有领地")
                .font(.title3).fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)
            Text("前往地图页，开始圈定属于你的末日领土！")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Load Logic
    private func loadTerritories() async {
        isLoading = true
        loadError = nil
        do {
            territories = try await TerritoryManager.shared.loadMyTerritories()
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Territory Card

struct TerritoryCard: View {
    let territory: Territory

    var body: some View {
        HStack(spacing: 14) {
            // 左侧图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: "flag.fill")
                    .font(.system(size: 20))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            // 中间信息
            VStack(alignment: .leading, spacing: 4) {
                Text(territory.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label(territory.formattedArea, systemImage: "map")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.success)
                    Text("·")
                        .foregroundColor(ApocalypseTheme.textMuted)
                    Text(territory.formattedDate)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .padding(14)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Preview

#Preview {
    TerritoryTabView()
}
