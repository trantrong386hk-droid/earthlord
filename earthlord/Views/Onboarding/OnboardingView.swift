//
//  OnboardingView.swift
//  earthlord
//
//  新手引导页面
//  首次注册后展示，帮助用户了解核心功能
//

import SwiftUI

struct OnboardingView: View {
    /// 完成回调
    var onComplete: () -> Void

    /// 当前页码
    @State private var currentPage = 0

    /// 页面数据
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "globe.americas.fill",
            title: "探索末日世界",
            description: "基于真实位置，探索你身边的废墟与资源点，发现隐藏的物资"
        ),
        OnboardingPage(
            icon: "flag.fill",
            title: "圈地建造",
            description: "在真实地图上圈定领地，建造你的末日避难所"
        ),
        OnboardingPage(
            icon: "cube.box.fill",
            title: "搜刮与交易",
            description: "搜刮废墟获取物资，与附近幸存者自由交易"
        ),
        OnboardingPage(
            icon: "antenna.radiowaves.left.and.right",
            title: "幸存者通讯",
            description: "通过无线电频道与周围幸存者沟通，组建联盟"
        ),
        OnboardingPage(
            icon: "figure.walk",
            title: "开始你的生存之旅",
            description: "末日已至，你准备好了吗？"
        )
    ]

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 页面内容
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                // 页码指示器
                pageIndicator
                    .padding(.bottom, 32)

                // 底部按钮
                bottomButton
                    .padding(.horizontal, 32)
                    .padding(.bottom, 48)
            }
        }
    }

    // MARK: - 页码指示器

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<pages.count, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                    .frame(width: 8, height: 8)
                    .scaleEffect(index == currentPage ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3), value: currentPage)
            }
        }
    }

    // MARK: - 底部按钮

    private var bottomButton: some View {
        VStack(spacing: 16) {
            if currentPage == pages.count - 1 {
                // 最后一页：进入游戏按钮
                Button {
                    completeOnboarding()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("进入游戏".localized)
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
            } else {
                // 非最后一页：跳过按钮
                Button {
                    completeOnboarding()
                } label: {
                    Text("跳过".localized)
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
    }

    // MARK: - 完成引导

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "has_completed_onboarding")
        onComplete()
    }
}

// MARK: - 页面数据模型

struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
}

// MARK: - 单页视图

struct OnboardingPageView: View {
    let page: OnboardingPage

    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // 图标
            Image(systemName: page.icon)
                .font(.system(size: 80))
                .foregroundColor(ApocalypseTheme.primary)
                .shadow(color: ApocalypseTheme.primary.opacity(0.4), radius: 12)
                .scaleEffect(isAnimating ? 1.0 : 0.5)
                .opacity(isAnimating ? 1.0 : 0.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.6), value: isAnimating)

            // 标题
            Text(page.title.localized)
                .font(.title.bold())
                .foregroundColor(ApocalypseTheme.textPrimary)
                .multilineTextAlignment(.center)
                .opacity(isAnimating ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.4).delay(0.2), value: isAnimating)

            // 描述
            Text(page.description.localized)
                .font(.body)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .opacity(isAnimating ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.4).delay(0.3), value: isAnimating)

            Spacer()
            Spacer()
        }
        .onAppear {
            isAnimating = true
        }
        .onDisappear {
            isAnimating = false
        }
    }
}

#Preview {
    OnboardingView {
        print("Onboarding completed")
    }
}
