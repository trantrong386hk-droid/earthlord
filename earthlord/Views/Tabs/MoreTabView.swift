import SwiftUI

struct MoreTabView: View {
    @ObservedObject private var languageManager = LanguageManager.shared
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // 支持与帮助区域
                        VStack(alignment: .leading, spacing: 12) {
                            Text("支持与帮助".localized)
                                .font(.headline)
                                .foregroundColor(ApocalypseTheme.textPrimary)
                                .padding(.horizontal, 4)
                                .padding(.top, 10)

                            ActionCard(
                                icon: "questionmark.circle.fill",
                                title: "技术支持".localized,
                                subtitle: "常见问题、联系我们".localized
                            ) {
                                if let url = URL(string: "https://trantrong386hk-droid.github.io/earthlord-support/support.html") {
                                    openURL(url)
                                }
                            }

                            ActionCard(
                                icon: "hand.raised.fill",
                                title: "隐私政策".localized,
                                subtitle: "了解我们如何保护您的隐私".localized
                            ) {
                                if let url = URL(string: "https://trantrong386hk-droid.github.io/earthlord-support/privacy.html") {
                                    openURL(url)
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(Text("更多".localized))
            .navigationBarTitleDisplayMode(.large)
        }
        .id(languageManager.refreshID)
    }
}

#Preview {
    MoreTabView()
}
