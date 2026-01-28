//
//  IdleMarketView.swift
//  earthlord
//
//  闲置物品浏览网格
//  以 2 列 LazyVGrid 展示活跃的闲置物品
//

import SwiftUI

struct IdleMarketView: View {

    // MARK: - 属性

    @ObservedObject private var idleManager = IdleItemManager.shared

    // MARK: - 状态

    @State private var showCreateSheet = false
    @State private var selectedItem: IdleItem?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            headerView
                .padding(.horizontal, 16)
                .padding(.top, 12)

            // 内容区
            if idleManager.isLoading && idleManager.allItems.isEmpty {
                loadingView
            } else if idleManager.allItems.isEmpty {
                emptyStateView
            } else {
                gridView
            }
        }
        .task {
            await idleManager.loadAllItems()
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateIdleItemView()
        }
        .sheet(item: $selectedItem) { item in
            IdleItemDetailView(item: item)
        }
    }

    // MARK: - 标题栏

    private var headerView: some View {
        HStack {
            Text("闲置物品")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("(\(idleManager.allItems.count)个)")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            Button {
                showCreateSheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                    Text("发布")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.primary)
            }
        }
    }

    // MARK: - 加载中

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
            Text("加载中...")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textMuted)
            Spacer()
        }
    }

    // MARK: - 空状态

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("暂无闲置物品")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("点击右上角发布你的闲置物品")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textMuted)

            Button {
                showCreateSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("发布闲置物品")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(ApocalypseTheme.primary)
                )
            }
            .padding(.top, 8)

            Spacer()
        }
    }

    // MARK: - 网格视图

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(idleManager.allItems) { item in
                    IdleItemCard(item: item)
                        .onTapGesture {
                            selectedItem = item
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 100)
        }
        .refreshable {
            await idleManager.loadAllItems()
        }
    }
}

// MARK: - 物品卡片

private struct IdleItemCard: View {
    let item: IdleItem

    @State private var photoURL: URL?

    var body: some View {
        ApocalypseCard(cornerRadius: 10, padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                // 照片
                photoView
                    .frame(height: 140)
                    .clipped()

                // 信息
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .lineLimit(1)

                    HStack {
                        // 成色标签
                        Text(item.condition.displayName)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(item.condition.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(item.condition.color.opacity(0.15))
                            )

                        Spacer()

                        // 时间
                        Text(item.formattedCreatedAt)
                            .font(.caption2)
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                }
                .padding(10)
            }
        }
    }

    @ViewBuilder
    private var photoView: some View {
        if let url = photoURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    photoPlaceholder
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(ApocalypseTheme.cardBackground)
                @unknown default:
                    photoPlaceholder
                }
            }
        } else {
            photoPlaceholder
                .task {
                    await loadPhoto()
                }
        }
    }

    private var photoPlaceholder: some View {
        ZStack {
            ApocalypseTheme.background
            Image(systemName: "photo")
                .font(.title2)
                .foregroundColor(ApocalypseTheme.textMuted)
        }
    }

    private func loadPhoto() async {
        guard let firstPath = item.photoUrls.first else { return }
        photoURL = try? await IdleItemManager.shared.getPhotoURL(path: firstPath)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        ApocalypseTheme.background
            .ignoresSafeArea()

        IdleMarketView()
    }
}
