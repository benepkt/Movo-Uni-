import SwiftUI
import AVKit

struct ExerciseDemoView: View {
    let name: String
    var aspect: CGFloat = 1 // 1:1 für deine Clips
    @State private var image: UIImage?
    @State private var videoURL: URL?

    var body: some View {
        ZStack {
            if let url = videoURL {
                VideoPlayerView(url: url)
                    .overlay(LinearGradient(
                        colors: [.clear, Color.black.opacity(0.35)],
                        startPoint: .center, endPoint: .bottom
                    ).allowsHitTesting(false))
            } else if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.gray.opacity(0.12))
                    .overlay(Image(systemName: "figure.strengthtraining.traditional").font(.system(size: 44)).foregroundColor(.secondary))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06))
        )
        .shadow(color: .black.opacity(0.25), radius: 14, y: 8)
        .aspectRatio(aspect, contentMode: .fit)
        .onAppear {
            image    = ExerciseMediaService.shared.thumbnail(for: name)
            videoURL = ExerciseMediaService.shared.localVideoURL(for: name)
        }
    }
}

private struct VideoPlayerView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.showsPlaybackControls = false
        vc.videoGravity = .resizeAspectFill
        let player = AVPlayer(url: url)
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main
        ) { _ in
            player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
            player.play()
        }
        player.isMuted = true
        player.play()
        vc.player = player
        return vc
    }
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}
