import SwiftUI

/// 通用占位视图
/// 注意：调用时需传入已本地化的字符串（使用 .localized）
struct PlaceholderView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.primary)

                Text(verbatim: title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(verbatim: subtitle)
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
    }
}

#Preview {
    PlaceholderView(
        icon: "map.fill",
        title: "地图",
        subtitle: "探索和圈占领地"
    )
}
