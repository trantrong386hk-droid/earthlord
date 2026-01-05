//
//  TestMenuView.swift
//  earthlord
//
//  测试模块入口页面
//  注意：不需要 NavigationStack，因为已经在 ContentView 的 NavigationStack 内部
//

import SwiftUI

// MARK: - 测试菜单视图

struct TestMenuView: View {

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            List {
                // MARK: - Supabase 测试
                NavigationLink {
                    SupabaseTestView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "server.rack")
                            .font(.title2)
                            .foregroundColor(ApocalypseTheme.primary)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Supabase 连接测试")
                                .font(.headline)
                                .foregroundColor(ApocalypseTheme.textPrimary)

                            Text("测试后端数据库连接状态")
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(ApocalypseTheme.cardBackground)

                // MARK: - 圈地功能测试
                NavigationLink {
                    TerritoryTestView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "location.circle")
                            .font(.title2)
                            .foregroundColor(ApocalypseTheme.success)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("圈地功能测试")
                                .font(.headline)
                                .foregroundColor(ApocalypseTheme.textPrimary)

                            Text("GPS定位、路径追踪、闭环检测")
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(ApocalypseTheme.cardBackground)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("测试模块")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TestMenuView()
    }
}
