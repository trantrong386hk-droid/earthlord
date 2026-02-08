//
//  MessageRowView.swift
//  earthlord
//
//  频道消息行组件 - 用于消息中心列表
//

import SwiftUI

struct MessageRowView: View {
    let channel: CommunicationChannel
    let lastMessage: ChannelMessage?
    let unreadCount: Int
    let currentUserId: UUID?

    // 判断是否是创建者
    private var isCreator: Bool {
        guard let userId = currentUserId else { return false }
        return channel.creatorId == userId
    }

    // 始终返回 true，因为显示在消息中心的都是已订阅的频道
    private var isSubscribed: Bool {
        return !isCreator  // 如果不是创建者，就显示已订阅
    }

    var body: some View {
        HStack(spacing: 12) {
            // 左侧：频道图标（创建者黄色，其他橙色）
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
                // 第一行：频道名称 + 创建者/已订阅标记
                HStack(spacing: 6) {
                    Text(channel.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .lineLimit(1)

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

                // 第二行：频道代码 · 成员数 · 最新消息
                HStack(spacing: 8) {
                    Text(channel.channelCode)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.primary)

                    Text("·")
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Text("\(channel.memberCount) 成员")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    // 最新消息预览
                    if let message = lastMessage {
                        Text("·")
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        Text(message.isAudioMessage ? "[语音消息]" : message.content)
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // 右侧信息
            VStack(alignment: .trailing, spacing: 4) {
                // 时间
                if let message = lastMessage {
                    Text(message.timeAgo)
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.6))
                }

                // 未读数量徽章
                if unreadCount > 0 {
                    Text("\(unreadCount)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ApocalypseTheme.primary)
                        .cornerRadius(8)
                }
            }
        }
        .padding(12)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - 预览

#Preview {
    VStack(spacing: 12) {
        // 官方频道示例（创建者）
        MessageRowView(
            channel: CommunicationChannel(
                id: CommunicationManager.officialChannelId,
                creatorId: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                channelType: .official,
                channelCode: "OFF-MAIN",
                name: "官方频道",
                description: "官方公告",
                isActive: true,
                memberCount: 100,
                createdAt: Date(),
                updatedAt: Date()
            ),
            lastMessage: ChannelMessage(
                messageId: UUID(),
                channelId: UUID(),
                senderId: nil,
                senderCallsign: nil,
                content: "欢迎来到地球领主！这是官方公告频道。",
                metadata: MessageMetadata(category: "news"),
                createdAt: Date().addingTimeInterval(-300)
            ),
            unreadCount: 3,
            currentUserId: UUID(uuidString: "00000000-0000-0000-0000-000000000001")
        )

        // 普通频道示例（已订阅）
        MessageRowView(
            channel: CommunicationChannel(
                id: UUID(),
                creatorId: UUID(),
                channelType: .walkie,
                channelCode: "WLK-001",
                name: "生存者联盟",
                description: "互助频道",
                isActive: true,
                memberCount: 15,
                createdAt: Date(),
                updatedAt: Date()
            ),
            lastMessage: ChannelMessage(
                messageId: UUID(),
                channelId: UUID(),
                senderId: UUID(),
                senderCallsign: "Alpha-01",
                content: "有人在附近吗？需要物资补给。",
                metadata: nil,
                createdAt: Date().addingTimeInterval(-60)
            ),
            unreadCount: 0,
            currentUserId: UUID(uuidString: "00000000-0000-0000-0000-000000000002")
        )

        // 语音消息示例
        MessageRowView(
            channel: CommunicationChannel(
                id: UUID(),
                creatorId: UUID(),
                channelType: .camp,
                channelCode: "CMP-042",
                name: "营地广播",
                description: nil,
                isActive: true,
                memberCount: 5,
                createdAt: Date(),
                updatedAt: Date()
            ),
            lastMessage: ChannelMessage(
                messageId: UUID(),
                channelId: UUID(),
                senderId: UUID(),
                senderCallsign: "Beta-03",
                content: "[语音消息]",
                metadata: MessageMetadata(
                    messageType: "audio",
                    audioUrl: "https://example.com/audio.m4a",
                    audioDuration: 8.5
                ),
                createdAt: Date().addingTimeInterval(-120)
            ),
            unreadCount: 1,
            currentUserId: UUID(uuidString: "00000000-0000-0000-0000-000000000002")
        )
    }
    .padding()
    .background(ApocalypseTheme.background)
}
