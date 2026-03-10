//
//  PackProductCard.swift
//  Earthlord
//
//  商品卡片：显示物资包/背包扩容包详情与购买按钮
//

import SwiftUI
import StoreKit

// MARK: - PackProductCard（物资包）

struct PackProductCard: View {
    let pack: PackDefinition
    let product: Product?
    let isPurchasing: Bool
    let onBuy: () -> Void

    var body: some View {
        ELCard(padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)) {
            VStack(alignment: .leading, spacing: 12) {
                // ── 标题行 ──
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pack.displayName)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                        Text(pack.tagline)
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                    Spacer()
                    priceTag
                }

                Divider()
                    .background(Color.white.opacity(0.1))

                // ── 物品预览 ──
                itemPreviewGrid

                // ── 购买按钮 ──
                buyButton
            }
        }
    }

    // 价格标签
    private var priceTag: some View {
        Text(pack.price)
            .font(.system(size: 20, weight: .heavy))
            .foregroundColor(ApocalypseTheme.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(ApocalypseTheme.primary.opacity(0.15))
            .cornerRadius(10)
    }

    // 物品预览网格
    private var itemPreviewGrid: some View {
        let guaranteed = pack.items.filter { $0.isGuaranteed }
        let random = pack.items.filter { !$0.isGuaranteed }

        return VStack(alignment: .leading, spacing: 8) {
            // 保底物品
            if !guaranteed.isEmpty {
                Text("保底物品")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textMuted)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(guaranteed, id: \.itemId) { item in
                        itemChip(item: item, isGuaranteed: true)
                    }
                }
            }

            // 随机物品
            if !random.isEmpty {
                Text("随机物品")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textMuted)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(random, id: \.itemId) { item in
                        itemChip(item: item, isGuaranteed: false)
                    }
                }
            }
        }
    }

    private func itemChip(item: PackItem, isGuaranteed: Bool) -> some View {
        let def = MockItemDefinitions.find(item.itemId)
        let name = def?.displayName ?? item.itemId
        let rarity = def?.rarity ?? .common
        let rarityColor: Color = {
            switch rarity {
            case .common:   return Color(white: 0.55)
            case .uncommon: return ApocalypseTheme.success
            case .rare:     return ApocalypseTheme.info
            }
        }()

        return VStack(spacing: 3) {
            Text(name)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            HStack(spacing: 3) {
                Text("×\(item.quantity)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(isGuaranteed ? ApocalypseTheme.textPrimary : ApocalypseTheme.textMuted)
                if let prob = item.probability {
                    Text("\(Int(prob * 100))%")
                        .font(.system(size: 10))
                        .foregroundColor(ApocalypseTheme.warning)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(rarityColor.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isGuaranteed ? rarityColor.opacity(0.4) : rarityColor.opacity(0.2), lineWidth: 1)
        )
    }

    // 购买按钮
    private var buyButton: some View {
        Button(action: onBuy) {
            HStack(spacing: 8) {
                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "bag.fill")
                        .font(.system(size: 14))
                }
                Text(isPurchasing ? "购买中..." : "立即购买 \(pack.price)")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isPurchasing ? ApocalypseTheme.primary.opacity(0.5) : ApocalypseTheme.primary)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .disabled(isPurchasing || product == nil)
    }
}

// MARK: - BagExpansionCard（背包扩容卡片）

struct BagExpansionCard: View {
    let expansion: BagExpansionProduct
    let product: Product?
    let isPurchasing: Bool
    let onBuy: () -> Void

    var body: some View {
        ELCard(padding: EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)) {
            HStack(spacing: 12) {
                // 图标
                ZStack {
                    Circle()
                        .fill(ApocalypseTheme.info.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "bag.badge.plus")
                        .font(.system(size: 20))
                        .foregroundColor(ApocalypseTheme.info)
                }

                // 信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(expansion.displayName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Text(expansion.description)
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }

                Spacer()

                // 价格 + 购买
                Button(action: onBuy) {
                    VStack(spacing: 2) {
                        if isPurchasing {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.7)
                        } else {
                            Text(expansion.price)
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(width: 60, height: 36)
                    .background(isPurchasing ? ApocalypseTheme.info.opacity(0.5) : ApocalypseTheme.info)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .disabled(isPurchasing || product == nil)
            }
        }
    }
}
