//
//  PTTCallView.swift
//  earthlord
//
//  PTT通话界面 - 支持文字和语音消息
//

import SwiftUI
import Auth
import CoreLocation

// MARK: - 消息模式枚举

enum MessageMode: Hashable {
    case text
    case voice

    var iconName: String {
        switch self {
        case .text: return "text.bubble.fill"
        case .voice: return "waveform"
        }
    }

    var displayName: String {
        switch self {
        case .text: return "文字"
        case .voice: return "语音"
        }
    }
}

struct PTTCallView: View {
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var communicationManager: CommunicationManager
    @StateObject private var audioRecorder = AudioRecordingManager.shared

    @State private var selectedChannelIndex = 0
    @State private var messageContent = ""
    @State private var isPressing = false
    @State private var showSuccessToast = false
    @State private var isSending = false
    @State private var messageMode: MessageMode = .text
    @State private var recordingURL: URL?
    @State private var showPermissionAlert = false
    @FocusState private var isTextEditorFocused: Bool

    // 排除官方频道的订阅列表
    private var availableChannels: [SubscribedChannel] {
        communicationManager.subscribedChannels.filter {
            $0.channel.channelType != .official
        }
    }

    private var selectedChannel: CommunicationChannel? {
        guard !availableChannels.isEmpty, selectedChannelIndex < availableChannels.count else {
            return nil
        }
        return availableChannels[selectedChannelIndex].channel
    }

    private var currentDevice: CommunicationDevice? {
        communicationManager.currentDevice
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                if availableChannels.isEmpty {
                    emptyStateView
                } else {
                    VStack(spacing: 12) {
                        // 当前频道信息卡片
                        currentChannelInfoCard
                            .padding(.top, 8)

                        // 频道切换标签栏
                        channelTabBar

                        // 模式切换器
                        modeSwitcher

                        // 根据模式显示不同的输入区
                        if messageMode == .text {
                            messageInputArea
                        } else {
                            recordingIndicator
                        }

                        // PTT按钮
                        pttButton

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }

                // 成功提示
                if showSuccessToast {
                    successToastView
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("PTT通话")
                        .font(.headline)
                        .foregroundColor(.white)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if isTextEditorFocused {
                        Button("完成") {
                            isTextEditorFocused = false
                        }
                        .foregroundColor(ApocalypseTheme.primary)
                    }
                }
            }
            .onTapGesture {
                isTextEditorFocused = false
            }
            .alert("需要麦克风权限", isPresented: $showPermissionAlert) {
                Button("去设置", role: .none) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("取消", role: .cancel) {
                    messageMode = .text
                }
            } message: {
                Text("请在设置中允许「地球领主」访问麦克风，以使用语音消息功能。")
            }
        }
    }

    // MARK: - 当前频道信息卡片

    private var currentChannelInfoCard: some View {
        HStack(spacing: 14) {
            if let channel = selectedChannel, let device = currentDevice {
                // 左侧：频道类型图标
                ZStack {
                    Circle()
                        .fill(ApocalypseTheme.primary.opacity(0.2))
                        .frame(width: 50, height: 50)

                    Image(systemName: channel.channelType.iconName)
                        .font(.system(size: 24))
                        .foregroundColor(ApocalypseTheme.primary)
                }

                // 中间：频道信息
                VStack(alignment: .leading, spacing: 4) {
                    // 频道代码（大号粗体）
                    Text(channel.channelCode)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(ApocalypseTheme.primary)

                    // 频道名称
                    Text(channel.name)
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    // 设备信息
                    HStack(spacing: 6) {
                        Image(systemName: device.deviceType.iconName)
                            .font(.system(size: 12))

                        Text(device.deviceType.displayName)
                            .font(.caption)

                        Text("·")
                            .font(.caption)

                        Text(device.deviceType.rangeText)
                            .font(.caption)
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }

                Spacer()

                // 右侧：状态指示器
                VStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)

                    Text("在线")
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(ApocalypseTheme.primary.opacity(0.3), lineWidth: 2)
        )
    }

    // MARK: - 频道切换标签栏

    private var channelTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(availableChannels.enumerated()), id: \.offset) { index, subscribedChannel in
                    ChannelTabButton(
                        channel: subscribedChannel.channel,
                        isSelected: selectedChannelIndex == index
                    ) {
                        selectedChannelIndex = index
                    }
                }
            }
        }
        .frame(height: 60)
    }

    // MARK: - 模式切换器

    private var modeSwitcher: some View {
        HStack(spacing: 0) {
            ForEach([MessageMode.text, MessageMode.voice], id: \.self) { mode in
                Button(action: {
                    if mode == .voice {
                        // 检查麦克风权限
                        Task {
                            let hasPermission = await audioRecorder.requestPermission()
                            await MainActor.run {
                                if hasPermission {
                                    messageMode = mode
                                } else {
                                    showPermissionAlert = true
                                }
                            }
                        }
                    } else {
                        messageMode = mode
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: mode.iconName)
                            .font(.system(size: 14))

                        Text(mode.displayName)
                            .font(.subheadline)
                            .fontWeight(messageMode == mode ? .semibold : .regular)
                    }
                    .foregroundColor(messageMode == mode ? .white : ApocalypseTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        messageMode == mode
                            ? ApocalypseTheme.primary
                            : Color.clear
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(ApocalypseTheme.textSecondary.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - 消息输入区（文字模式）

    private var messageInputArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("呼叫内容")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.textSecondary)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $messageContent)
                    .font(.body)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .frame(height: 100)
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isTextEditorFocused
                                    ? ApocalypseTheme.primary.opacity(0.5)
                                    : ApocalypseTheme.textSecondary.opacity(0.2),
                                lineWidth: isTextEditorFocused ? 2 : 1
                            )
                    )
                    .focused($isTextEditorFocused)

                if messageContent.isEmpty {
                    Text("在此输入呼叫内容...")
                        .font(.body)
                        .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    // MARK: - 录音指示器（语音模式）

    private var recordingIndicator: some View {
        VStack(spacing: 16) {
            if audioRecorder.isRecording {
                // 录音波形动画
                HStack(spacing: 4) {
                    ForEach(0..<5, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(ApocalypseTheme.primary)
                            .frame(width: 4)
                            .frame(height: animatingHeight(for: index))
                            .animation(
                                Animation.easeInOut(duration: 0.5)
                                    .repeatForever()
                                    .delay(Double(index) * 0.1),
                                value: audioRecorder.isRecording
                            )
                    }
                }
                .frame(height: 60)

                // 录音时长
                Text(AudioRecordingManager.formatDuration(audioRecorder.recordingDuration))
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(ApocalypseTheme.primary)

                Text("正在录音...")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            } else {
                // 未录音状态
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.3))

                Text("按住下方按钮开始录音")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("最长60秒")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.7))
            }
        }
        .frame(height: 100)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    private func animatingHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 20
        let maxHeight: CGFloat = 60
        if audioRecorder.isRecording {
            return CGFloat.random(in: baseHeight...maxHeight)
        }
        return baseHeight
    }

    // MARK: - PTT按钮

    private var pttButton: some View {
        let isDisabled = isSending || (messageMode == .text && messageContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        return VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        isDisabled
                            ? ApocalypseTheme.textSecondary.opacity(0.2)
                            : isPressing
                                ? (messageMode == .voice ? Color.red.opacity(0.8) : ApocalypseTheme.textSecondary.opacity(0.3))
                                : ApocalypseTheme.primary
                    )
                    .frame(width: 120, height: 120)

                VStack(spacing: 6) {
                    Image(systemName: messageMode == .voice ? "mic.fill" : "paperplane.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(isDisabled ? 0.4 : 1.0))

                    Text(buttonText)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(isDisabled ? 0.4 : 1.0))
                        .multilineTextAlignment(.center)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressing && !isDisabled {
                            handlePressStart()
                        }
                    }
                    .onEnded { _ in
                        if !isDisabled {
                            handlePressEnd()
                        }
                    }
            )
            .allowsHitTesting(!isDisabled)

            Text(instructionText)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.7))
        }
    }

    private var buttonText: String {
        if isSending {
            return "发送中..."
        }

        if messageMode == .voice {
            return isPressing ? "松开发送" : "按住说话"
        } else {
            return isPressing ? "发送中..." : "按住发送"
        }
    }

    private var instructionText: String {
        if messageMode == .voice {
            return audioRecorder.isRecording ? "松开按钮发送" : "长按录制语音"
        } else {
            return messageContent.isEmpty ? "请先输入呼叫内容" : "长按按钮发送"
        }
    }

    // MARK: - 空状态视图

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))

            Text("暂无可用频道")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("请先订阅频道")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 成功提示

    private var successToastView: some View {
        VStack {
            Spacer()

            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)

                Text("消息已发送")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(25)
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            .padding(.bottom, 50)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(), value: showSuccessToast)
    }

    // MARK: - 按钮交互处理

    private func handlePressStart() {
        isPressing = true

        // 震动反馈
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // 语音模式：开始录音
        if messageMode == .voice {
            do {
                recordingURL = try audioRecorder.startRecording()
            } catch {
                print("❌ [PTT] 开始录音失败: \(error)")
            }
        }
    }

    private func handlePressEnd() {
        isPressing = false
        isTextEditorFocused = false

        // 语音模式：停止录音并发送
        if messageMode == .voice {
            if let url = audioRecorder.stopRecording() {
                recordingURL = url
                sendVoiceMessage(audioURL: url, duration: audioRecorder.recordingDuration)
            }
        } else {
            // 文字模式：发送文字
            sendTextMessage()
        }
    }

    // MARK: - 发送消息

    private func sendTextMessage() {
        guard let channel = selectedChannel,
              let userId = authManager.currentUser?.id,
              let device = currentDevice,
              !messageContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        isSending = true

        Task {
            do {
                let location = LocationManager.shared.userLocation
                let success = await communicationManager.sendChannelMessage(
                    channelId: channel.id,
                    content: messageContent,
                    latitude: location?.latitude,
                    longitude: location?.longitude,
                    deviceType: device.deviceType.rawValue
                )

                await MainActor.run {
                    if success {
                        messageContent = ""
                        showSuccessToast = true

                        // 2秒后隐藏提示
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showSuccessToast = false
                        }
                    }

                    isSending = false
                }
            } catch {
                print("❌ [PTT] 发送消息失败: \(error)")
                await MainActor.run {
                    isSending = false
                }
            }
        }
    }

    private func sendVoiceMessage(audioURL: URL, duration: TimeInterval) {
        guard let channel = selectedChannel,
              authManager.currentUser?.id != nil,
              let device = currentDevice,
              duration > 0.5 else {  // 至少0.5秒
            print("⚠️ [PTT] 录音时长太短，已取消")
            return
        }

        isSending = true

        Task {
            let location = LocationManager.shared.userLocation
            let success = await communicationManager.sendAudioMessage(
                channelId: channel.id,
                audioURL: audioURL,
                duration: duration,
                latitude: location?.latitude,
                longitude: location?.longitude,
                deviceType: device.deviceType.rawValue
            )

            await MainActor.run {
                if success {
                    showSuccessToast = true

                    // 2秒后隐藏提示
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showSuccessToast = false
                    }

                    // 删除本地录音文件
                    audioRecorder.deleteRecording(at: audioURL)
                }

                isSending = false
            }
        }
    }
}

// MARK: - 频道标签按钮

struct ChannelTabButton: View {
    let channel: CommunicationChannel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: channel.channelType.iconName)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)

                Text(channel.channelCode)
                    .font(.caption)
                    .fontWeight(isSelected ? .bold : .regular)
                    .foregroundColor(isSelected ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)
            }
            .frame(width: 70)
            .padding(.vertical, 8)
            .background(
                isSelected
                    ? ApocalypseTheme.primary.opacity(0.15)
                    : ApocalypseTheme.cardBackground
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? ApocalypseTheme.primary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 预览

#Preview {
    NavigationStack {
        PTTCallView()
            .environmentObject(AuthManager.shared)
            .environmentObject(CommunicationManager.shared)
    }
}
