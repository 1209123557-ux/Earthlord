//
//  BuildingBrowserView.swift
//  Earthlord
//
//  建筑浏览器：分类筛选 + 2列网格，点击直接进入建造流程
//

import SwiftUI

struct BuildingBrowserView: View {
    let onDismiss: () -> Void
    let onStartConstruction: (BuildingTemplate) -> Void

    @State private var selectedCategory: BuildingCategory? = nil
    @ObservedObject private var buildingManager = BuildingManager.shared

    private var filteredTemplates: [BuildingTemplate] {
        guard let cat = selectedCategory else { return buildingManager.buildingTemplates }
        return buildingManager.buildingTemplates.filter { $0.category == cat }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // 分类滚动条
                    categoryScrollView
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    if buildingManager.buildingTemplates.isEmpty {
                        Spacer()
                        Text("暂无建筑模板")
                            .foregroundColor(ApocalypseTheme.textMuted)
                        Spacer()
                    } else {
                        buildingGrid
                    }
                }
            }
            .navigationTitle("选择建筑")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { onDismiss() }
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            buildingManager.loadTemplates()
        }
    }

    // MARK: - Category Scroll

    private var categoryScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryButton(category: nil, isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(BuildingCategory.allCases, id: \.self) { cat in
                    CategoryButton(category: cat, isSelected: selectedCategory == cat) {
                        selectedCategory = cat
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Building Grid

    private var buildingGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                ForEach(filteredTemplates) { template in
                    BuildingCard(template: template) {
                        onStartConstruction(template)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
    }
}
