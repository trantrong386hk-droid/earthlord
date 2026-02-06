//
//  ChannelDetailView.swift
//  earthlord
//
//  频道详情页面
//  展示频道信息、订阅/取消订阅、删除功能
//

import SwiftUI
import Auth

struct ChannelDetailView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var communicationManager = CommunicationManager.shared
    @Environment(\.dismiss) private var dismiss

    let channel: CommunicationChannel

    @State private var isLoading = false
    @State private var showDeleteConfirmation = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showChatView = false

    private var isCreator: Bool {
        authManager.currentUser?.id == channel.creatorId
    }

    private var isSubscribed: Bool {
        communicationManager.isSubscribed(channelId: channel.id)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 频道头像和基本信息
                    headerSection

                    // 频道信息卡片
                    infoCard

                    // 操作按钮
                    actionButtons

                    // 删除按钮（仅创建者可见）
                    if isCreator {
                        deleteButton
                    }
                }
                .padding(20)
            }
            .background(ApocalypseTheme.background)
            .navigationTitle("频道详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .alert("删除频道", isPresented: $showDeleteConfirmation) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    deleteChannel()
                }
            } message: {
                Text("确定要删除频道「\(channel.name)」吗？此操作不可撤销，所有订阅者将失去访问权限。")
            }
            .alert("操作失败", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .fullScreenCover(isPresented: $showChatView) {
                NavigationStack {
                    ChannelChatView(channel: channel)
                }
            }
        }
    }

    // MARK: - 头部区域

    private var headerSection: some View {
        VStack(spacing: 16) {
            // 频道图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.2))
                    .frame(width: 80, height: 80)

                Image(systemName: channel.channelType.iconName)
                    .font(.system(size: 36))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            // 频道名称
            VStack(spacing: 4) {
                Text(channel.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(channel.channelCode)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.primary)
            }

            // 订阅状态标签
            if isSubscribed {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                    Text("已订阅")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.green)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.15))
                .cornerRadius(20)
            }
        }
    }

    // MARK: - 信息卡片

    private var infoCard: some View {
        VStack(spacing: 16) {
            infoRow(icon: "tag.fill", title: "类型", value: channel.channelType.displayName)
            Divider().background(ApocalypseTheme.textSecondary.opacity(0.2))
            infoRow(icon: "person.2.fill", title: "成员", value: "\(channel.memberCount) 人")
            Divider().background(ApocalypseTheme.textSecondary.opacity(0.2))
            infoRow(icon: "calendar", title: "创建时间", value: formatDate(channel.createdAt))

            if let description = channel.description, !description.isEmpty {
                Divider().background(ApocalypseTheme.textSecondary.opacity(0.2))
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(ApocalypseTheme.primary)
                        Text("描述")
                            .foregroundColor(ApocalypseTheme.textSecondary)
                        Spacer()
                    }
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if isCreator {
                Divider().background(ApocalypseTheme.textSecondary.opacity(0.2))
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                    Text("你是频道创建者")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(ApocalypseTheme.primary)
                .frame(width: 24)
            Text(title)
                .foregroundColor(ApocalypseTheme.textSecondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .font(.subheadline)
    }

    // MARK: - 操作按钮

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if isSubscribed {
                // 进入聊天按钮
                Button(action: { showChatView = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "message.fill")
                        Text("进入聊天")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(ApocalypseTheme.primary)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }

                // 取消订阅按钮（创建者不能取消订阅自己的频道）
                if !isCreator {
                    Button(action: unsubscribe) {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView()
                                    .tint(ApocalypseTheme.textPrimary)
                                    .scaleEffect(0.8)
                            }
                            Image(systemName: "bell.slash.fill")
                            Text(isLoading ? "处理中..." : "取消订阅")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(ApocalypseTheme.cardBackground)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(ApocalypseTheme.textSecondary.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .disabled(isLoading)
                }
            } else {
                // 订阅按钮
                Button(action: subscribe) {
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        }
                        Image(systemName: "bell.fill")
                        Text(isLoading ? "处理中..." : "订阅频道")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isLoading ? ApocalypseTheme.textSecondary.opacity(0.3) : ApocalypseTheme.primary)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isLoading)
            }
        }
    }

    // MARK: - 删除按钮

    private var deleteButton: some View {
        Button(action: { showDeleteConfirmation = true }) {
            HStack(spacing: 8) {
                Image(systemName: "trash.fill")
                Text("删除频道")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.red.opacity(0.15))
            .foregroundColor(.red)
            .cornerRadius(12)
        }
        .disabled(isLoading)
    }

    // MARK: - Actions

    private func subscribe() {
        guard let userId = authManager.currentUser?.id else { return }
        isLoading = true

        Task {
            let success = await communicationManager.subscribeToChannel(userId: userId, channelId: channel.id)
            await MainActor.run {
                isLoading = false
                if !success {
                    errorMessage = communicationManager.errorMessage ?? "订阅失败"
                    showError = true
                }
            }
        }
    }

    private func unsubscribe() {
        guard let userId = authManager.currentUser?.id else { return }
        isLoading = true

        Task {
            let success = await communicationManager.unsubscribeFromChannel(userId: userId, channelId: channel.id)
            await MainActor.run {
                isLoading = false
                if !success {
                    errorMessage = communicationManager.errorMessage ?? "取消订阅失败"
                    showError = true
                }
            }
        }
    }

    private func deleteChannel() {
        guard let userId = authManager.currentUser?.id else { return }
        isLoading = true

        Task {
            let success = await communicationManager.deleteChannel(channelId: channel.id, userId: userId)
            await MainActor.run {
                isLoading = false
                if success {
                    dismiss()
                } else {
                    errorMessage = communicationManager.errorMessage ?? "删除失败"
                    showError = true
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

#Preview {
    let mockChannel = CommunicationChannel(
        id: UUID(),
        creatorId: UUID(),
        channelType: .public,
        channelCode: "PUB-TEST",
        name: "测试频道",
        description: "这是一个测试频道的描述信息",
        isActive: true,
        memberCount: 42,
        createdAt: Date(),
        updatedAt: Date()
    )

    return ChannelDetailView(channel: mockChannel)
}
