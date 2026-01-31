//
//  ChannelChatView.swift
//  earthlord
//
//  频道聊天界面
//  支持消息发送、实时推送、历史消息加载
//

import SwiftUI
import Auth
import CoreLocation

struct ChannelChatView: View {
    let channel: CommunicationChannel

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var communicationManager = CommunicationManager.shared
    @ObservedObject private var authManager = AuthManager.shared
    @State private var messageText = ""
    @State private var isLoading = true
    @State private var showChannelDetail = false
    @FocusState private var isInputFocused: Bool

    private var currentUserId: UUID? {
        authManager.currentUser?.id
    }

    private var canSend: Bool {
        communicationManager.canSendMessage()
    }

    private var messages: [ChannelMessage] {
        communicationManager.getMessages(for: channel.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 消息列表
            messageListView

            // 输入栏或收音机提示
            if canSend {
                inputBar
            } else {
                radioOnlyNotice
            }
        }
        .background(ApocalypseTheme.background)
        .navigationTitle(channel.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                        Text("返回")
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showChannelDetail = true }) {
                    memberCountBadge
                }
            }
        }
        .sheet(isPresented: $showChannelDetail) {
            ChannelDetailView(channel: channel)
        }
        .onAppear {
            setupChat()
        }
        .onDisappear {
            teardownChat()
        }
    }

    // MARK: - 消息列表

    private var messageListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if isLoading {
                        loadingIndicator
                    } else if messages.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(messages) { message in
                            MessageBubbleView(
                                message: message,
                                isOwnMessage: message.senderId == currentUserId
                            )
                            .id(message.id)
                        }
                    }
                }
                .padding()
            }
            .onChange(of: messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onAppear {
                scrollToBottom(proxy: proxy)
            }
        }
    }

    // MARK: - 加载指示器

    private var loadingIndicator: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
            Text("加载消息中...")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    // MARK: - 空状态

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))
            Text("暂无消息")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textSecondary)
            Text("成为第一个发送消息的人吧")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.7))
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    // MARK: - 输入栏

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("输入消息...", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(20)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .focused($isInputFocused)
                .lineLimit(1...5)

            Button(action: sendMessage) {
                Group {
                    if communicationManager.isSendingMessage {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                    }
                }
                .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? ApocalypseTheme.textSecondary.opacity(0.5)
                    : ApocalypseTheme.primary)
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || communicationManager.isSendingMessage)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.background)
    }

    // MARK: - 收音机提示

    private var radioOnlyNotice: some View {
        HStack(spacing: 8) {
            Image(systemName: "radio")
                .foregroundColor(ApocalypseTheme.textSecondary)
            Text("收音机模式只能接收消息，无法发送")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(ApocalypseTheme.cardBackground.opacity(0.5))
    }

    // MARK: - 成员数徽章

    private var memberCountBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "person.2.fill")
                .font(.caption)
            Text("\(channel.memberCount)")
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(ApocalypseTheme.textSecondary)
    }

    // MARK: - 方法

    private func setupChat() {
        // 调试：打印当前用户 ID
        print("📱 [Chat] 当前用户 ID: \(currentUserId?.uuidString ?? "nil")")

        // 订阅频道消息
        communicationManager.subscribeToChannelMessages(channelId: channel.id)

        // 启动 Realtime 订阅
        communicationManager.startRealtimeSubscription()

        // 加载历史消息
        Task {
            await communicationManager.loadChannelMessages(channelId: channel.id)
            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func teardownChat() {
        // 取消订阅频道消息
        communicationManager.unsubscribeFromChannelMessages(channelId: channel.id)

        // 如果没有其他订阅的频道，停止 Realtime
        if communicationManager.subscribedChannelIds.isEmpty {
            communicationManager.stopRealtimeSubscription()
        }
    }

    private func sendMessage() {
        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        let deviceType = communicationManager.getCurrentDeviceType().rawValue

        // 获取真实 GPS 位置
        let location = LocationManager.shared.userLocation
        let latitude = location?.latitude
        let longitude = location?.longitude

        Task {
            let success = await communicationManager.sendChannelMessage(
                channelId: channel.id,
                content: content,
                latitude: latitude,
                longitude: longitude,
                deviceType: deviceType
            )

            if success {
                await MainActor.run {
                    messageText = ""
                    isInputFocused = false
                }
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastMessage = messages.last else { return }
        withAnimation(.easeOut(duration: 0.3)) {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }
}

// MARK: - 消息气泡组件

struct MessageBubbleView: View {
    let message: ChannelMessage
    let isOwnMessage: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isOwnMessage {
                Spacer(minLength: 60)
            }

            VStack(alignment: isOwnMessage ? .trailing : .leading, spacing: 4) {
                // 发送者信息（非自己的消息）
                if !isOwnMessage {
                    senderInfo
                }

                // 消息内容
                messageContent

                // 时间
                timeLabel
            }

            if !isOwnMessage {
                Spacer(minLength: 60)
            }
        }
    }

    // MARK: - 发送者信息

    private var senderInfo: some View {
        HStack(spacing: 4) {
            // 设备图标
            if let deviceType = message.deviceType,
               let device = DeviceType(rawValue: deviceType) {
                Image(systemName: device.iconName)
                    .font(.system(size: 10))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 呼号
            Text(message.senderCallsign ?? "未知用户")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    // MARK: - 消息内容

    private var messageContent: some View {
        Text(message.content)
            .font(.body)
            .foregroundColor(isOwnMessage ? .white : ApocalypseTheme.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                isOwnMessage
                    ? ApocalypseTheme.primary
                    : ApocalypseTheme.cardBackground
            )
            .cornerRadius(16)
    }

    // MARK: - 时间标签

    private var timeLabel: some View {
        Text(message.timeAgo)
            .font(.system(size: 10))
            .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.7))
    }
}

#Preview {
    NavigationStack {
        ChannelChatView(channel: CommunicationChannel(
            id: UUID(),
            creatorId: UUID(),
            channelType: .public,
            channelCode: "PUB-001",
            name: "测试频道",
            description: "这是一个测试频道",
            isActive: true,
            memberCount: 15,
            createdAt: Date(),
            updatedAt: Date()
        ))
    }
}
