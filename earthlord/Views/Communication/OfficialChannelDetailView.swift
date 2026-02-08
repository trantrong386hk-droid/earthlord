//
//  OfficialChannelDetailView.swift
//  earthlord
//
//  官方频道详情页 - 带消息分类过滤
//

import SwiftUI
import Auth

struct OfficialChannelDetailView: View {
    let channel: CommunicationChannel

    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var communicationManager: CommunicationManager

    @State private var selectedCategory: MessageCategory?  // nil 表示"全部"
    @State private var isLoadingMessages = false

    // 过滤后的消息
    private var filteredMessages: [ChannelMessage] {
        let allMessages = communicationManager.getMessages(for: channel.id)

        guard let category = selectedCategory else {
            return allMessages  // 显示全部
        }

        return allMessages.filter { $0.category == category }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 分类过滤器
            categoryFilterBar
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(ApocalypseTheme.background)

            Divider()
                .background(ApocalypseTheme.textSecondary.opacity(0.3))

            // 消息列表
            if isLoadingMessages {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredMessages.isEmpty {
                emptyStateView
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredMessages) { message in
                                OfficialMessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding(16)
                    }
                    .background(ApocalypseTheme.background)
                    .onAppear {
                        // 滚动到最新消息
                        if let lastMessage = filteredMessages.last {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .navigationTitle("官方公告")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Image(systemName: "megaphone.fill")
                        .font(.system(size: 16))
                        .foregroundColor(ApocalypseTheme.primary)

                    Text("官方公告")
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
            }
        }
        .onAppear {
            loadMessages()
            communicationManager.subscribeToChannelMessages(channelId: channel.id)
        }
        .onDisappear {
            communicationManager.unsubscribeFromChannelMessages(channelId: channel.id)
        }
    }

    // MARK: - 分类过滤栏

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // "全部"选项
                MessageCategoryChip(
                    label: "全部",
                    isSelected: selectedCategory == nil,
                    iconName: "list.bullet",
                    color: .gray
                ) {
                    selectedCategory = nil
                }

                // 各分类
                ForEach(MessageCategory.allCases, id: \.self) { category in
                    MessageCategoryChip(
                        label: category.displayName,
                        isSelected: selectedCategory == category,
                        iconName: category.iconName,
                        color: category.color
                    ) {
                        selectedCategory = category
                    }
                }
            }
        }
    }

    // MARK: - 空状态视图

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: selectedCategory != nil ? "tray" : "megaphone")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))

            Text(selectedCategory != nil ? "该分类暂无消息" : "暂无官方公告")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            if selectedCategory != nil {
                Text("试试查看其他分类")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ApocalypseTheme.background)
    }

    // MARK: - 加载消息

    private func loadMessages() {
        isLoadingMessages = true
        Task {
            await communicationManager.loadChannelMessages(channelId: channel.id)
            isLoadingMessages = false
        }
    }
}

// MARK: - 分类标签按钮

struct MessageCategoryChip: View {
    let label: String
    let isSelected: Bool
    let iconName: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: 12))

                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                isSelected ? color.opacity(0.2) : ApocalypseTheme.cardBackground
            )
            .foregroundColor(isSelected ? color : ApocalypseTheme.textSecondary)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 官方消息气泡

struct OfficialMessageBubble: View {
    let message: ChannelMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 分类标签（如果有）
            if let category = message.category {
                HStack(spacing: 6) {
                    Image(systemName: category.iconName)
                        .font(.system(size: 12))

                    Text(category.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(category.color)
                .cornerRadius(12)
            }

            // 消息内容
            Text(message.content)
                .font(.body)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            // 时间
            Text(message.timeAgo)
                .font(.caption2)
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.7))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    message.category != nil
                        ? message.category!.color.opacity(0.3)
                        : Color.clear,
                    lineWidth: 1
                )
        )
    }
}

// MARK: - 预览

#Preview {
    NavigationStack {
        OfficialChannelDetailView(
            channel: CommunicationChannel(
                id: CommunicationManager.officialChannelId,
                creatorId: UUID(),
                channelType: .official,
                channelCode: "OFF-MAIN",
                name: "官方频道",
                description: "官方公告频道",
                isActive: true,
                memberCount: 0,
                createdAt: Date(),
                updatedAt: Date()
            )
        )
        .environmentObject(AuthManager.shared)
        .environmentObject(CommunicationManager.shared)
    }
}
