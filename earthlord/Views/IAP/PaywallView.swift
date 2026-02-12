//
//  PaywallView.swift
//  earthlord
//
//  付费墙页面
//  展示订阅权益对比、价格选择和购买按钮
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @ObservedObject private var storeKit = StoreKitManager.shared
    @ObservedObject private var entitlement = EntitlementManager.shared
    @Environment(\.dismiss) private var dismiss

    /// 触发原因（可选）
    var reason: PaywallReason?

    /// 选中的订阅方案
    @State private var selectedPlan: SubscriptionPlan = .monthly

    /// 是否正在购买
    @State private var isPurchasing = false

    /// 购买结果提示
    @State private var toastMessage: String?

    enum SubscriptionPlan {
        case monthly
        case annual
    }

    var body: some View {
        ZStack {
            // 背景
            ApocalypseTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // 关闭按钮
                    closeButton

                    // 触发原因提示
                    if let reason = reason ?? entitlement.paywallReason {
                        reasonBanner(reason)
                    }

                    // 标题
                    headerSection

                    // 权益对比
                    benefitsComparison

                    // 价格选择
                    planSelector

                    // 订阅按钮
                    subscribeButton

                    // 恢复购买 + 条款
                    footerLinks
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }

            // 购买中遮罩
            if isPurchasing {
                purchasingOverlay
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
    }

    // MARK: - 关闭按钮

    private var closeButton: some View {
        HStack {
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
        .padding(.top, 12)
    }

    // MARK: - 触发原因横幅

    private func reasonBanner(_ reason: PaywallReason) -> some View {
        VStack(spacing: 4) {
            Text(reason.title)
                .font(.headline)
                .foregroundColor(ApocalypseTheme.warning)
            Text(reason.subtitle)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(ApocalypseTheme.warning.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - 标题区域

    private var headerSection: some View {
        VStack(spacing: 12) {
            // 皇冠图标
            Image(systemName: "crown.fill")
                .font(.system(size: 48))
                .foregroundColor(ApocalypseTheme.primary)
                .shadow(color: ApocalypseTheme.primary.opacity(0.5), radius: 10)

            Text("精英幸存者".localized)
                .font(.largeTitle.bold())
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("解锁所有高级特权，畅享末日生存".localized)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    // MARK: - 权益对比

    private var benefitsComparison: some View {
        VStack(spacing: 0) {
            // 表头
            HStack {
                Text("特权".localized)
                    .font(.caption.bold())
                    .foregroundColor(ApocalypseTheme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("免费".localized)
                    .font(.caption.bold())
                    .foregroundColor(ApocalypseTheme.textMuted)
                    .frame(width: 60)
                Text("精英".localized)
                    .font(.caption.bold())
                    .foregroundColor(ApocalypseTheme.primary)
                    .frame(width: 60)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider().background(ApocalypseTheme.textMuted.opacity(0.3))

            // 权益行
            benefitRow(title: "每日探索".localized, free: "3 次".localized, elite: "无限".localized)
            benefitRow(title: "每日圈地".localized, free: "5 次".localized, elite: "无限".localized)
            benefitRow(title: "每日搜刮".localized, free: "10 次".localized, elite: "无限".localized)
            benefitRow(title: "背包容量".localized, free: "30kg", elite: "50kg")
            benefitRow(title: "建造速度".localized, free: "正常".localized, elite: "2 倍速".localized)
            benefitRow(title: "探索奖励".localized, free: "正常".localized, elite: "1.5 倍".localized)
            benefitRow(title: "通讯范围".localized, free: "正常".localized, elite: "+20%".localized)
            benefitRow(title: "交易手续费".localized, free: "5%".localized, elite: "0%".localized)
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    private func benefitRow(title: String, free: String, elite: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(free)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)
                .frame(width: 60)
            Text(elite)
                .font(.caption.bold())
                .foregroundColor(ApocalypseTheme.primary)
                .frame(width: 60)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - 方案选择

    private var planSelector: some View {
        VStack(spacing: 12) {
            // 月订阅
            planCard(
                plan: .monthly,
                title: "月订阅".localized,
                price: storeKit.monthlyProduct?.cnyPrice ?? "¥25",
                subtitle: "按月计费".localized,
                isSelected: selectedPlan == .monthly
            )

            // 年订阅
            planCard(
                plan: .annual,
                title: "年订阅".localized,
                price: storeKit.annualProduct?.cnyPrice ?? "¥198",
                subtitle: "约 66 折，最划算".localized,
                badge: "推荐".localized,
                isSelected: selectedPlan == .annual
            )
        }
    }

    private func planCard(plan: SubscriptionPlan, title: String, price: String, subtitle: String, badge: String? = nil, isSelected: Bool) -> some View {
        Button {
            selectedPlan = plan
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        if let badge = badge {
                            Text(badge)
                                .font(.caption2.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(ApocalypseTheme.primary)
                                .cornerRadius(8)
                        }
                    }

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                Spacer()

                Text(price)
                    .font(.title3.bold())
                    .foregroundColor(isSelected ? ApocalypseTheme.primary : ApocalypseTheme.textPrimary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ApocalypseTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? ApocalypseTheme.primary : ApocalypseTheme.textMuted.opacity(0.2),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
    }

    // MARK: - 订阅按钮

    private var subscribeButton: some View {
        Button {
            Task {
                await performPurchase()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "crown.fill")
                Text("立即订阅".localized)
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(14)
            .shadow(color: ApocalypseTheme.primary.opacity(0.4), radius: 8, y: 4)
        }
        .disabled(isPurchasing)
    }

    // MARK: - 底部链接

    private var footerLinks: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    isPurchasing = true
                    await storeKit.restorePurchases()
                    isPurchasing = false
                    if storeKit.subscriptionStatus.isSubscribed {
                        showToast("订阅已恢复".localized)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            dismiss()
                        }
                    } else {
                        showToast("未找到有效订阅".localized)
                    }
                }
            } label: {
                Text("恢复购买".localized)
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            HStack(spacing: 16) {
                Link("使用条款".localized, destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)

                Link("隐私政策".localized, destination: URL(string: "https://trantrong386hk-droid.github.io/earthlord-support/privacy.html")!)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            Text("订阅将在到期前 24 小时自动续费，可在设置中管理或取消".localized)
                .font(.caption2)
                .foregroundColor(ApocalypseTheme.textMuted)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - 购买中遮罩

    private var purchasingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                    .scaleEffect(1.5)
                Text("处理中...".localized)
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding(32)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(16)
        }
    }

    // MARK: - 方法

    private func performPurchase() async {
        if entitlement.isSubscribed {
            showToast("您已是精英幸存者，无需重复订阅".localized)
            return
        }

        let product: Product?
        switch selectedPlan {
        case .monthly:
            product = storeKit.monthlyProduct
        case .annual:
            product = storeKit.annualProduct
        }

        guard let product = product else {
            showToast("商品暂不可用".localized)
            return
        }

        isPurchasing = true
        let success = await storeKit.purchase(product)
        isPurchasing = false

        if success {
            showToast("订阅成功！".localized)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
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
    PaywallView(reason: .explorationLimit)
}
