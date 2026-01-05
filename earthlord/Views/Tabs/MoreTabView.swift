import SwiftUI

struct MoreTabView: View {
    @ObservedObject private var languageManager = LanguageManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // 开发者工具区域
                        VStack(alignment: .leading, spacing: 12) {
                            Text("开发者工具".localized)
                                .font(.headline)
                                .foregroundColor(ApocalypseTheme.textPrimary)
                                .padding(.horizontal, 4)

                            // Supabase 测试入口
                            NavigationLink(destination: SupabaseTestView()) {
                                ApocalypseCard {
                                    HStack(spacing: 16) {
                                        Image(systemName: "server.rack")
                                            .font(.title)
                                            .foregroundColor(ApocalypseTheme.primary)
                                            .frame(width: 50, height: 50)
                                            .background(ApocalypseTheme.primary.opacity(0.15))
                                            .cornerRadius(10)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Supabase 连接测试".localized)
                                                .font(.headline)
                                                .foregroundColor(ApocalypseTheme.textPrimary)
                                            Text("测试后端服务连接状态".localized)
                                                .font(.caption)
                                                .foregroundColor(ApocalypseTheme.textSecondary)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(ApocalypseTheme.textMuted)
                                    }
                                }
                            }

                            // 圈地测试入口
                            NavigationLink(destination: TerritoryTestView()) {
                                ApocalypseCard {
                                    HStack(spacing: 16) {
                                        Image(systemName: "location.circle")
                                            .font(.title)
                                            .foregroundColor(ApocalypseTheme.success)
                                            .frame(width: 50, height: 50)
                                            .background(ApocalypseTheme.success.opacity(0.15))
                                            .cornerRadius(10)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("圈地功能测试".localized)
                                                .font(.headline)
                                                .foregroundColor(ApocalypseTheme.textPrimary)
                                            Text("GPS定位、路径追踪、调试日志".localized)
                                                .font(.caption)
                                                .foregroundColor(ApocalypseTheme.textSecondary)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(ApocalypseTheme.textMuted)
                                    }
                                }
                            }
                        }

                        // 设置区域
                        VStack(alignment: .leading, spacing: 12) {
                            Text("设置".localized)
                                .font(.headline)
                                .foregroundColor(ApocalypseTheme.textPrimary)
                                .padding(.horizontal, 4)
                                .padding(.top, 10)

                            ActionCard(
                                icon: "gearshape.fill",
                                title: "通用设置".localized,
                                subtitle: "语言、通知、隐私".localized
                            ) {
                                print("通用设置")
                            }

                            ActionCard(
                                icon: "person.circle.fill",
                                title: "账户管理".localized,
                                subtitle: "登录、注销、数据同步".localized
                            ) {
                                print("账户管理")
                            }

                            ActionCard(
                                icon: "info.circle.fill",
                                title: "关于".localized,
                                subtitle: "版本信息、开发者".localized
                            ) {
                                print("关于")
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
