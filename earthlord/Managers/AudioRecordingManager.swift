//
//  AudioRecordingManager.swift
//  earthlord
//
//  音频录制管理器 - 处理录音、权限、文件管理
//

import Foundation
import AVFoundation
import SwiftUI
import Combine

@MainActor
class AudioRecordingManager: NSObject, ObservableObject {
    static let shared = AudioRecordingManager()

    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var hasPermission = false

    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var currentRecordingURL: URL?

    // 最大录音时长（秒）
    private let maxRecordingDuration: TimeInterval = 60

    private override init() {
        super.init()
    }

    // MARK: - 权限管理

    /// 请求麦克风权限
    func requestPermission() async -> Bool {
        if #available(iOS 17.0, *) {
            // iOS 17+ 使用 AVAudioApplication
            let status = AVAudioApplication.shared.recordPermission

            switch status {
            case .granted:
                hasPermission = true
                return true

            case .denied:
                hasPermission = false
                return false

            case .undetermined:
                let granted = await AVAudioApplication.requestRecordPermission()
                hasPermission = granted
                return granted

            @unknown default:
                hasPermission = false
                return false
            }
        } else {
            // iOS 17 以下使用 AVAudioSession
            let status = AVAudioSession.sharedInstance().recordPermission

            switch status {
            case .granted:
                hasPermission = true
                return true

            case .denied:
                hasPermission = false
                return false

            case .undetermined:
                let granted = await withCheckedContinuation { continuation in
                    AVAudioSession.sharedInstance().requestRecordPermission { granted in
                        continuation.resume(returning: granted)
                    }
                }
                hasPermission = granted
                return granted

            @unknown default:
                hasPermission = false
                return false
            }
        }
    }

    // MARK: - 录音控制

    /// 开始录音
    func startRecording() throws -> URL {
        // 配置音频会话
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default)
        try audioSession.setActive(true)

        // 创建录音文件URL
        let fileName = "audio_\(UUID().uuidString).m4a"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documentsPath.appendingPathComponent(fileName)
        currentRecordingURL = audioURL

        // 配置录音设置
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        // 创建录音器
        audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
        audioRecorder?.delegate = self
        audioRecorder?.prepareToRecord()
        audioRecorder?.record()

        isRecording = true
        recordingDuration = 0

        // 启动计时器
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.recordingDuration = self.audioRecorder?.currentTime ?? 0

                // 检查是否超过最大时长
                if self.recordingDuration >= self.maxRecordingDuration {
                    _ = self.stopRecording()
                }
            }
        }

        print("✅ [录音] 开始录音: \(audioURL.lastPathComponent)")
        return audioURL
    }

    /// 停止录音
    func stopRecording() -> URL? {
        guard isRecording, let recorder = audioRecorder else {
            return nil
        }

        recorder.stop()
        recordingTimer?.invalidate()
        recordingTimer = nil
        isRecording = false

        // 停用音频会话
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("❌ [录音] 停用音频会话失败: \(error)")
        }

        let duration = recordingDuration
        print("✅ [录音] 录音完成，时长: \(String(format: "%.1f", duration))秒")

        return currentRecordingURL
    }

    /// 取消录音（删除文件）
    func cancelRecording() {
        guard let url = currentRecordingURL else { return }

        _ = stopRecording()

        // 删除文件
        try? FileManager.default.removeItem(at: url)
        currentRecordingURL = nil
        recordingDuration = 0

        print("✅ [录音] 已取消录音")
    }

    // MARK: - 文件管理

    /// 获取音频文件数据
    func getAudioData(from url: URL) -> Data? {
        return try? Data(contentsOf: url)
    }

    /// 删除录音文件
    func deleteRecording(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    /// 格式化时长显示
    static func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioRecordingManager: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("❌ [录音] 录音失败")
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            print("❌ [录音] 编码错误: \(error)")
        }
    }
}
