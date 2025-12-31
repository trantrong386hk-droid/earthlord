import SwiftUI

struct MapTabView: View {
    @ObservedObject private var languageManager = LanguageManager.shared

    var body: some View {
        PlaceholderView(
            icon: "map.fill",
            title: "地图".localized,
            subtitle: "探索和圈占领地".localized
        )
        .id(languageManager.refreshID)
    }
}

#Preview {
    MapTabView()
}
