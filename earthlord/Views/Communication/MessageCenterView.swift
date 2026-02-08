//
//  MessageCenterView.swift
//  earthlord
//
//  消息中心 - 聚合所有频道的最新消息
//

import SwiftUI
import Auth

struct MessageCenterView: View {
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var communicationManager: CommunicationManager

    @State private var showingOfficialChannel = false
    @State private var showingChat = false
    @State private var selectedChannel: CommunicationChannel?
    @State private var isLoading = false

    var channelSummaries: [CommunicationManager.ChannelSummary] {
        communicationManager.getChannelSummaries()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if channelSummaries.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(channelSummaries) { summary in
                                Button(action: {
                                    selectedChannel = summary.channel
                                    if summary.channel.channelType == .official {
                                        showingOfficialChannel = true
                                    } else {
                                        showingChat = true
                                    }
                                }) {
                                    MessageRowView(
                                        channel: summary.channel,
                                        lastMessage: summary.lastMessage,
                                        unreadCount: summary.unreadCount,
                                        currentUserId: authManager.currentUser?.id
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("消息中心")
                        .font(.headline)
                        .foregroundColor(.white)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: refreshMessages) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(ApocalypseTheme.primary)
                    }
                }
            }
            .navigationDestination(isPresented: $showingOfficialChannel) {
                if let channel = selectedChannel {
                    OfficialChannelDetailView(channel: channel)
                        .environmentObject(authManager)
                        .environmentObject(communicationManager)
                }
            }
            .navigationDestination(isPresented: $showingChat) {
                if let channel = selectedChannel {
                    ChannelChatView(channel: channel)
                }
            }
            .onAppear {
                loadMessages()
            }
        }
    }

    // MARK: - 空状态视图

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))

            Text("暂无消息")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("订阅频道后，消息将在这里显示")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 加载消息

    private func loadMessages() {
        guard !isLoading else { return }

        isLoading = true
        Task {
            if let userId = authManager.currentUser?.id {
                await communicationManager.loadSubscribedChannels(userId: userId)
                await communicationManager.loadAllChannelLatestMessages()
            }
            isLoading = false
        }
    }

    private func refreshMessages() {
        loadMessages()
    }
}

// MARK: - 预览

#Preview {
    NavigationStack {
        MessageCenterView()
            .environmentObject(AuthManager.shared)
            .environmentObject(CommunicationManager.shared)
    }
}
