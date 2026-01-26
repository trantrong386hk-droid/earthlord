//
//  CreateOfferView.swift
//  earthlord
//
//  发布交易挂单页面
//  让用户创建"我出X换Y"的交易挂单
//

import SwiftUI

struct CreateOfferView: View {

    // MARK: - 属性

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var tradeManager = TradeManager.shared

    // MARK: - 状态

    @State private var offeringItems: [TradeItem] = []
    @State private var requestingItems: [TradeItem] = []
    @State private var expiresInHours: Int = 24
    @State private var message: String = ""
    @State private var showOfferingPicker = false
    @State private var showRequestingPicker = false
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccessAlert = false

    // MARK: - 计算属性

    /// 是否可以提交
    private var canSubmit: Bool {
        !offeringItems.isEmpty && !requestingItems.isEmpty && !isSubmitting
    }

    /// 有效期选项
    private let expirationOptions = [6, 12, 24, 48]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // 我要出的物品
                        offeringSection
                            .padding(.horizontal, 16)

                        // 我想要的物品
                        requestingSection
                            .padding(.horizontal, 16)

                        // 有效期选择
                        expirationSection
                            .padding(.horizontal, 16)

                        // 留言
                        messageSection
                            .padding(.horizontal, 16)

                        // 发布按钮
                        submitButton
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("发布交易挂单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .sheet(isPresented: $showOfferingPicker) {
                ItemPickerView(mode: .offering) { item in
                    addOfferingItem(item)
                }
            }
            .sheet(isPresented: $showRequestingPicker) {
                ItemPickerView(mode: .requesting) { item in
                    addRequestingItem(item)
                }
            }
            .alert("发布失败", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("发布成功", isPresented: $showSuccessAlert) {
                Button("确定") {
                    dismiss()
                }
            } message: {
                Text("你的交易挂单已发布，等待其他玩家接受")
            }
        }
    }

    // MARK: - 我要出的物品

    private var offeringSection: some View {
        ApocalypseCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                // 标题
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(ApocalypseTheme.warning)
                    Text("我要出的物品")
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Spacer()
                }

                // 已选物品列表
                if offeringItems.isEmpty {
                    Text("还没有选择物品")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textMuted)
                        .padding(.vertical, 8)
                } else {
                    ForEach(offeringItems) { item in
                        TradeItemEditRow(item: item) { newQuantity in
                            updateOfferingItemQuantity(item: item, quantity: newQuantity)
                        } onDelete: {
                            removeOfferingItem(item)
                        }
                    }
                }

                // 添加按钮
                Button {
                    showOfferingPicker = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("添加物品")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(ApocalypseTheme.primary.opacity(0.5), lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: - 我想要的物品

    private var requestingSection: some View {
        ApocalypseCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                // 标题
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(ApocalypseTheme.success)
                    Text("我想要的物品")
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Spacer()
                }

                // 已选物品列表
                if requestingItems.isEmpty {
                    Text("还没有选择物品")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textMuted)
                        .padding(.vertical, 8)
                } else {
                    ForEach(requestingItems) { item in
                        TradeItemEditRow(item: item) { newQuantity in
                            updateRequestingItemQuantity(item: item, quantity: newQuantity)
                        } onDelete: {
                            removeRequestingItem(item)
                        }
                    }
                }

                // 添加按钮
                Button {
                    showRequestingPicker = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("添加物品")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(ApocalypseTheme.primary.opacity(0.5), lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: - 有效期选择

    private var expirationSection: some View {
        ApocalypseCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(ApocalypseTheme.info)
                    Text("有效期")
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Spacer()
                }

                HStack(spacing: 10) {
                    ForEach(expirationOptions, id: \.self) { hours in
                        ExpirationButton(
                            hours: hours,
                            isSelected: expiresInHours == hours
                        ) {
                            expiresInHours = hours
                        }
                    }
                }
            }
        }
    }

    // MARK: - 留言

    private var messageSection: some View {
        ApocalypseCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "text.bubble.fill")
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    Text("留言（可选）")
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Spacer()
                }

                TextField("添加交易说明...", text: $message, axis: .vertical)
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .padding(12)
                    .background(ApocalypseTheme.background)
                    .cornerRadius(8)
                    .lineLimit(3...5)
            }
        }
    }

    // MARK: - 发布按钮

    private var submitButton: some View {
        Button {
            submitOffer()
        } label: {
            HStack {
                if isSubmitting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                } else {
                    Image(systemName: "paperplane.fill")
                }
                Text(isSubmitting ? "发布中..." : "发布挂单")
                    .fontWeight(.semibold)
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(canSubmit ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
            )
        }
        .disabled(!canSubmit)
    }

    // MARK: - 方法

    private func addOfferingItem(_ item: TradeItem) {
        // 检查是否已存在
        if let index = offeringItems.firstIndex(where: { $0.name == item.name }) {
            // 合并数量
            let newQuantity = offeringItems[index].quantity + item.quantity
            offeringItems[index] = TradeItem(name: item.name, quantity: newQuantity)
        } else {
            offeringItems.append(item)
        }
    }

    private func addRequestingItem(_ item: TradeItem) {
        // 检查是否已存在
        if let index = requestingItems.firstIndex(where: { $0.name == item.name }) {
            // 合并数量
            let newQuantity = requestingItems[index].quantity + item.quantity
            requestingItems[index] = TradeItem(name: item.name, quantity: newQuantity)
        } else {
            requestingItems.append(item)
        }
    }

    private func updateOfferingItemQuantity(item: TradeItem, quantity: Int) {
        if let index = offeringItems.firstIndex(where: { $0.name == item.name }) {
            offeringItems[index] = TradeItem(name: item.name, quantity: quantity)
        }
    }

    private func updateRequestingItemQuantity(item: TradeItem, quantity: Int) {
        if let index = requestingItems.firstIndex(where: { $0.name == item.name }) {
            requestingItems[index] = TradeItem(name: item.name, quantity: quantity)
        }
    }

    private func removeOfferingItem(_ item: TradeItem) {
        offeringItems.removeAll { $0.name == item.name }
    }

    private func removeRequestingItem(_ item: TradeItem) {
        requestingItems.removeAll { $0.name == item.name }
    }

    private func submitOffer() {
        guard canSubmit else { return }

        isSubmitting = true

        Task {
            do {
                try await tradeManager.createOffer(
                    offeringItems: offeringItems,
                    requestingItems: requestingItems,
                    expiresInHours: expiresInHours,
                    message: message.isEmpty ? nil : message
                )
                await MainActor.run {
                    isSubmitting = false
                    showSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - 交易物品编辑行

private struct TradeItemEditRow: View {
    let item: TradeItem
    let onQuantityChange: (Int) -> Void
    let onDelete: () -> Void

    @State private var editingQuantity: String = ""

    var body: some View {
        HStack(spacing: 12) {
            // 物品名称
            Text(item.name)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            // 数量编辑
            HStack(spacing: 8) {
                Button {
                    if item.quantity > 1 {
                        onQuantityChange(item.quantity - 1)
                    }
                } label: {
                    Image(systemName: "minus.circle")
                        .foregroundColor(item.quantity > 1 ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                }
                .disabled(item.quantity <= 1)

                Text("x\(item.quantity)")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .frame(minWidth: 40)

                Button {
                    onQuantityChange(item.quantity + 1)
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }

            // 删除按钮
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(ApocalypseTheme.danger.opacity(0.8))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(ApocalypseTheme.background.opacity(0.5))
        .cornerRadius(8)
    }
}

// MARK: - 有效期按钮

private struct ExpirationButton: View {
    let hours: Int
    let isSelected: Bool
    let action: () -> Void

    private var displayText: String {
        if hours >= 24 {
            return "\(hours / 24)天"
        } else {
            return "\(hours)小时"
        }
    }

    var body: some View {
        Button(action: action) {
            Text(displayText)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : ApocalypseTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? ApocalypseTheme.primary : ApocalypseTheme.background)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            isSelected ? Color.clear : ApocalypseTheme.textMuted.opacity(0.3),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    CreateOfferView()
}
