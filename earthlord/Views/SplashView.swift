import SwiftUI
import AVFoundation

/// 自定义 UIView，使用 AVPlayerLayer 作为根 layer，自动跟随 bounds 变化
class PlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

/// AVPlayer 视频播放器的 UIViewRepresentable 封装
struct VideoPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.backgroundColor = .black
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {}
}

/// 启动页视图 - 播放开屏视频
struct SplashView: View {
    /// 认证管理器
    @ObservedObject var authManager = AuthManager.shared

    /// 是否完成加载
    @Binding var isFinished: Bool

    /// 视频播放器
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player = player {
                VideoPlayerView(player: player)
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            setupAndPlay()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    private func setupAndPlay() {
        guard let url = Bundle.main.url(forResource: "splash_video", withExtension: "mp4") else {
            // 视频文件未找到，fallback：延迟后直接完成
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isFinished = true
                }
            }
            return
        }

        let avPlayer = AVPlayer(url: url)
        self.player = avPlayer

        // 监听视频播放完毕
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: avPlayer.currentItem,
            queue: .main
        ) { _ in
            // 播完后等 0.5 秒再过渡
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isFinished = true
                }
            }
        }

        avPlayer.play()
    }
}

#Preview {
    SplashView(isFinished: .constant(false))
}
