import SwiftUI

struct SlideshowView: View {
    @ObservedObject var viewModel: SlideshowViewModel

    @State private var showPauseOverlay = false
    @State private var overlayHideTask: Task<Void, Never>?
    @FocusState private var slideshowFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let slide = viewModel.currentSlide {
                    let effectiveTransition = viewModel.transitionOverride ?? viewModel.currentTransition
                    let resolvedTransition = TransitionManager.transition(
                        for: effectiveTransition,
                        fallback: viewModel.currentTransition
                    )
                    let animation = TransitionManager.animation(
                        for: effectiveTransition,
                        overrideDuration: viewModel.animationDurationOverride
                    )

                    TransitionView(
                        transition: resolvedTransition,
                        animation: animation,
                        trigger: viewModel.currentSlideIndex
                    ) {
                        slideView(for: slide)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                    }
                } else {
                    ProgressView("Loading Slides")
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }

                if showPauseOverlay {
                    let shelfHeight = min(proxy.size.height * 0.4, PauseShelfView.preferredHeight)

                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        PauseShelfView(viewModel: viewModel) {
                            // Settings action wired in Phase 4.
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: shelfHeight)
                        .background(alignment: .bottom) {
                            pauseOverlayBackground(height: shelfHeight)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .focusable(true)
        .focused($slideshowFocused)
        .onAppear {
            slideshowFocused = true
        }
        .ignoresSafeArea()
        .sensoryFeedback(.success, trigger: viewModel.currentSlideIndex)
        .onPlayPauseCommand {
            togglePauseOverlay()
        }
        .onMoveCommand { direction in
            guard !showPauseOverlay else { return }
            switch direction {
            case .left:
                viewModel.previousSlide()
            case .right:
                viewModel.nextSlide()
            default:
                break
            }
        }
        .onChange(of: viewModel.currentSlideIndex) {
            guard let slide = viewModel.currentSlide else { return }
            let effectiveTransition = viewModel.transitionOverride ?? viewModel.currentTransition
            print("Slide: \(slide.name) | transition=\(effectiveTransition) | orientation=\(slide.orientation) | url=\(slide.mediaURL)")
        }
        .onDisappear {
            overlayHideTask?.cancel()
        }
    }

    @ViewBuilder
    private func slideView(for slide: SlideItem) -> some View {
        switch slide.mediaType {
        case .image:
            SlideImageView(slide: slide)
        case .video:
            SlideVideoView(slide: slide)
        }
    }

    private func togglePauseOverlay() {
        overlayHideTask?.cancel()
        if viewModel.isPlaying {
            viewModel.pause()
            withAnimation(.easeInOut(duration: 0.25)) {
                showPauseOverlay = true
            }
            slideshowFocused = false
        } else {
            viewModel.play()
            viewModel.cancelFocusDebounce()
            overlayHideTask = Task {
                do {
                    try await Task.sleep(nanoseconds: 3_000_000_000)
                } catch {
                    return
                }
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showPauseOverlay = false
                    }
                    slideshowFocused = true
                }
            }
        }
    }

    @ViewBuilder
    private func pauseOverlayBackground(height: CGFloat) -> some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay(
                LinearGradient(
                    colors: [Color.white.opacity(0.35), Color.white.opacity(0.05), Color.clear],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .mask(
                LinearGradient(
                    colors: [Color.white, Color.white.opacity(0.85), Color.clear],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(height: height)
            .frame(maxWidth: .infinity, alignment: .bottom)
    }
}
