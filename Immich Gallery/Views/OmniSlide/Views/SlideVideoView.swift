import AVFoundation
import SwiftUI

struct SlideVideoView: View {
    let slide: SlideItem
    let isActive: Bool
    let onPlaybackReady: ((UUID) -> Void)?
    private let networkService: NetworkService

    @State private var player: AVPlayer?
    @State private var computedOrientation: SlideItem.Orientation?
    @State private var playbackObserverTask: Task<Void, Never>?

    init(slide: SlideItem, isActive: Bool, networkService: NetworkService, onPlaybackReady: ((UUID) -> Void)? = nil) {
        self.slide = slide
        self.isActive = isActive
        self.networkService = networkService
        self.onPlaybackReady = onPlaybackReady
        
        // Removed heavy lifting from init
        _computedOrientation = State(initialValue: slide.orientation)
    }

    var body: some View {
        ZStack {
            if let player = player {
                if computedOrientation == .portrait {
                    PortraitView {
                        AVPlayerLayerView(player: player)
                    }
                } else {
                    AVPlayerLayerView(player: player)
                }
            } else {
                LoadingView(label: "Buffering Video")
            }
        }
        .task(id: slide.mediaURL) {
            resolveOrientation()
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            playbackObserverTask?.cancel()
            player?.pause()
            player = nil // Final cleanup when view is truly gone
        }
        .onPlayPauseCommand(perform: {
            //pause video
            if player?.timeControlStatus == .playing {
                player?.pause()
            } else {
                player?.play()
            }
        })
        .onChange(of: isActive) { active in
            if active {
                if player == nil {
                    setupPlayer()
                }
                player?.isMuted = false
                player?.play()
                startPlaybackObserver()
            } else {
                player?.pause()
                player?.isMuted = true
                // Do NOT set player = nil here to preserve buffering
                playbackObserverTask?.cancel()
            }
        }
    }
    
    private func setupPlayer() {
        guard player == nil else { return }
        
        // Initialize player by checking VideoPrefetcher for indexed player items
        let authHeaders = Self.getAuthHeaders(networkService: networkService)
        let item = VideoPrefetcher.shared.playerItem(for: slide.mediaURL, headers: authHeaders)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.automaticallyWaitsToMinimizeStalling = true
        player = newPlayer
        
        if isActive {
            newPlayer.isMuted = false
            newPlayer.play()
            startPlaybackObserver()
        } else {
            newPlayer.isMuted = true
            newPlayer.pause()
        }
    }

    private static func getAuthHeaders(networkService: NetworkService) -> [String: String] {
        guard let token = networkService.accessToken else { return [:] }
        if networkService.currentAuthType == .apiKey {
            return ["x-api-key": token]
        } else {
            return ["Authorization": "Bearer \(token)"]
        }
    }

    private func getAuthHeaders() -> [String: String] {
        Self.getAuthHeaders(networkService: networkService)
    }

    private func startPlaybackObserver() {
        playbackObserverTask?.cancel()
        playbackObserverTask = Task { @MainActor in
            while !Task.isCancelled {
                guard let player = player else { 
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    continue 
                }
                let currentItem = player.currentItem
                let isReady = currentItem?.status == .readyToPlay
                let isPlaying = player.timeControlStatus == .playing
                if isReady && isPlaying {
                    onPlaybackReady?(slide.id)
                    break
                }
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }
    }

    private func resolveOrientation() {
        Task {
            let asset = AVURLAsset(url: slide.mediaURL, options: ["AVURLAssetHTTPHeaderFieldsKey": getAuthHeaders()])
            do {
                if let track = try await asset.loadTracks(withMediaType: .video).first {
                     let naturalSize = try await track.load(.naturalSize)
                     let transform = try await track.load(.preferredTransform)
                     let transformed = naturalSize.applying(transform)
                     let size = CGSize(width: abs(transformed.width), height: abs(transformed.height))
                     if size.height > 0 {
                         let ratio = size.width / size.height
                         let orientation: SlideItem.Orientation = ratio >= 1.33 ? .landscape : .portrait
                         await MainActor.run {
                             computedOrientation = orientation
                         }
                     }
                }
            } catch {
                return
            }
        }
    }
}
