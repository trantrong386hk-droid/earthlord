//
//  AudioPlayerManager.swift
//  earthlord
//
//  音频播放器管理器
//

import Foundation
import AVFoundation
import SwiftUI
import Combine

@MainActor
class AudioPlayerManager: NSObject, ObservableObject {
    static let shared = AudioPlayerManager()

    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentPlayingURL: String?

    private var audioPlayer: AVPlayer?
    private var timeObserver: Any?

    private override init() {
        super.init()
    }

    // MARK: - 播放控制

    /// 播放音频
    func play(from urlString: String) {
        // 如果正在播放同一个音频，则暂停
        if currentPlayingURL == urlString && isPlaying {
            pause()
            return
        }

        // 如果是新音频，停止当前播放
        if currentPlayingURL != urlString {
            stop()
        }

        guard let url = URL(string: urlString) else {
            print("❌ [音频播放] 无效的 URL: \(urlString)")
            return
        }

        currentPlayingURL = urlString

        // 创建播放器
        let playerItem = AVPlayerItem(url: url)
        audioPlayer = AVPlayer(playerItem: playerItem)

        // 配置音频会话
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ [音频播放] 配置音频会话失败: \(error)")
        }

        // 监听播放进度
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = audioPlayer?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            Task { @MainActor in
                self.currentTime = time.seconds
                if let duration = self.audioPlayer?.currentItem?.duration.seconds,
                   !duration.isNaN, !duration.isInfinite {
                    self.duration = duration
                }
            }
        }

        // 监听播放结束
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )

        // 开始播放
        audioPlayer?.play()
        isPlaying = true

        print("▶️ [音频播放] 开始播放: \(urlString)")
    }

    /// 暂停播放
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        print("⏸️ [音频播放] 已暂停")
    }

    /// 停止播放
    func stop() {
        audioPlayer?.pause()
        audioPlayer = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        currentPlayingURL = nil

        if let observer = timeObserver {
            audioPlayer?.removeTimeObserver(observer)
            timeObserver = nil
        }

        NotificationCenter.default.removeObserver(self)

        print("⏹️ [音频播放] 已停止")
    }

    /// 跳转到指定时间
    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        audioPlayer?.seek(to: cmTime)
    }

    // MARK: - 播放结束处理

    @objc private func playerDidFinishPlaying() {
        Task { @MainActor in
            isPlaying = false
            currentTime = 0
            print("✅ [音频播放] 播放完成")
        }
    }
}
