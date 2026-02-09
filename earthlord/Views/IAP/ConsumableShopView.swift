//
//  ConsumableShopView.swift
//  earthlord
//
//  消耗品商店页面
//  展示可购买的消耗品商品网格
//

import SwiftUI
import StoreKit

struct ConsumableShopView: View {
    @ObservedObject private var storeKit = StoreKitManager.shared
    @Environment(\.dismiss) private var dismiss

    /// 购买结果提示
    @State private var toastMessage: String?

    /// 是否正在购买
    @State private var isPurchasing = false

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 说明文字
                        Text("获取物资，加速你的末日生存之旅")
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .padding(.top, 8)

                        if !storeKit.consumableProducts.isEmpty {
                            // 正常商品网格（StoreKit 商品已加载）
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ], spacing: 12) {
                                ForEach(storeKit.consumableProducts, id: \.id) { product in
                                    consumableCard(product: product)
                                }
                            }
                        } else if storeKit.hasLoadedProducts {
                            // 加载完毕但无商品 → 使用本地元数据回退显示
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ], spacing: 12) {
                                ForEach(Array(IAPProductID.consumableIDs), id: \.self) { productId in
                                    if let meta = IAPProductMeta.all[productId] {
                                        fallbackCard(meta: meta)
                                    }
                                }
                            }

                            // 提示 + 重新加载
                            VStack(spacing: 12) {
                                Text("商品配置中，请稍后再试")
                                    .font(.caption)
                                    .foregroundColor(ApocalypseTheme.textMuted)

                                Button {
                                    Task { await storeKit.loadProducts() }
                                } label: {
                                    Label("重新加载", systemImage: "arrow.clockwise")
                                        .font(.caption)
                                        .foregroundColor(ApocalypseTheme.primary)
                                }
                            }
                            .padding(.top, 8)
                        } else if storeKit.isLoading {
                            // 正在加载中
                            VStack(spacing: 12) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                                Text("正在加载商品...")
                                    .font(.subheadline)
                                    .foregroundColor(ApocalypseTheme.textMuted)
                            }
                            .padding(.top, 40)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }

                // 购买中遮罩
                if isPurchasing {
                    ZStack {
                        Color.black.opacity(0.5).ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                                .scaleEffect(1.5)
                            Text("处理中...")
                                .font(.subheadline)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }
                        .padding(32)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(16)
                    }
                }

                // Toast
                if let message = toastMessage {
                    VStack {
                        Spacer()
                        Text(message)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(8)
                            .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("物资商店")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - 商品卡片

    private func consumableCard(product: Product) -> some View {
        let meta = IAPProductMeta.all[product.id]

        return VStack(spacing: 10) {
            // 图标
            Image(systemName: meta?.icon ?? "questionmark.circle")
                .font(.system(size: 32))
                .foregroundColor(iconColor(for: product.id))
                .frame(height: 40)

            // 名称
            Text(meta?.displayName ?? product.displayName)
                .font(.subheadline.bold())
                .foregroundColor(ApocalypseTheme.textPrimary)
                .lineLimit(1)

            // 内容描述
            VStack(spacing: 2) {
                ForEach(meta?.contents ?? [], id: \.self) { item in
                    Text(item)
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(minHeight: 40)

            Spacer()

            // 购买按钮
            Button {
                Task {
                    isPurchasing = true
                    let success = await storeKit.purchase(product)
                    isPurchasing = false
                    if success {
                        showToast("购买成功！")
                    }
                }
            } label: {
                Text(product.displayPrice)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(10)
            }
            .disabled(isPurchasing)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(14)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(14)
    }

    // MARK: - 回退卡片（无 StoreKit 商品时使用本地元数据 + fallback 价格）

    private func fallbackCard(meta: IAPProductMeta) -> some View {
        VStack(spacing: 10) {
            // 图标
            Image(systemName: meta.icon)
                .font(.system(size: 32))
                .foregroundColor(iconColor(for: meta.productId))
                .frame(height: 40)

            // 名称
            Text(meta.displayName)
                .font(.subheadline.bold())
                .foregroundColor(ApocalypseTheme.textPrimary)
                .lineLimit(1)

            // 内容描述
            VStack(spacing: 2) {
                ForEach(meta.contents, id: \.self) { item in
                    Text(item)
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(minHeight: 40)

            Spacer()

            // 购买按钮（显示 fallback 价格，点击后尝试加载并购买）
            Button {
                Task {
                    isPurchasing = true
                    // 重新加载商品
                    await storeKit.loadProducts()
                    // 查找对应商品
                    if let product = storeKit.consumableProducts.first(where: { $0.id == meta.productId }) {
                        let success = await storeKit.purchase(product)
                        isPurchasing = false
                        if success {
                            showToast("购买成功！")
                        }
                    } else {
                        isPurchasing = false
                        showToast("商品加载失败，请检查网络后重试")
                    }
                }
            } label: {
                Text(meta.fallbackPrice)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(10)
            }
            .disabled(isPurchasing)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(14)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(14)
    }

    // MARK: - 辅助方法

    private func iconColor(for productId: String) -> Color {
        switch productId {
        case IAPProductID.resourceBox:
            return ApocalypseTheme.success
        case IAPProductID.instantBuild:
            return ApocalypseTheme.warning
        case IAPProductID.explorationBoost:
            return ApocalypseTheme.info
        case IAPProductID.legendaryCrate:
            return ApocalypseTheme.primary
        default:
            return ApocalypseTheme.textMuted
        }
    }

    private func showToast(_ message: String) {
        withAnimation {
            toastMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                toastMessage = nil
            }
        }
    }
}

#Preview {
    ConsumableShopView()
}
