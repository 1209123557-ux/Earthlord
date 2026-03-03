//
//  CreateOfferView.swift
//  Earthlord
//
//  发布挂单页面，从 MyOffersView NavigationLink push 进入。
//

import SwiftUI

struct CreateOfferView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var inventoryManager: InventoryManager

    // MARK: - 状态
    @State private var offeringItems: [(itemId: String, quantity: Int)] = []
    @State private var requestingItems: [(itemId: String, quantity: Int)] = []
    @State private var expireHours: Int = 24
    @State private var message: String = ""

    @State private var showOfferingPicker = false
    @State private var showRequestingPicker = false

    @State private var isSubmitting = false
    @State private var toastMessage: String? = nil
    @State private var showSuccessToast = false

    private let expireOptions = [1, 6, 12, 24, 48, 72]

    private var canSubmit: Bool {
        !offeringItems.isEmpty && !requestingItems.isEmpty && !isSubmitting
    }

    var body: some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // 出售物品区
                    itemSection(
                        title: "我要出的物品",
                        icon: "arrow.up.circle.fill",
                        iconColor: ApocalypseTheme.danger,
                        items: offeringItems,
                        onAdd: { showOfferingPicker = true },
                        onRemove: { idx in
                            offeringItems.remove(at: idx)
                        }
                    )

                    // 想要物品区
                    itemSection(
                        title: "我想要的物品",
                        icon: "arrow.down.circle.fill",
                        iconColor: ApocalypseTheme.success,
                        items: requestingItems,
                        onAdd: { showRequestingPicker = true },
                        onRemove: { idx in
                            requestingItems.remove(at: idx)
                        }
                    )

                    // 有效期 Picker
                    expirePicker

                    // 留言框
                    messageField

                    // 发布按钮
                    submitButton
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }

            // Toast
            if showSuccessToast, let msg = toastMessage {
                toastView(msg)
            }
        }
        .navigationTitle("发布挂单")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showOfferingPicker) {
            ItemPickerView(mode: .fromInventory) { itemId, qty in
                addItem(to: &offeringItems, itemId: itemId, quantity: qty)
            }
            .environmentObject(inventoryManager)
        }
        .sheet(isPresented: $showRequestingPicker) {
            ItemPickerView(mode: .allItems) { itemId, qty in
                addItem(to: &requestingItems, itemId: itemId, quantity: qty)
            }
            .environmentObject(inventoryManager)
        }
    }

    // MARK: - 物品列表区块

    private func itemSection(
        title: String,
        icon: String,
        iconColor: Color,
        items: [(itemId: String, quantity: Int)],
        onAdd: @escaping () -> Void,
        onRemove: @escaping (Int) -> Void
    ) -> some View {
        ELCard {
            VStack(alignment: .leading, spacing: 12) {
                // 标题行
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 15))
                        .foregroundColor(iconColor)
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Spacer()
                    Button(action: onAdd) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .semibold))
                            Text("添加")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(ApocalypseTheme.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(ApocalypseTheme.primary.opacity(0.15))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }

                Divider().background(Color.white.opacity(0.07))

                if items.isEmpty {
                    Text("尚未添加物品")
                        .font(.system(size: 13))
                        .foregroundColor(ApocalypseTheme.textMuted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else {
                    ForEach(Array(items.enumerated()), id: \.offset) { idx, entry in
                        itemRow(entry: entry, onRemove: { onRemove(idx) })
                    }
                }
            }
        }
    }

    private func itemRow(entry: (itemId: String, quantity: Int), onRemove: @escaping () -> Void) -> some View {
        let def = MockItemDefinitions.find(entry.itemId)
        let (icon, color) = categoryIconColor(def?.category ?? .material)
        return HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.18))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(color)
            }
            Text(def?.displayName ?? entry.itemId)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ApocalypseTheme.textPrimary)
            Spacer()
            Text("×\(entry.quantity)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textSecondary)
            Button(action: onRemove) {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.danger)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 有效期 Picker

    private var expirePicker: some View {
        ELCard {
            HStack {
                Image(systemName: "clock.fill")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.info)
                Text("有效期")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Spacer()
                Picker("有效期", selection: $expireHours) {
                    ForEach(expireOptions, id: \.self) { h in
                        Text("\(h)小时").tag(h)
                    }
                }
                .pickerStyle(.menu)
                .foregroundColor(ApocalypseTheme.primary)
                .tint(ApocalypseTheme.primary)
            }
        }
    }

    // MARK: - 留言输入框

    private var messageField: some View {
        ELCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    Text("留言（可选）")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
                TextField("", text: $message,
                          prompt: Text("说点什么…").foregroundColor(ApocalypseTheme.textMuted))
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .autocorrectionDisabled()
            }
        }
    }

    // MARK: - 发布按钮

    private var submitButton: some View {
        Button(action: submit) {
            HStack(spacing: 8) {
                if isSubmitting {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.85)
                }
                Text(isSubmitting ? "发布中…" : "发布挂单")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(canSubmit ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
            .cornerRadius(14)
        }
        .disabled(!canSubmit)
        .buttonStyle(.plain)
        .padding(.bottom, 8)
    }

    // MARK: - 提交逻辑

    private func submit() {
        guard canSubmit else { return }
        isSubmitting = true
        Task {
            do {
                try await TradeManager.shared.createTradeOffer(
                    offeringItems: offeringItems,
                    requestingItems: requestingItems,
                    expireHours: expireHours,
                    message: message.isEmpty ? nil : message
                )
                toastMessage = "挂单发布成功！"
                showSuccessToast = true
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                dismiss()
            } catch {
                toastMessage = error.localizedDescription
                showSuccessToast = true
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                showSuccessToast = false
            }
            isSubmitting = false
        }
    }

    // MARK: - Toast

    private func toastView(_ text: String) -> some View {
        VStack {
            Spacer()
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.75))
                .cornerRadius(20)
                .padding(.bottom, 50)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Helpers

    private func addItem(to list: inout [(itemId: String, quantity: Int)], itemId: String, quantity: Int) {
        if let idx = list.firstIndex(where: { $0.itemId == itemId }) {
            list[idx].quantity += quantity
        } else {
            list.append((itemId: itemId, quantity: quantity))
        }
    }

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
