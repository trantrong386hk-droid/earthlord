import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 4  // 默认进入「个人」页面

    var body: some View {
        TabView(selection: $selectedTab) {
            MapTabView()
                .tabItem {
                    Image(systemName: "map.fill")
                    Text("地图".localized)
                }
                .tag(0)

            TerritoryTabView()
                .tabItem {
                    Image(systemName: "flag.fill")
                    Text("领地".localized)
                }
                .tag(1)

            ResourcesTabView()
                .tabItem {
                    Image(systemName: "cube.box.fill")
                    Text("资源".localized)
                }
                .tag(2)

            CommunicationTabView()
                .tabItem {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                    Text("通讯".localized)
                }
                .tag(3)

            ProfileTabView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("个人".localized)
                }
                .tag(4)

            MoreTabView()
                .tabItem {
                    Image(systemName: "ellipsis")
                    Text("更多".localized)
                }
                .tag(5)
        }
        .tint(ApocalypseTheme.primary)
    }
}

#Preview {
    MainTabView()
}
