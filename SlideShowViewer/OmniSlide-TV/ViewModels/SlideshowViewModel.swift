import Combine
import Foundation

@MainActor
final class SlideshowViewModel: ObservableObject {
    @Published var currentSlideIndex: Int = 0
    @Published var slides: [SlideItem] = [] {
        didSet {
            buildTransitionPlaylist()
            updateCurrentTransition()
        }
    }
    @Published var isPlaying: Bool = true
    @Published var selectedTransition: TransitionType = .random
    @Published var autoplayInterval: TimeInterval = 5.0
    @Published private(set) var currentTransition: TransitionType = .fade
    @Published var transitionOverride: TransitionType?
    @Published var animationDurationOverride: Double?

    private var transitionPlaylist: [TransitionType] = []
    private var autoplayTask: Task<Void, Never>?
    private var focusDebounceTask: Task<Void, Never>?

    init(slides: [SlideItem]? = nil) {
        self.slides = slides ?? PicsumProvider.makeSlides()
        buildTransitionPlaylist()
        updateCurrentTransition()
        startAutoplay()
    }

    var currentSlide: SlideItem? {
        guard slides.indices.contains(currentSlideIndex) else { return nil }
        return slides[currentSlideIndex]
    }

    func play() {
        isPlaying = true
    }

    func pause() {
        isPlaying = false
    }

    func nextSlide() {
        guard !slides.isEmpty else { return }
        currentSlideIndex = (currentSlideIndex + 1) % slides.count
        updateCurrentTransition()
        cancelFocusDebounce()
    }

    func previousSlide() {
        guard !slides.isEmpty else { return }
        currentSlideIndex = (currentSlideIndex - 1 + slides.count) % slides.count
        updateCurrentTransition()
        cancelFocusDebounce()
    }

    func updateAutoplayInterval(_ interval: TimeInterval) {
        autoplayInterval = interval
        startAutoplay()
    }

    func jumpToSlide(index: Int, useCrossfade: Bool) {
        guard slides.indices.contains(index) else { return }
        if useCrossfade {
            transitionOverride = .fade
            animationDurationOverride = 0.6
        }
        currentSlideIndex = index
        updateCurrentTransition()
        if useCrossfade {
            scheduleTransitionOverrideReset()
        }
    }

    func handleShelfFocusChange(index: Int) {
        focusDebounceTask?.cancel()
        guard index != currentSlideIndex else { return }
        focusDebounceTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 2_000_000_000)
            } catch {
                return
            }
            await MainActor.run {
                guard let self, self.currentSlideIndex != index else { return }
                self.jumpToSlide(index: index, useCrossfade: true)
            }
        }
    }

    func cancelFocusDebounce() {
        focusDebounceTask?.cancel()
        focusDebounceTask = nil
    }

    private func startAutoplay() {
        autoplayTask?.cancel()
        autoplayTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: UInt64(self.autoplayInterval * 1_000_000_000))
                } catch {
                    return
                }
                if self.isPlaying {
                    self.nextSlide()
                }
            }
        }
    }

    private func updateCurrentTransition() {
        if selectedTransition == .random {
            if transitionPlaylist.indices.contains(currentSlideIndex) {
                currentTransition = transitionPlaylist[currentSlideIndex]
            } else {
                currentTransition = TransitionManager.randomNonRandomTransition()
            }
        } else {
            currentTransition = selectedTransition
        }
    }

    private func scheduleTransitionOverrideReset() {
        Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 800_000_000)
            } catch {
                return
            }
            await MainActor.run {
                self?.transitionOverride = nil
                self?.animationDurationOverride = nil
            }
        }
    }

    private func buildTransitionPlaylist() {
        guard !slides.isEmpty else {
            transitionPlaylist = []
            return
        }

        transitionPlaylist = slides.map { _ in
            TransitionManager.randomNonRandomTransition()
        }
    }

    deinit {
        autoplayTask?.cancel()
    }
}
