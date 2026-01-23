import AVKit
import SwiftUI

struct SlideVideoView: View {
    let slide: SlideItem

    @State private var foregroundPlayer: AVPlayer
    @State private var backgroundPlayer: AVPlayer
    @State private var computedOrientation: SlideItem.Orientation?

    init(slide: SlideItem) {
        self.slide = slide
        let foreground = AVPlayer(url: slide.mediaURL)
        let background = AVPlayer(url: slide.mediaURL)
        background.isMuted = true
        _foregroundPlayer = State(initialValue: foreground)
        _backgroundPlayer = State(initialValue: background)
    }

    var body: some View {
        ZStack {
            if let resolvedOrientation = computedOrientation {
                if resolvedOrientation == .portrait {
                    PortraitView {
                        VideoPlayer(player: foregroundPlayer)
                    }
                } else {
                    VideoPlayer(player: foregroundPlayer)
                }
            } else {
                ProgressView("Loading Video")
            }
        }
        .task(id: slide.mediaURL) {
            resolveOrientation()
        }
        .onAppear {
            if computedOrientation != nil {
                startPlayback()
            }
        }
        .onChange(of: computedOrientation?.rawValue) { _, newValue in
            guard newValue != nil else { return }
            startPlayback()
        }
        .onDisappear {
            foregroundPlayer.pause()
            backgroundPlayer.pause()
        }
    }

    private func startPlayback() {
        foregroundPlayer.play()
        if computedOrientation == .portrait {
            backgroundPlayer.play()
        }
    }

    private func resolveOrientation() {
        Task {
            let asset = AVURLAsset(url: slide.mediaURL)
            do {
                let track = try await asset.loadTracks(withMediaType: AVMediaType.video).first
                guard let track else { return }
                let naturalSize = try await track.load(.naturalSize)
                let transform = try await track.load(.preferredTransform)
                let transformed = naturalSize.applying(transform)
                let size = CGSize(width: abs(transformed.width), height: abs(transformed.height))
                guard size.height > 0 else { return }
                let ratio = size.width / size.height
                let orientation: SlideItem.Orientation = ratio >= 1.33 ? .landscape : .portrait
                let ratioText = String(format: "%.2f", ratio)
                await MainActor.run {
                    computedOrientation = orientation
                }
                print("Video media: \(slide.name) | size=\(Int(size.width))x\(Int(size.height)) | ratio=\(ratioText) | computed=\(orientation) | slide=\(slide.orientation) | url=\(slide.mediaURL)")
            } catch {
                print("Video media: \(slide.name) | failed to load track | url=\(slide.mediaURL)")
            }
        }
    }
}
