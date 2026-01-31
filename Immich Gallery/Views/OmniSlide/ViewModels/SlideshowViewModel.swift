import Combine
import Foundation
import SwiftUI

@MainActor
final class SlideshowViewModel: ObservableObject {
    @Published var currentSlideIndex: Int = 0
    @Published private(set) var previousSlideIndex: Int = 0
    @Published var slides: [SlideItem] = [] {
        didSet {
            buildTransitionPlaylist()
            updateCurrentTransition()
            updatePreviousSlideIndexForCurrent()
            updatePlaybackReadinessForCurrentSlide()
            prefetchUpcomingMedia()
        }
    }
    @Published var isPlaying: Bool = true
    @Published var selectedTransition: TransitionType = .random
    @Published var autoplayInterval: TimeInterval = 5.0
    @Published private(set) var currentTransition: TransitionType = .fade
    
    var onSlideshowFinished: (() -> Void)?
    @Published private(set) var transitionForChange: TransitionType = .fade
    @Published var transitionOverride: TransitionType?
    @Published var animationDurationOverride: Double?
    @Published private(set) var isPlaybackReady: Bool = true
    let usesCoreImageTransitions: Bool = false
    @Published private(set) var transitionCounter: Int = 0
    let prefetchCount: Int = 2
    let shelfThumbnailPrefetchRange: Int = 5

    private enum SlideAdvanceTrigger {
        case auto
        case manual
    }

    private var transitionPlaylist: [TransitionType] = []
    private var autoplayTask: Task<Void, Never>?
    private var focusDebounceTask: Task<Void, Never>?
    private var pendingOverlaySplitIndex: Int?
    private var playbackReadyTimeoutTask: Task<Void, Never>?
    private var pendingPlaybackSlideID: UUID?
    private var hasTriggeredFinish: Bool = false
    private var transitionCleanupTask: Task<Void, Never>?
    
    private let networkService: NetworkService

    init(assets: [ImmichAsset], networkService: NetworkService, startingIndex: Int = 0) {
        self.networkService = networkService
        self.slides = assets.map { Self.mapAssetToSlideItem($0, networkService: networkService) }
        self.currentSlideIndex = min(max(startingIndex, 0), max(0, self.slides.count - 1))
        
        buildTransitionPlaylist()
        updateCurrentTransition()
        updateTransitionForChange()
        updatePreviousSlideIndexForCurrent()
        updatePlaybackReadinessForCurrentSlide()
        prefetchUpcomingMedia()
        startAutoplay()
    }

    private static func mapAssetToSlideItem(_ asset: ImmichAsset, networkService: NetworkService) -> SlideItem {
        let isVideo = asset.type == .video
        
        // Construct URLs
        let baseURL = networkService.baseURL
        let mediaEndpoint = isVideo 
            ? "/api/assets/\(asset.id)/video/playback" 
            : "/api/assets/\(asset.id)/original"
        
        // For RAW images, use preview endpoint
        let isRaw = asset.originalMimeType?.lowercased().contains("raw") == true || 
                    ["nef", "dng", "cr2", "arw", "orf", "raf"].contains(asset.originalMimeType?.lowercased().components(separatedBy: "/").last ?? "")
        
        let finalMediaEndpoint = (!isVideo && isRaw) 
            ? "/api/assets/\(asset.id)/thumbnail?format=webp&size=preview"
            : mediaEndpoint
            
        let thumbnailEndpoint = "/api/assets/\(asset.id)/thumbnail?format=webp&size=thumbnail"
        
        return SlideItem(
            id: UUID(),
            assetId: asset.id,
            name: asset.originalFileName,
            mediaURL: URL(string: "\(baseURL)\(finalMediaEndpoint)") ?? URL(fileURLWithPath: ""),
            thumbnailURL: URL(string: "\(baseURL)\(thumbnailEndpoint)") ?? URL(fileURLWithPath: ""),
            caption: asset.exifInfo?.description ?? asset.originalFileName,
            mediaType: isVideo ? .video : .image,
            orientation: .landscape // Default, could be refined from exif
        )
    }

    var currentSlide: SlideItem? {
        guard slides.indices.contains(currentSlideIndex) else { return nil }
        return slides[currentSlideIndex]
    }

    var previousSlideItem: SlideItem? {
        guard slides.indices.contains(previousSlideIndex) else { return nil }
        return slides[previousSlideIndex]
    }

    func slide(atOffset offset: Int) -> SlideItem? {
        guard !slides.isEmpty else { return nil }
        let index = (currentSlideIndex + offset + slides.count) % slides.count
        return slides[index]
    }

    func play() {
        isPlaying = true
        startAutoplay()
    }

    func pause() {
        isPlaying = false
        autoplayTask?.cancel()
        autoplayTask = nil
    }

    func nextSlide() {
        advanceSlide(by: 1, trigger: .manual)
    }

    func previousSlide() {
        advanceSlide(by: -1, trigger: .manual)
    }

    func jumpToSlide(index: Int, useCrossfade: Bool) {
        guard slides.indices.contains(index) else { return }
        
        // Cancel any pending debounced jump if we're doing a direct jump
        focusDebounceTask?.cancel()
        focusDebounceTask = nil
        
        if useCrossfade {
            transitionOverride = .crossDissolve
            animationDurationOverride = 0.8 // Increased slightly for a more premium crossfade feel
        }
        
        transitionForChange = transitionForSlide(at: index)
        Task { @MainActor in
            await Task.yield()
            previousSlideIndex = currentSlideIndex
            currentSlideIndex = index
            transitionCounter += 1
            updateCurrentTransition()
            updatePlaybackReadinessForCurrentSlide()
            prefetchUpcomingMedia()
            restartAutoplayAfterManual()
            if useCrossfade {
                scheduleTransitionOverrideReset()
            }
        }
    }

    func jumpToSlideDebounced(index: Int) {
        guard slides.indices.contains(index) else { return }
        guard index != currentSlideIndex else { return }

        focusDebounceTask?.cancel()
        focusDebounceTask = Task { @MainActor in
            // 1 second delay to balance network traffic and avoid rapid reloads
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            guard !Task.isCancelled else { return }
            
            // Perform the jump with crossfade
            jumpToSlide(index: index, useCrossfade: true)
        }
    }

    func completeOverlaySplit(from triggerIndex: Int) {
        guard triggerIndex == transitionCounter else { return }
        // The OverlaySplit shows slides ahead, so we need to advance the index
        // to match what was revealed. Typically advances by 2.
        advanceSlide(by: 2, trigger: .auto)
    }

    func markPlaybackReady(for slideID: UUID) {
        guard currentSlide?.id == slideID else { return }
        playbackReadyTimeoutTask?.cancel()
        playbackReadyTimeoutTask = nil
        pendingPlaybackSlideID = nil
        isPlaybackReady = true
    }

    private func startAutoplay() {
        autoplayTask?.cancel()
        autoplayTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                let waitDuration: TimeInterval = self.autoplayInterval
                try? await Task.sleep(nanoseconds: UInt64(waitDuration * 1_000_000_000))
                
                if self.isPlaying, self.isPlaybackReady {
                    self.advanceSlide(by: 1, trigger: .auto)
                }
            }
        }
    }

    private func advanceSlide(by offset: Int, trigger: SlideAdvanceTrigger) {
        guard !slides.isEmpty else { return }
        
        // Calculate next index
        let count = slides.count
        let nextIndex = (currentSlideIndex + offset + count) % count
        
        // Check for loop completion (auto only)
        if trigger == .auto && offset > 0 && nextIndex == 0 {
            // We finished the loop
            guard !hasTriggeredFinish else { return }
            print("🎬 SlideshowViewModel: Slideshow finished loop")
            
            if let onSlideshowFinished = onSlideshowFinished {
                 hasTriggeredFinish = true
                 self.isPlaying = false // Stop immediately
                 self.autoplayTask?.cancel()
                 self.autoplayTask = nil
                 
                 Task { @MainActor in
                     onSlideshowFinished()
                 }
                 return
            }
        }
        
        transitionForChange = transitionForSlide(at: nextIndex)
        
        // Start transition cleanup
        transitionCleanupTask?.cancel()
        let duration = TransitionManager.totalDuration(for: TransitionManager.definition(for: transitionForChange, fallback: currentTransition))
        
        Task { @MainActor in
            await Task.yield()
            previousSlideIndex = currentSlideIndex
            currentSlideIndex = nextIndex
            transitionCounter += 1
            updateCurrentTransition()
            updatePlaybackReadinessForCurrentSlide()
            prefetchUpcomingMedia()
            
            // Schedule cleanup to stop using TransitionPairView and release resources (like old video players)
            transitionCleanupTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64((duration + 0.5) * 1_000_000_000))
                guard !Task.isCancelled else { return }
                print("🎬 SlideshowViewModel: Transition cleanup - clearing previousSlideIndex")
                previousSlideIndex = -1 // Use -1 to indicate no previous slide
            }
            
            if trigger == .manual {
                restartAutoplayAfterManual()
            }
        }
    }

    private func restartAutoplayAfterManual() {
        guard isPlaying else { return }
        startAutoplay()
    }

    private func updateCurrentTransition() {
        currentTransition = transitionForSlide(at: currentSlideIndex)
    }

    private func updateTransitionForChange() {
        transitionForChange = transitionForSlide(at: currentSlideIndex)
    }

    private func transitionForSlide(at index: Int) -> TransitionType {
        // Special case: The first image in the slideshow always appears with a fade transition
        if index == 0 {
            return .fade
        }
        
        if selectedTransition == .random {
            if transitionPlaylist.indices.contains(index) {
                return transitionPlaylist[index]
            }
            return TransitionManager.randomNonRandomTransition()
        }
        return selectedTransition
    }

    private func prefetchUpcomingMedia() {
        guard !slides.isEmpty else { return }
        
        // 1. Determine the "Keep Window"
        // extensive window: current - 1 ... current + prefetchCount
        var keepIndices = Set<Int>()
        keepIndices.insert(currentSlideIndex)
        
        // Previous slide (for immediate back navigation)
        let prevIndex = (currentSlideIndex - 1 + slides.count) % slides.count
        keepIndices.insert(prevIndex)
        
        // Upcoming slides
        for i in 1...prefetchCount {
             let nextIndex = (currentSlideIndex + i) % slides.count
             keepIndices.insert(nextIndex)
        }
        
        let keepSlides = keepIndices.map { slides[$0] }
        let keepURLs = Set(keepSlides.map { $0.mediaURL })
        
        // 2. Prune memory
        // Run on utility queue to avoid blocking main thread, though prune is fast
        Task.detached(priority: .background) {
            ImageCache.shared.prune(keeping: keepURLs)
            await VideoPrefetcher.shared.prune(keeping: keepURLs)
        }
        
        // 3. Prefetch upcoming
        // We only actively prefetch the *future* items, not the previous one (unless it was already loaded)
        guard prefetchCount > 0 else { return }
        let upcomingSlides = (1...prefetchCount).compactMap { offset -> SlideItem? in
            let index = (currentSlideIndex + offset) % slides.count
            return slides[index]
        }
        
        let upcomingImageURLs = upcomingSlides
            .filter { $0.mediaType == .image }
            .map { $0.mediaURL }
        ImageLoader.prefetch(urls: upcomingImageURLs, networkService: networkService)

        for slide in upcomingSlides where slide.mediaType == .video {
            let headers = getAuthHeaders()
            VideoPrefetcher.shared.prefetch(url: slide.mediaURL, headers: headers)
        }
    }
    
    private func getAuthHeaders() -> [String: String] {
        guard let token = networkService.accessToken else { return [:] }
        if networkService.currentAuthType == .apiKey {
            return ["x-api-key": token]
        } else {
            return ["Authorization": "Bearer \(token)"]
        }
    }

    private func scheduleTransitionOverrideReset() {
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
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

    private func updatePreviousSlideIndexForCurrent() {
        guard !slides.isEmpty else {
            previousSlideIndex = 0
            return
        }
        let safeIndex = min(max(currentSlideIndex, 0), slides.count - 1)
        previousSlideIndex = (safeIndex - 1 + slides.count) % slides.count
    }

    private func updatePlaybackReadinessForCurrentSlide() {
        playbackReadyTimeoutTask?.cancel()
        playbackReadyTimeoutTask = nil
        pendingPlaybackSlideID = nil
        guard let slide = currentSlide else {
            isPlaybackReady = true
            return
        }
        switch slide.mediaType {
        case .image:
            isPlaybackReady = true
        case .video:
            isPlaybackReady = false
            schedulePlaybackReadyTimeout(for: slide.id)
        }
    }

    private func schedulePlaybackReadyTimeout(for slideID: UUID) {
        pendingPlaybackSlideID = slideID
        playbackReadyTimeoutTask?.cancel()
        playbackReadyTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            await MainActor.run {
                guard let self, self.pendingPlaybackSlideID == slideID else { return }
                self.isPlaybackReady = true
                self.pendingPlaybackSlideID = nil
            }
        }
    }

    func cleanup() {
        print("🎬 SlideshowViewModel: Cleanup - releasing all resources")
        autoplayTask?.cancel()
        autoplayTask = nil
        focusDebounceTask?.cancel()
        focusDebounceTask = nil
        transitionCleanupTask?.cancel()
        transitionCleanupTask = nil
        playbackReadyTimeoutTask?.cancel()
        playbackReadyTimeoutTask = nil
        
        ImageCache.shared.removeAll()
        VideoPrefetcher.shared.removeAll()
        
        // Clear slides to ensure any held resources are dropped
        self.slides = []
    }

    deinit {
        // Can't easily use async tasks here, but we can call basic cleanup
        // Note: Task cancellation is handled by the tasks themselves if they check Task.isCancelled
        print("🎬 SlideshowViewModel: deinit")
    }
}
