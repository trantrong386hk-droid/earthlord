//
//  ChannelCenterView.swift
//  earthlord
//
//  频道中心页面
//  支持 Tab 切换：我的频道 / 发现频道
//

import SwiftUI
import Auth

struct ChannelCenterView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var communicationManager = CommunicationManager.shared

    @State private var selectedTab = 0  // 0: 我的频道, 1: 发现频道
    @State private var searchText = ""
    @State private var showCreateSheet = false
    @State private var selectedChannelForDetail: CommunicationChannel?
    @State private var selectedChannelForChat: CommunicationChannel?

    var body: some View {
        VStack(spacing: 0) {
            // 顶部 Tab 切换
            tabSelector

            // 搜索栏
            searchBar

            // 频道列表
            if communicationManager.isLoading {
                loadingView
            } else {
                channelList
            }
        }
        .background(ApocalypseTheme.background)
        .sheet(isPresented: $showCreateSheet) {
            CreateChannelSheet(onChannelCreated: { _ in
                showCreateSheet = false
            })
        }
        .sheet(item: $selectedChannelForDetail) { channel in
            ChannelDetailView(channel: channel)
        }
        .fullScreenCover(item: $selectedChannelForChat) { channel in
            NavigationStack {
                ChannelChatView(channel: channel)
            }
        }
        .task {
            await loadData()
        }
    }

    // MARK: - Tab 选择器

    private var tabSelector: some View {
        HStack(spacing: 0) {
            tabButton(title: "我的频道", index: 0)
            tabButton(title: "发现频道", index: 1)

            Spacer()

            // 创建按钮
            Button(action: { showCreateSheet = true }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(ApocalypseTheme.primary)
            }
            .padding(.trailing, 16)
        }
        .padding(.vertical, 12)
        .background(ApocalypseTheme.cardBackground)
    }

    private func tabButton(title: String, index: Int) -> some View {
        Button(action: { selectedTab = index }) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(selectedTab == index ? .semibold : .regular)
                    .foregroundColor(selectedTab == index ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)

                Rectangle()
                    .fill(selectedTab == index ? ApocalypseTheme.primary : Color.clear)
                    .frame(height: 2)
            }
        }
        .frame(width: 100)
    }

    // MARK: - 搜索栏

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(ApocalypseTheme.textSecondary)

            TextField("搜索频道...", text: $searchText)
                .textFieldStyle(.plain)
                .foregroundColor(ApocalypseTheme.textPrimary)

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
        .padding(10)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(8)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - 频道列表

    private var channelList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if selectedTab == 0 {
                    // 我的频道
                    if filteredSubscribedChannels.isEmpty {
                        emptyMyChannelsView
                    } else {
                        ForEach(filteredSubscribedChannels) { subscribedChannel in
                            channelRow(subscribedChannel.channel, isSubscribed: true)
                        }
                    }
                } else {
                    // 发现频道
                    if filteredDiscoverChannels.isEmpty {
                        emptyDiscoverView
                    } else {
                        ForEach(filteredDiscoverChannels) { channel in
                            channelRow(channel, isSubscribed: communicationManager.isSubscribed(channelId: channel.id))
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - 频道行

    private func channelRow(_ channel: CommunicationChannel, isSubscribed: Bool) -> some View {
        let isCreator = authManager.currentUser?.id == channel.creatorId

        return Button(action: {
            // 所有频道点击都先显示详情
            selectedChannelForDetail = channel
        }) {
            HStack(spacing: 12) {
                // 图标
                ZStack {
                    Circle()
                        .fill(isCreator ? ApocalypseTheme.warning.opacity(0.2) : ApocalypseTheme.primary.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: channel.channelType.iconName)
                        .font(.system(size: 20))
                        .foregroundColor(isCreator ? ApocalypseTheme.warning : ApocalypseTheme.primary)

                    // 创建者皇冠徽章
                    if isCreator {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow)
                            .offset(x: 16, y: -16)
                    }
                }

                // 频道信息
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(channel.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        // 创建者或订阅标记
                        if isCreator {
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
                        } else if isSubscribed {
                            HStack(spacing: 2) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 10))
                                Text("已订阅")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.green)
                        }
                    }

                    HStack(spacing: 8) {
                        Text(channel.channelCode)
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.primary)

                        Text("·")
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        Text("\(channel.memberCount) 成员")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        // 显示距离（如果可用）
                        if let distance = communicationManager.calculateChannelDistance(channel),
                           let distanceText = communicationManager.formatDistance(distance) {
                            Text("·")
                                .foregroundColor(ApocalypseTheme.textSecondary)

                            HStack(spacing: 3) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 9))
                                Text(distanceText)
                                    .font(.caption)
                            }
                            .foregroundColor(ApocalypseTheme.success)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding(12)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 空状态视图

    private var emptyMyChannelsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 40))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))

            Text("还没有订阅频道")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Button(action: { selectedTab = 1 }) {
                Text("去发现频道")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.primary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var emptyDiscoverView: some View {
        VStack(spacing: 16) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 40))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))

            Text(searchText.isEmpty ? "暂无公开频道" : "未找到匹配频道")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Button(action: { showCreateSheet = true }) {
                Text("创建第一个频道")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.primary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .tint(ApocalypseTheme.primary)
            Spacer()
        }
    }

    // MARK: - 过滤后的数据

    private var filteredSubscribedChannels: [SubscribedChannel] {
        if searchText.isEmpty {
            return communicationManager.subscribedChannels
        }
        return communicationManager.subscribedChannels.filter {
            $0.channel.name.localizedCaseInsensitiveContains(searchText) ||
            $0.channel.channelCode.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredDiscoverChannels: [CommunicationChannel] {
        // 获取所有已订阅的频道 ID
        let subscribedChannelIds = Set(communicationManager.subscribedChannels.map { $0.channel.id })

        // 过滤出未订阅的频道
        let unsubscribedChannels = communicationManager.channels.filter { channel in
            !subscribedChannelIds.contains(channel.id)
        }

        // 再应用搜索过滤
        if searchText.isEmpty {
            return unsubscribedChannels
        }
        return unsubscribedChannels.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.channelCode.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - 加载数据

    private func loadData() async {
        guard let userId = authManager.currentUser?.id else { return }
        await communicationManager.loadPublicChannels()
        await communicationManager.loadSubscribedChannels(userId: userId)
    }
}

#Preview {
    ChannelCenterView()
}
