import SwiftUI

struct MoreTabView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // 开发者工具区域
                        VStack(alignment: .leading, spacing: 12) {
                            Text("开发者工具")
                                .font(.headline)
                                .foregroundColor(ApocalypseTheme.textPrimary)
                                .padding(.horizontal, 4)

                            // Supabase 测试入口
                            NavigationLink {
                                SupabaseTestView()
                            } label: {
                                ActionCard(
                                    icon: "server.rack",
                                    title: "Supabase 连接测试",
                                    subtitle: "测试后端服务连接状态"
                                ) {}
                            }
                            .buttonStyle(.plain)
                        }

                        // 设置区域
                        VStack(alignment: .leading, spacing: 12) {
                            Text("设置")
                                .font(.headline)
                                .foregroundColor(ApocalypseTheme.textPrimary)
                                .padding(.horizontal, 4)
                                .padding(.top, 10)

                            ActionCard(
                                icon: "gearshape.fill",
                                title: "通用设置",
                                subtitle: "语言、通知、隐私"
                            ) {
                                print("通用设置")
                            }

                            ActionCard(
                                icon: "person.circle.fill",
                                title: "账户管理",
                                subtitle: "登录、注销、数据同步"
                            ) {
                                print("账户管理")
                            }

                            ActionCard(
                                icon: "info.circle.fill",
                                title: "关于",
                                subtitle: "版本信息、开发者"
                            ) {
                                print("关于")
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("更多")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    MoreTabView()
}
