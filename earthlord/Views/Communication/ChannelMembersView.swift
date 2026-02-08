//
//  ChannelMembersView.swift
//  earthlord
//
//  频道成员列表页面
//  显示订阅该频道的所有成员
//

import SwiftUI
import Auth

struct ChannelMembersView: View {
    let channel: CommunicationChannel

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var communicationManager = CommunicationManager.shared

    @State private var members: [ChannelMember] = []
    @State private var isLoading = true
    @State private var showChannelDetail = false

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                if isLoading {
                    loadingView
                } else if members.isEmpty {
                    emptyStateView
                } else {
                    membersList
                }
            }
            .navigationTitle("频道成员")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showChannelDetail = true }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(ApocalypseTheme.primary)
                    }
                }
            }
            .sheet(isPresented: $showChannelDetail) {
                ChannelDetailView(channel: channel)
            }
            .task {
                await loadMembers()
            }
        }
    }

    // MARK: - 成员列表

    private var membersList: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 头部统计卡片
                headerCard
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                // 成员列表
                LazyVStack(spacing: 12) {
                    ForEach(members) { member in
                        MemberRow(member: member, channelName: channel.name)
                    }
                }
                .padding(16)
            }
        }
    }

    // MARK: - 头部统计卡片

    private var headerCard: some View {
        ApocalypseCard(padding: 16) {
            HStack(spacing: 20) {
                // 频道图标
                ZStack {
                    Circle()
                        .fill(ApocalypseTheme.primary.opacity(0.2))
                        .frame(width: 60, height: 60)

                    Image(systemName: channel.channelType.iconName)
                        .font(.system(size: 28))
                        .foregroundColor(ApocalypseTheme.primary)
                }

                // 频道信息
                VStack(alignment: .leading, spacing: 6) {
                    Text(channel.name)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    HStack(spacing: 6) {
                        Image(systemName: "person.2.fill")
                            .font(.caption)
                        Text("\(members.count) 位成员")
                            .font(.caption)
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }

                Spacer()
            }
        }
    }

    // MARK: - 加载状态

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
            Text("加载成员中...")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    // MARK: - 空状态

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 40))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))

            Text("暂无成员")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("还没有人订阅这个频道")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.7))
        }
    }

    // MARK: - 方法

    private func loadMembers() async {
        isLoading = true
        members = await communicationManager.loadChannelMembers(
            channelId: channel.id,
            creatorId: channel.creatorId
        )
        isLoading = false
    }
}

// MARK: - 成员行组件

private struct MemberRow: View {
    let member: ChannelMember
    let channelName: String

    var body: some View {
        ApocalypseCard(padding: 14) {
            HStack(spacing: 14) {
                // 左侧：用户头像（使用设备图标或默认头像）
                ZStack {
                    Circle()
                        .fill(member.isCreator ? ApocalypseTheme.warning.opacity(0.2) : ApocalypseTheme.primary.opacity(0.15))
                        .frame(width: 50, height: 50)

                    if let deviceType = member.deviceType {
                        Image(systemName: deviceType.iconName)
                            .font(.title3)
                            .foregroundColor(member.isCreator ? ApocalypseTheme.warning : ApocalypseTheme.primary)
                    } else {
                        Image(systemName: "person.fill")
                            .font(.title3)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }

                    // 创建者皇冠徽章
                    if member.isCreator {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.yellow)
                            .offset(x: 18, y: -18)
                    }
                }

                // 中间：用户信息
                VStack(alignment: .leading, spacing: 6) {
                    // 呼号
                    HStack(spacing: 6) {
                        Text(member.callsign ?? "未知用户")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        if member.isCreator {
                            Text("创建者")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.yellow)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(ApocalypseTheme.warning.opacity(0.2))
                                )
                        }
                    }

                    // 设备和加入时间
                    HStack(spacing: 8) {
                        // 设备类型
                        if let deviceType = member.deviceType {
                            HStack(spacing: 4) {
                                Image(systemName: deviceType.iconName)
                                    .font(.caption2)
                                Text(deviceType.displayName)
                                    .font(.caption)
                            }
                            .foregroundColor(ApocalypseTheme.textSecondary)
                        }

                        if member.deviceType != nil {
                            Text("·")
                                .foregroundColor(ApocalypseTheme.textMuted)
                        }

                        // 加入时间
                        Text(member.joinedTimeAgo)
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }

                Spacer()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ChannelMembersView(channel: CommunicationChannel(
        id: UUID(),
        creatorId: UUID(),
        channelType: .`public`,
        channelCode: "PUB-001",
        name: "测试频道",
        description: "这是一个测试频道",
        isActive: true,
        memberCount: 15,
        createdAt: Date(),
        updatedAt: Date()
    ))
}
