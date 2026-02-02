import SwiftUI

struct OmniSlideshowView: View {
    @ObservedObject var viewModel: SlideshowViewModel
    let networkService: NetworkService
    
    @State private var showPauseOverlay = false
    @FocusState private var slideshowFocused: Bool
    @State private var playbackIcon: String?
    @State private var iconTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { proxy in
            let effectiveTransition = viewModel.transitionOverride ?? viewModel.transitionForChange
            
            ZStack {
                // Background Pre-rendering (Hidden)
                // This forces SwiftUI to start the lifecycle (loading images/videos) for the next/previous slides
                Group {
                    if let next = viewModel.slide(atOffset: 1) {
                        slideView(for: next, isActive: false)
                            .frame(width: 1, height: 1) // Tiny frame
                            .opacity(0.01) // Nearly invisible
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)

                // Main Content
                if let slide = viewModel.currentSlide {
                    let definition = TransitionManager.definition(
                        for: effectiveTransition,
                        overrideDuration: viewModel.animationDurationOverride,
                        fallback: viewModel.currentTransition
                    )
                    
                    if effectiveTransition == .overlaySplit,
                       let previousSlide = viewModel.previousSlideItem,
                       let rightSlide = viewModel.slide(atOffset: 1),
                       let revealSlide = viewModel.slide(atOffset: 2) {
                        
                        OverlaySplitTransitionView(
                            trigger: viewModel.transitionCounter,
                            duration: TransitionManager.totalDuration(for: definition),
                            idleDurationOverride: viewModel.autoplayInterval,
                            onReveal: {
                                viewModel.completeOverlaySplit(from: viewModel.transitionCounter)
                            }
                        ) {
                            slideView(for: slide, isActive: true)
                        } rightContent: {
                            slideView(for: rightSlide, isActive: false)
                        } backgroundContent: {
                            slideView(for: previousSlide, isActive: false)
                        } revealContent: {
                            slideView(for: revealSlide, isActive: false)
                        }
                        .id(viewModel.transitionCounter)
                    } else {
                        // Standard Transitions
                        if let previousSlide = viewModel.previousSlideItem {
                            TransitionPairView(
                                definition: definition,
                                trigger: viewModel.transitionCounter,
                                isOutgoingVideo: previousSlide.mediaType == .video,
                                isIncomingVideo: slide.mediaType == .video,
                                outgoingFilmBurnSeed: filmBurnSeed(for: previousSlide),
                                incomingFilmBurnSeed: filmBurnSeed(for: slide)
                            ) {
                                slideView(for: previousSlide, isActive: false)
                                    .frame(width: proxy.size.width, height: proxy.size.height)
                            } incoming: {
                                slideView(for: slide, isActive: true)
                                    .frame(width: proxy.size.width, height: proxy.size.height)
                            }
                            .id(viewModel.transitionCounter)
                        } else {
                            slideView(for: slide, isActive: true)
                                .frame(width: proxy.size.width, height: proxy.size.height)
                        }
                    }
                }
                
                // Pause Overlay
                if showPauseOverlay {
                    VStack {
                        Spacer()
                        PauseShelfView(viewModel: viewModel, networkService: networkService) {
                            // Settings action
                        }
                    }
                    .background(.ultraThinMaterial.opacity(0.5))
                    .transition(.opacity)
                }
                
                // Playback Icon
                if let playbackIcon {
                    Image(systemName: playbackIcon)
                        .font(.system(size: 100, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(radius: 10)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .focusable(true)
        .focused($slideshowFocused)
        .onAppear { 
            slideshowFocused = true
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .ignoresSafeArea()
        .onPlayPauseCommand { togglePause() }
        .onMoveCommand { direction in
            guard !showPauseOverlay else { return }
            if direction == .left { viewModel.previousSlide() }
            if direction == .right { viewModel.nextSlide() }
        }
    }

    private func filmBurnSeed(for slide: SlideItem) -> SIMD2<Float> {
        let counter = UInt64(viewModel.transitionCounter)
        let slideHash = slide.id.uuidString.hashValue
        let transitionHash = UInt64(bitPattern: Int64(slideHash)) ^ (counter &* 0x9E3779B97F4A7C15)
        return FilmBurnSeedGenerator.seed(from: transitionHash)
    }

    @ViewBuilder
    private func slideView(for slide: SlideItem, isActive: Bool) -> some View {
        switch slide.mediaType {
        case .image:
            SlideImageView(slide: slide, networkService: networkService)
        case .video:
            SlideVideoView(slide: slide, isActive: isActive, networkService: networkService) { slideID in
                viewModel.markPlaybackReady(for: slideID)
            }
        }
    }

    private func togglePause() {
        if viewModel.isPlaying {
            viewModel.pause()
            showPlaybackIcon("pause.fill")
            withAnimation { showPauseOverlay = true }
            slideshowFocused = false
        } else {
            viewModel.play()
            showPlaybackIcon("play.fill")
            withAnimation { showPauseOverlay = false }
            slideshowFocused = true
        }
    }

    private func showPlaybackIcon(_ name: String) {
        iconTask?.cancel()
        playbackIcon = name
        iconTask = Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run { withAnimation { playbackIcon = nil } }
        }
    }
}
