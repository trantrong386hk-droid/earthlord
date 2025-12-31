import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 2  // 默认进入「个人」页面

    var body: some View {
        TabView(selection: $selectedTab) {
            MapTabView()
                .tabItem {
                    Image(systemName: "map.fill")
                    Text("地图")
                }
                .tag(0)

            TerritoryTabView()
                .tabItem {
                    Image(systemName: "flag.fill")
                    Text("领地")
                }
                .tag(1)

            ProfileTabView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("个人")
                }
                .tag(2)

            MoreTabView()
                .tabItem {
                    Image(systemName: "ellipsis")
                    Text("更多")
                }
                .tag(3)
        }
        .tint(ApocalypseTheme.primary)
    }
}

#Preview {
    MainTabView()
}
