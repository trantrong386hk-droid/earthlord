import SwiftUI

struct TerritoryTabView: View {
    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // 标题
                    Text("我的领地")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 20)

                    // 统计卡片行
                    HStack(spacing: 12) {
                        StatCard(
                            icon: "flag.fill",
                            title: "领地数量",
                            number: "2",
                            unit: "块",
                            color: ApocalypseTheme.primary
                        )

                        StatCard(
                            icon: "building.2.fill",
                            title: "建筑",
                            number: "6",
                            unit: "座",
                            color: ApocalypseTheme.success
                        )
                    }

                    // 信息卡片
                    VStack(spacing: 12) {
                        InfoCard(
                            icon: "map.fill",
                            title: "总面积",
                            value: "30,702 m²"
                        )

                        InfoCard(
                            icon: "bolt.fill",
                            title: "能源产出",
                            value: "1,200 kW/天",
                            iconColor: ApocalypseTheme.warning
                        )

                        InfoCard(
                            icon: "leaf.fill",
                            title: "资源储备",
                            value: "充足",
                            iconColor: ApocalypseTheme.success
                        )
                    }

                    // 操作卡片
                    Text("快捷操作")
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 10)

                    VStack(spacing: 12) {
                        ActionCard(
                            icon: "plus.circle.fill",
                            title: "圈占新领地",
                            subtitle: "开始新的开拓之旅"
                        ) {
                            print("圈占新领地")
                        }

                        ActionCard(
                            icon: "hammer.fill",
                            title: "建造建筑",
                            subtitle: "发展你的领地"
                        ) {
                            print("建造建筑")
                        }

                        ActionCard(
                            icon: "chart.bar.fill",
                            title: "领地详情",
                            subtitle: "查看完整统计数据"
                        ) {
                            print("查看详情")
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
    }
}

#Preview {
    TerritoryTabView()
}
