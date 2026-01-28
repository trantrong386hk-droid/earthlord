//
//  CreateIdleItemView.swift
//  earthlord
//
//  发布闲置物品表单
//  支持照片选择、物品信息填写、成色选择
//

import SwiftUI
import PhotosUI

struct CreateIdleItemView: View {

    // MARK: - 环境

    @Environment(\.dismiss) private var dismiss

    // MARK: - 状态

    @State private var title: String = ""
    @State private var descriptionText: String = ""
    @State private var condition: ItemCondition = .good
    @State private var desiredExchange: String = ""

    /// 已选照片 items
    @State private var selectedPhotos: [PhotosPickerItem] = []
    /// 已加载的照片 UIImage
    @State private var loadedImages: [UIImage] = []

    @State private var isPublishing = false
    @State private var showError = false
    @State private var errorMessage = ""

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // 照片区域
                        photoSection

                        // 物品名称
                        titleSection

                        // 物品描述
                        descriptionSection

                        // 物品成色
                        conditionSection

                        // 期望交换
                        desiredExchangeSection

                        // 发布按钮
                        publishButton

                        Spacer(minLength: 40)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("发布闲置物品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .alert("发布失败", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - 照片区域

    private var photoSection: some View {
        ApocalypseCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "camera.fill")
                        .foregroundColor(ApocalypseTheme.primary)
                    Text("物品照片")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Text("(最多3张)")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }

                HStack(spacing: 10) {
                    // 已选照片预览
                    ForEach(loadedImages.indices, id: \.self) { index in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: loadedImages[index])
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .cornerRadius(8)
                                .clipped()

                            // 删除按钮
                            Button {
                                removePhoto(at: index)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .background(
                                        Circle()
                                            .fill(Color.black.opacity(0.6))
                                    )
                            }
                            .offset(x: 4, y: -4)
                        }
                    }

                    // 添加按钮
                    if loadedImages.count < 3 {
                        PhotosPicker(
                            selection: $selectedPhotos,
                            maxSelectionCount: 3 - loadedImages.count,
                            matching: .images
                        ) {
                            VStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.title3)
                                Text("添加")
                                    .font(.caption2)
                            }
                            .foregroundColor(ApocalypseTheme.textMuted)
                            .frame(width: 80, height: 80)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(
                                        ApocalypseTheme.textMuted.opacity(0.5),
                                        style: StrokeStyle(lineWidth: 1, dash: [5])
                                    )
                            )
                        }
                        .onChange(of: selectedPhotos) { _, newValue in
                            loadPhotos(from: newValue)
                        }
                    }
                }
            }
        }
    }

    // MARK: - 物品名称

    private var titleSection: some View {
        ApocalypseCard(padding: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "tag.fill")
                        .foregroundColor(ApocalypseTheme.primary)
                    Text("物品名称")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }

                TextField("请输入物品名称（最多50字）", text: $title)
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(ApocalypseTheme.background)
                    )
                    .onChange(of: title) { _, newValue in
                        if newValue.count > 50 {
                            title = String(newValue.prefix(50))
                        }
                    }

                HStack {
                    Spacer()
                    Text("\(title.count)/50")
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
        }
    }

    // MARK: - 物品描述

    private var descriptionSection: some View {
        ApocalypseCard(padding: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "text.alignleft")
                        .foregroundColor(ApocalypseTheme.primary)
                    Text("物品描述")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }

                TextEditor(text: $descriptionText)
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 80, maxHeight: 150)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(ApocalypseTheme.background)
                    )
                    .onChange(of: descriptionText) { _, newValue in
                        if newValue.count > 500 {
                            descriptionText = String(newValue.prefix(500))
                        }
                    }

                HStack {
                    Spacer()
                    Text("\(descriptionText.count)/500")
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
        }
    }

    // MARK: - 物品成色

    private var conditionSection: some View {
        ApocalypseCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(ApocalypseTheme.primary)
                    Text("物品成色")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }

                // 成色选项
                HStack(spacing: 8) {
                    ForEach(ItemCondition.allCases, id: \.self) { cond in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                condition = cond
                            }
                        } label: {
                            Text(cond.displayName)
                                .font(.caption)
                                .fontWeight(condition == cond ? .semibold : .regular)
                                .foregroundColor(condition == cond ? .white : cond.color)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(condition == cond ? cond.color : cond.color.opacity(0.15))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - 期望交换

    private var desiredExchangeSection: some View {
        ApocalypseCard(padding: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(ApocalypseTheme.primary)
                    Text("期望交换")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Text("(可选)")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }

                TextField("描述你期望交换的物品（最多200字）", text: $desiredExchange)
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(ApocalypseTheme.background)
                    )
                    .onChange(of: desiredExchange) { _, newValue in
                        if newValue.count > 200 {
                            desiredExchange = String(newValue.prefix(200))
                        }
                    }

                HStack {
                    Spacer()
                    Text("\(desiredExchange.count)/200")
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
        }
    }

    // MARK: - 发布按钮

    private var publishButton: some View {
        Button {
            publishItem()
        } label: {
            HStack(spacing: 8) {
                if isPublishing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                Text(isPublishing ? "发布中..." : "发布闲置物品")
                    .fontWeight(.semibold)
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(canPublish ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
            )
        }
        .disabled(!canPublish || isPublishing)
        .padding(.top, 8)
    }

    // MARK: - 计算属性

    private var canPublish: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !loadedImages.isEmpty
    }

    // MARK: - 方法

    private func removePhoto(at index: Int) {
        guard index < loadedImages.count else { return }
        loadedImages.remove(at: index)
        // 重置 selectedPhotos 以允许重新选择
        selectedPhotos = []
    }

    private func loadPhotos(from items: [PhotosPickerItem]) {
        Task {
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        if loadedImages.count < 3 {
                            loadedImages.append(image)
                        }
                    }
                }
            }
            await MainActor.run {
                selectedPhotos = []
            }
        }
    }

    private func publishItem() {
        isPublishing = true

        Task {
            do {
                // 1. 上传所有照片
                var photoUrls: [String] = []
                for image in loadedImages {
                    let path = try await IdleItemManager.shared.uploadPhoto(image)
                    photoUrls.append(path)
                }

                // 2. 创建物品
                try await IdleItemManager.shared.createItem(
                    title: title,
                    description: descriptionText,
                    condition: condition,
                    desiredExchange: desiredExchange.isEmpty ? nil : desiredExchange,
                    photoUrls: photoUrls
                )

                await MainActor.run {
                    isPublishing = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isPublishing = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    CreateIdleItemView()
}
