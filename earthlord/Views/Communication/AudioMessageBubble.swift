//
//  AudioMessageBubble.swift
//  earthlord
//
//  音频消息气泡组件
//

import SwiftUI

struct AudioMessageBubble: View {
    let message: ChannelMessage
    let isSentByMe: Bool
    @StateObject private var audioPlayer = AudioPlayerManager.shared

    private var isPlaying: Bool {
        audioPlayer.isPlaying && audioPlayer.currentPlayingURL == message.audioUrl
    }

    private var progress: Double {
        guard let duration = message.audioDuration, duration > 0 else { return 0 }
        return audioPlayer.currentTime / duration
    }

    var body: some View {
        HStack(spacing: 12) {
            // 播放按钮
            Button(action: {
                if let audioUrl = message.audioUrl {
                    audioPlayer.play(from: audioUrl)
                }
            }) {
                ZStack {
                    Circle()
                        .fill(isSentByMe ? Color.white.opacity(0.3) : ApocalypseTheme.primary.opacity(0.3))
                        .frame(width: 40, height: 40)

                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16))
                        .foregroundColor(isSentByMe ? .white : ApocalypseTheme.primary)
                }
            }
            .buttonStyle(PlainButtonStyle())

            // 波形和时长
            VStack(alignment: .leading, spacing: 4) {
                // 波形可视化（简化版）
                HStack(spacing: 2) {
                    ForEach(0..<30, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(isSentByMe ? Color.white.opacity(0.6) : ApocalypseTheme.primary.opacity(0.6))
                            .frame(width: 2, height: CGFloat.random(in: 8...20))
                    }
                }
                .frame(height: 20)

                // 时长显示
                Text(formatDuration())
                    .font(.caption2)
                    .foregroundColor(isSentByMe ? .white.opacity(0.7) : ApocalypseTheme.textSecondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            isSentByMe
                ? ApocalypseTheme.primary
                : ApocalypseTheme.cardBackground
        )
        .cornerRadius(16)
        .overlay(
            // 播放进度条
            GeometryReader { geometry in
                if isPlaying && progress > 0 {
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: geometry.size.width * progress)
                        .cornerRadius(16, corners: [.bottomLeft, .topLeft])
                }
            }
        )
    }

    private func formatDuration() -> String {
        if isPlaying {
            return AudioRecordingManager.formatDuration(audioPlayer.currentTime)
        } else if let duration = message.audioDuration {
            return AudioRecordingManager.formatDuration(duration)
        } else {
            return "0:00"
        }
    }
}

// MARK: - 预览

#Preview {
    VStack(spacing: 12) {
        // 他人发送的音频消息
        AudioMessageBubble(
            message: ChannelMessage(
                messageId: UUID(),
                channelId: UUID(),
                senderId: UUID(),
                senderCallsign: "Alpha-01",
                content: "[语音消息]",
                metadata: MessageMetadata(
                    messageType: "audio",
                    audioUrl: "https://example.com/audio.m4a",
                    audioDuration: 15.5
                ),
                createdAt: Date()
            ),
            isSentByMe: false
        )

        // 我发送的音频消息
        AudioMessageBubble(
            message: ChannelMessage(
                messageId: UUID(),
                channelId: UUID(),
                senderId: UUID(),
                senderCallsign: "Me",
                content: "[语音消息]",
                metadata: MessageMetadata(
                    messageType: "audio",
                    audioUrl: "https://example.com/audio.m4a",
                    audioDuration: 8.2
                ),
                createdAt: Date()
            ),
            isSentByMe: true
        )
    }
    .padding()
    .background(ApocalypseTheme.background)
}
