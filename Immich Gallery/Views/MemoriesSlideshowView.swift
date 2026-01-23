//
//  MemoriesSlideshowView.swift
//  Immich Gallery
//
//  Created by Opencode Agent on 2026-01-23.
//

import SwiftUI
import UIKit
import AVKit
import OmniSlideTV

struct MemoriesSlideshowView: View {
    let albumId: String?
    let personId: String?
    let tagId: String?
    let city: String?
    let startingIndex: Int
    let isFavorite: Bool
    @Environment(\.dismiss) private var dismiss

    // Services created internally
    private let assetService: AssetService
    private let albumService: AlbumService?
    private let networkService: NetworkService

    // Asset provider created using factory - will be recreated with config if needed
    @State private var assetProvider: AssetProvider?
    @State private var slideshowConfig: SlideshowConfig?

    @ObservedObject private var thumbnailCache = ThumbnailCache.shared
    private let videoAdvanceInterval: TimeInterval = 8.0

    init(albumId: String? = nil, personId: String? = nil, tagId: String? = nil, city: String? = nil, startingIndex: Int = 0, isFavorite: Bool = false) {
        self.albumId = albumId
        self.personId = personId
        self.tagId = tagId
        self.city = city
        self.startingIndex = startingIndex
        self.isFavorite = isFavorite

        let userManager = UserManager()
        let networkService = NetworkService(userManager: userManager)
        self.networkService = networkService
        self.assetService = AssetService(networkService: networkService)
        self.albumService = AlbumService(networkService: networkService)

        let initialProvider = AssetProviderFactory.createProvider(
            albumId: albumId,
            personId: personId,
            tagId: tagId,
            city: city,
            isAllPhotos: false,
            isFavorite: isFavorite,
            assetService: assetService,
            albumService: albumService,
            config: nil
        )
        _assetProvider = State(initialValue: initialProvider)
    }

    enum SlideshowMedia {
        case image(asset: ImmichAsset, image: UIImage, dominantColor: Color?)
        case video(asset: ImmichAsset, player: AVPlayer, thumbnail: UIImage?, dominantColor: Color?)

        var asset: ImmichAsset {
            switch self {
            case .image(let asset, _, _):
                return asset
            case .video(let asset, _, _, _):
                return asset
            }
        }

        var dominantColor: Color? {
            switch self {
            case .image(_, _, let color):
                return color
            case .video(_, _, _, let color):
                return color
            }
        }

        var player: AVPlayer? {
            switch self {
            case .video(_, let player, _, _):
                return player
            default:
                return nil
            }
        }

        var thumbnail: UIImage? {
            switch self {
            case .video(_, _, let thumbnail, _):
                return thumbnail
            default:
                return nil
            }
        }

        var image: UIImage? {
            switch self {
            case .image(_, let image, _):
                return image
            default:
                return nil
            }
        }
    }

    @State private var mediaQueue: [SlideshowMedia] = []
    @State private var assetQueue: [ImmichAsset] = []
    @State private var currentMedia: SlideshowMedia?
    @State private var isLoading = true
    @State private var slideInterval: TimeInterval = UserDefaults.standard.slideshowInterval
    @State private var autoAdvanceTimer: Timer?
    @State private var isTransitioning = false
    @State private var dominantColor: Color = getBackgroundColor(UserDefaults.standard.slideshowBackgroundColor)
    @State private var slideshowTransition: TransitionType = .fade
    @State private var resolvedTransition: TransitionType = .fade
    @State private var transitionTrigger = 0
    @State private var isLoadingAssets = false

    @State private var hasMoreAssets = true
    @State private var currentPage = 1
    @State private var loadAssetsTask: Task<Void, Never>?
    @State private var slideshowBackgroundColor: String = UserDefaults.standard.slideshowBackgroundColor
    @State private var hideImageOverlay: Bool = UserDefaults.standard.hideImageOverlay
    @State private var enableReflectionsInSlideshow: Bool = UserDefaults.standard.enableReflectionsInSlideshow
    @State private var enableKenBurnsEffect: Bool = UserDefaults.standard.enableKenBurnsEffect
    @State private var dimensionMultiplier: Double = UserDefaults.standard.enableReflectionsInSlideshow ? 0.9 : 1.0
    @State private var kenBurnsScale: CGFloat = 1.0
    @State private var kenBurnsOffset: CGSize = .zero
    @State private var enableShuffle: Bool = UserDefaults.standard.enableSlideshowShuffle
    @State private var isSharedAlbum: Bool = false
    @FocusState private var isFocused: Bool

    private let slideshowTransitionMap: [String: TransitionType] = [
        "fade": .fade,
        "slide": .slide,
        "zoom": .zoom,
        "wipe": .wipe,
        "cube": .cube,
        "flip": .flip,
        "coverFlow": .coverFlow,
        "fadeThrough": .fadeThrough,
        "slideLeftRight": .slideLeftRight,
        "random": .random
    ]

    /// Computed property to get current Art Mode level from UserDefaults
    private var currentArtModeLevel: ArtModeLevel {
        let levelString = UserDefaults.standard.artModeLevel
        return ArtModeLevel(rawValue: levelString) ?? .off
    }

    private let slideAnimationDuration: Double = 1.5

    private var currentAsset: ImmichAsset? {
        currentMedia?.asset
    }

    var body: some View {
        ZStack {
            (slideshowBackgroundColor == "auto" ? dominantColor : getBackgroundColor(slideshowBackgroundColor))
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.6), value: dominantColor)

            if currentMedia == nil && !isLoading {
                VStack {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("No items to display")
                        .font(.title)
                        .foregroundColor(.white)
                }
            } else {
                if isLoading {
                    ProgressView("Loading...")
                        .foregroundColor(.white)
                        .scaleEffect(1.5)
                } else if let media = currentMedia {
                    GeometryReader { geometry in
                        let imageWidth = geometry.size.width * dimensionMultiplier
                        let imageHeight = geometry.size.height * dimensionMultiplier
                        let transition = TransitionManager.transition(
                            for: resolvedTransition,
                            fallback: slideshowTransition
                        )
                        let animation = TransitionManager.animation(
                            for: resolvedTransition,
                            overrideDuration: slideAnimationDuration
                        )

                        TransitionView(
                            transition: transition,
                            animation: animation,
                            trigger: transitionTrigger
                        ) {
                            VStack(spacing: 0) {
                                if case .image(_, let image, _) = media {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: imageWidth, height: imageHeight)
                                        .drawingGroup()
                                        .offset(kenBurnsOffset)
                                        .scaleEffect(kenBurnsScale)
                                        .animation(.linear(duration: slideInterval), value: kenBurnsScale)
                                        .animation(.linear(duration: slideInterval), value: kenBurnsOffset)
                                        .overlay(imageOverlay(imageWidth: imageWidth, imageHeight: imageHeight, image: image))
                                        .overlay(ArtModeOverlay(level: currentArtModeLevel))

                                    if enableReflectionsInSlideshow {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .scaleEffect(y: -1)
                                            .frame(width: imageWidth, height: imageHeight)
                                            .offset(y: -imageHeight * 0.0)
                                            .clipped()
                                            .mask(reflectionMask(geometry: geometry, imageHeight: imageHeight))
                                            .opacity(0.4)
                                            .drawingGroup()
                                            .offset(kenBurnsOffset)
                                            .scaleEffect(kenBurnsScale)
                                            .animation(.linear(duration: slideInterval), value: kenBurnsScale)
                                            .animation(.linear(duration: slideInterval), value: kenBurnsOffset)
                                    }
                                } else if case .video(let asset, let player, _, _) = media {
                                    VideoPlayer(player: player)
                                        .frame(width: imageWidth, height: imageHeight)
                                        .aspectRatio(contentMode: .fit)
                                        .overlay(videoOverlay(asset: asset, imageWidth: imageWidth, imageHeight: imageHeight))
                                        .overlay(ArtModeOverlay(level: currentArtModeLevel))
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack {
                        Image(systemName: "photo")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("Failed to load item")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .focusable(true)
        .focused($isFocused)
        .onAppear {
            isFocused = true
            UIApplication.shared.isIdleTimerDisabled = true
            applyTransitionSelection()
            initializeSlideshow()
        }
        .onDisappear {
            cleanup()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            slideInterval = UserDefaults.standard.slideshowInterval

            let newBackgroundColor = UserDefaults.standard.slideshowBackgroundColor
            let previousBackgroundColor = slideshowBackgroundColor
            slideshowBackgroundColor = newBackgroundColor

            hideImageOverlay = UserDefaults.standard.hideImageOverlay
            enableReflectionsInSlideshow = UserDefaults.standard.enableReflectionsInSlideshow
            enableKenBurnsEffect = UserDefaults.standard.enableKenBurnsEffect
            dimensionMultiplier = UserDefaults.standard.enableReflectionsInSlideshow ? 0.9 : 1.0

            if newBackgroundColor != previousBackgroundColor {
                if newBackgroundColor == "auto", let media = currentMedia {
                    if let cachedColor = media.dominantColor {
                        dominantColor = cachedColor
                    } else {
                        Task {
                            await updateDominantColor(from: media)
                        }
                    }
                } else if newBackgroundColor != "auto" {
                    dominantColor = getBackgroundColor(newBackgroundColor)
                }
            }

            enableShuffle = UserDefaults.standard.enableSlideshowShuffle
            applyTransitionSelection()
        }
        .onTapGesture {
            UIApplication.shared.isIdleTimerDisabled = false
            dismiss()
        }
    }

    private func initializeSlideshow() {
        loadAssetsTask = Task {
            await fetchConfigAndUpdateProvider()
            await checkIfAlbumIsShared()
            await loadInitialAssets()
            await loadInitialMedia()
            await showFirstMedia()
        }
    }

    private func fetchConfigAndUpdateProvider() async {
        guard let albumService = albumService else {
            await MainActor.run {
                self.assetProvider = AssetProviderFactory.createProvider(
                    albumId: albumId,
                    personId: personId,
                    tagId: tagId,
                    city: city,
                    isAllPhotos: false,
                    isFavorite: isFavorite,
                    assetService: assetService,
                    albumService: albumService
                )
            }
            return
        }

        let configService = SlideshowConfigService(albumService: albumService)
        let config = await configService.fetchSlideshowConfig()

        await MainActor.run {
            self.slideshowConfig = config

            if !config.albumIds.isEmpty || !config.personIds.isEmpty {
                self.assetProvider = AssetProviderFactory.createProvider(
                    albumId: nil,
                    personId: nil,
                    tagId: nil,
                    isAllPhotos: false,
                    isFavorite: isFavorite,
                    assetService: assetService,
                    albumService: albumService,
                    config: config
                )
            } else {
                self.assetProvider = AssetProviderFactory.createProvider(
                    albumId: albumId,
                    personId: personId,
                    tagId: tagId,
                    city: city,
                    isAllPhotos: false,
                    isFavorite: isFavorite,
                    assetService: assetService,
                    albumService: albumService
                )
            }
        }
    }

    private func checkIfAlbumIsShared() async {
        guard let albumId = albumId, let albumService = albumService else { return }

        do {
            let album = try await albumService.getAlbumInfo(albumId: albumId, withoutAssets: true)
            await MainActor.run {
                self.isSharedAlbum = album.shared
            }
        } catch {
            await MainActor.run {
                self.isSharedAlbum = false
            }
        }
    }

    private func cleanup() {
        loadAssetsTask?.cancel()
        loadAssetsTask = nil

        stopAutoAdvance()
        stopCurrentVideoPlayback()

        currentMedia = nil
        mediaQueue.removeAll()
        assetQueue.removeAll()

        UIApplication.shared.isIdleTimerDisabled = false
        NotificationCenter.default.post(name: NSNotification.Name("restartAutoSlideshowTimer"), object: nil)
    }

    private func loadInitialAssets() async {
        guard !Task.isCancelled, let assetProvider = assetProvider else { return }

        do {
            let searchResult: SearchResult
            if enableShuffle && !isSharedAlbum {
                searchResult = try await assetProvider.fetchRandomAssets(limit: 100)
            } else {
                searchResult = try await assetProvider.fetchAssets(
                    page: currentPage,
                    limit: 100
                )
            }

            await MainActor.run {
                let slideshowAssets = searchResult.assets.filter { $0.type == .image || $0.type == .video || $0.livePhotoVideoId != nil }
                let actualStartingIndex = min(startingIndex, max(0, slideshowAssets.count - 1))
                self.assetQueue = Array(slideshowAssets.dropFirst(actualStartingIndex))
                self.hasMoreAssets = searchResult.nextPage != nil || (enableShuffle && !isSharedAlbum)
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }

    private func loadInitialMedia() async {
        guard !assetQueue.isEmpty else {
            await MainActor.run {
                self.isLoading = false
            }
            return
        }

        let itemsToLoad = min(3, assetQueue.count)
        for i in 0..<itemsToLoad {
            guard i < assetQueue.count else { break }
            await loadMediaIntoQueue(asset: assetQueue[i])
        }

        await MainActor.run {
            self.assetQueue.removeFirst(min(itemsToLoad, self.assetQueue.count))
        }
    }

    private func loadMediaIntoQueue(asset: ImmichAsset) async {
        guard !Task.isCancelled else { return }

        if asset.type == .video || asset.livePhotoVideoId != nil {
            await loadVideoIntoQueue(asset: asset)
        } else {
            await loadImageIntoQueue(asset: asset)
        }
    }

    private func loadImageIntoQueue(asset: ImmichAsset) async {
        do {
            guard let image = try await assetService.loadFullImage(asset: asset) else {
                return
            }

            let dominantColor = slideshowBackgroundColor == "auto"
                ? await ImageColorExtractor.extractDominantColorAsync(from: image)
                : nil

            await MainActor.run {
                self.mediaQueue.append(.image(asset: asset, image: image, dominantColor: dominantColor))
            }
        } catch {
            print("MemoriesSlideshowView: Failed to load image for asset \(asset.id): \(error)")
        }
    }

    private func loadVideoIntoQueue(asset: ImmichAsset) async {
        do {
            let player = try await makeVideoPlayer(for: asset)
            let thumbnail = try await loadVideoThumbnail(for: asset)
            let dominantColor: Color?
            if slideshowBackgroundColor == "auto", let thumbnail {
                dominantColor = await ImageColorExtractor.extractDominantColorAsync(from: thumbnail)
            } else {
                dominantColor = nil
            }

            await MainActor.run {
                self.mediaQueue.append(.video(asset: asset, player: player, thumbnail: thumbnail, dominantColor: dominantColor))
            }
        } catch {
            print("MemoriesSlideshowView: Failed to load video for asset \(asset.id): \(error)")
        }
    }

    private func loadVideoThumbnail(for asset: ImmichAsset) async throws -> UIImage? {
        try await thumbnailCache.getThumbnail(for: asset.id, size: "preview") {
            try await assetService.loadImage(assetId: asset.id, size: "preview")
        }
    }

    private func loadVideoURL(for asset: ImmichAsset) async throws -> URL {
        if asset.type == .video {
            return try await assetService.loadVideoURL(asset: asset)
        }

        guard let livePhotoVideoId = asset.livePhotoVideoId else {
            throw ImmichError.clientError(400)
        }

        let endpoint = "/api/assets/\(livePhotoVideoId)/video/playback"
        guard let url = URL(string: "\(networkService.baseURL)\(endpoint)") else {
            throw ImmichError.invalidURL
        }
        return url
    }

    private func makeVideoPlayer(for asset: ImmichAsset) async throws -> AVPlayer {
        let videoURL = try await loadVideoURL(for: asset)
        let headers = videoAuthHeaders()
        let urlAsset: AVURLAsset

        if headers.isEmpty {
            urlAsset = AVURLAsset(url: videoURL)
        } else {
            urlAsset = AVURLAsset(url: videoURL, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        }

        let playerItem = AVPlayerItem(asset: urlAsset)
        let player = AVPlayer(playerItem: playerItem)
        player.actionAtItemEnd = .pause
        return player
    }

    private func showFirstMedia() async {
        await MainActor.run {
            guard !self.mediaQueue.isEmpty else {
                self.isLoading = false
                return
            }

            self.currentMedia = self.mediaQueue.removeFirst()
            self.isLoading = false

            if let dominantColor = self.currentMedia?.dominantColor,
               self.slideshowBackgroundColor == "auto" {
                self.dominantColor = dominantColor
            }

            if case .image = self.currentMedia {
                self.startKenBurnsEffect()
            } else {
                self.kenBurnsScale = 1.0
                self.kenBurnsOffset = .zero
            }

            self.resolveNextTransition()
            self.transitionTrigger += 1
            self.startMediaPlaybackIfNeeded()
            self.startAutoAdvance(for: self.currentMedia)

            Task {
                await self.maintainMediaQueue()
            }
        }
    }

    private func maintainMediaQueue() async {
        await MainActor.run {
            if self.mediaQueue.count < 2 {
                Task {
                    await self.loadMoreMediaIfNeeded()
                }
            }
        }
    }

    private func loadMoreMediaIfNeeded() async {
        let shouldLoadAssets = await MainActor.run {
            return self.assetQueue.count <= 2 && self.hasMoreAssets && !self.isLoadingAssets
        }

        if shouldLoadAssets {
            await loadMoreAssets()
        }

        let assetsToLoad = await MainActor.run {
            return Array(self.assetQueue.prefix(min(2, self.assetQueue.count)))
        }

        for asset in assetsToLoad {
            await loadMediaIntoQueue(asset: asset)
        }

        await MainActor.run {
            self.assetQueue.removeFirst(min(assetsToLoad.count, self.assetQueue.count))
        }
    }


    private func startAutoAdvance(for media: SlideshowMedia?) {
        stopAutoAdvance()
        let duration = durationForMedia(media)
        autoAdvanceTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in
            self.nextMedia()
        }
    }

    private func nextMedia() {
        guard !mediaQueue.isEmpty else {
            return
        }

        stopCurrentVideoPlayback()

        withAnimation(.easeInOut(duration: slideAnimationDuration)) {
            isTransitioning = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + slideAnimationDuration) {
            self.currentMedia = nil

            guard !self.mediaQueue.isEmpty else {
                return
            }

            self.currentMedia = self.mediaQueue.removeFirst()

            if let dominantColor = self.currentMedia?.dominantColor,
               self.slideshowBackgroundColor == "auto" {
                self.dominantColor = dominantColor
            }

            self.resolveNextTransition()
            self.transitionTrigger += 1

            withAnimation(.easeInOut(duration: self.slideAnimationDuration)) {
                self.isTransitioning = false
            }

            if case .image = self.currentMedia {
                self.startKenBurnsEffect()
            } else {
                self.kenBurnsScale = 1.0
                self.kenBurnsOffset = .zero
            }

            self.startMediaPlaybackIfNeeded()
            self.startAutoAdvance(for: self.currentMedia)

            Task {
                await self.maintainMediaQueue()
            }
        }
    }

    private func durationForMedia(_ media: SlideshowMedia?) -> TimeInterval {
        guard let media = media else { return slideInterval }
        switch media {
        case .video:
            return videoAdvanceInterval
        case .image:
            return slideInterval
        }
    }

    private func startMediaPlaybackIfNeeded() {
        guard let media = currentMedia else { return }
        switch media {
        case .video(_, let player, _, _):
            player.seek(to: .zero)
            player.isMuted = true
            player.play()
        case .image:
            break
        }
    }

    private func stopCurrentVideoPlayback() {
        guard let player = currentMedia?.player else { return }
        player.pause()
        player.replaceCurrentItem(with: nil)
    }

    private func stopAutoAdvance() {
        autoAdvanceTimer?.invalidate()
        autoAdvanceTimer = nil
    }

    private func resolveNextTransition() {
        if slideshowTransition == .random {
            resolvedTransition = TransitionManager.randomNonRandomTransition()
        } else {
            resolvedTransition = slideshowTransition
        }
    }

    private func applyTransitionSelection() {
        let storedTransition = UserDefaults.standard.slideshowTransition
        slideshowTransition = slideshowTransitionMap[storedTransition] ?? .fade
        resolveNextTransition()
    }

    private func startKenBurnsEffect() {
        guard enableKenBurnsEffect else {
            kenBurnsScale = 1.0
            kenBurnsOffset = .zero
            return
        }

        let zoomDirections = [true, false]
        let shouldZoomIn = zoomDirections.randomElement() ?? true

        let startScale: CGFloat = shouldZoomIn ? 1.0 : 1.2
        let endScale: CGFloat = shouldZoomIn ? 1.2 : 1.0

        let maxOffset: CGFloat = 20
        let startOffset = CGSize(
            width: CGFloat.random(in: -maxOffset...maxOffset),
            height: CGFloat.random(in: -maxOffset...maxOffset)
        )
        let endOffset = CGSize(
            width: CGFloat.random(in: -maxOffset...maxOffset),
            height: CGFloat.random(in: -maxOffset...maxOffset)
        )

        kenBurnsScale = startScale
        kenBurnsOffset = startOffset

        withAnimation(.linear(duration: slideInterval)) {
            kenBurnsScale = endScale
            kenBurnsOffset = endOffset
        }
    }

    private func loadMoreAssets() async {
        let shouldLoad = await MainActor.run {
            guard !self.isLoadingAssets && self.hasMoreAssets else {
                return false
            }
            self.isLoadingAssets = true
            return true
        }

        guard shouldLoad, let assetProvider = assetProvider else { return }

        do {
            let searchResult: SearchResult
            if enableShuffle && !isSharedAlbum {
                searchResult = try await assetProvider.fetchRandomAssets(limit: 100)
            } else {
                await MainActor.run {
                    self.currentPage += 1
                }
                searchResult = try await assetProvider.fetchAssets(
                    page: currentPage,
                    limit: 100
                )
            }

            await MainActor.run {
                let slideshowAssets = searchResult.assets.filter { $0.type == .image || $0.type == .video || $0.livePhotoVideoId != nil }
                self.assetQueue.append(contentsOf: slideshowAssets)
                self.hasMoreAssets = searchResult.nextPage != nil || (enableShuffle && !isSharedAlbum)
                self.isLoadingAssets = false
            }
        } catch {
            await MainActor.run {
                self.isLoadingAssets = false
                self.hasMoreAssets = enableShuffle && !isSharedAlbum
            }
        }
    }

    private func calculateActualImageSize(imageSize: CGSize, containerSize: CGSize) -> CGSize {
        let imageAspectRatio = imageSize.width / imageSize.height
        let containerAspectRatio = containerSize.width / containerSize.height

        if imageAspectRatio > containerAspectRatio {
            let actualWidth = containerSize.width
            let actualHeight = actualWidth / imageAspectRatio
            return CGSize(width: actualWidth, height: actualHeight)
        } else {
            let actualHeight = containerSize.height
            let actualWidth = actualHeight * imageAspectRatio
            return CGSize(width: actualWidth, height: actualHeight)
        }
    }

    private func reflectionMask(geometry: GeometryProxy, imageHeight: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                colors: [.black.opacity(0.9), .clear],
                startPoint: .top,
                endPoint: .center
            )

                            if enableKenBurnsEffect {
                                Rectangle()
                                    .fill(.clear)
                                    .background(
                                        Rectangle()
                                            .fill(.black)
                                            .scaleEffect(kenBurnsScale)
                                            .offset(
                                                x: -kenBurnsOffset.width,
                                                y: -kenBurnsOffset.height - imageHeight
                                            )
                                            .blendMode(.destinationOut)
                                    )
                            }

        }
        .compositingGroup()
    }

    private func imageOverlay(imageWidth: CGFloat, imageHeight: CGFloat, image: UIImage) -> some View {
        Group {
            if !hideImageOverlay {
                GeometryReader { imageGeometry in
                    let actualImageSize = calculateActualImageSize(
                        imageSize: CGSize(width: image.size.width, height: image.size.height),
                        containerSize: CGSize(width: imageWidth, height: imageHeight)
                    )
                    let screenWidth = imageGeometry.size.width
                    let isSmallWidth = actualImageSize.width < (screenWidth / 2)

                    if isSmallWidth {
                        VStack {
                            HStack {
                                Spacer()
                                if let asset = currentAsset {
                                    LockScreenStyleOverlay(asset: asset, isSlideshowMode: true)
                                        .opacity(isTransitioning ? 0.0 : 1.0)
                                        .animation(.easeInOut(duration: slideAnimationDuration), value: isTransitioning)
                                }
                            }
                        }
                    } else {
                        let xOffset = (imageWidth - actualImageSize.width) / 2
                        let yOffset = (imageHeight - actualImageSize.height) / 2

                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                if let asset = currentAsset {
                                    LockScreenStyleOverlay(asset: asset, isSlideshowMode: true)
                                        .opacity(isTransitioning ? 0.0 : 1.0)
                                        .animation(.easeInOut(duration: slideAnimationDuration), value: isTransitioning)
                                        .padding(.trailing, 20)
                                        .padding(.bottom, 20)
                                }
                            }
                        }
                        .frame(width: actualImageSize.width, height: actualImageSize.height)
                        .offset(x: xOffset, y: yOffset)
                    }
                }
            }
        }
    }

    private func videoOverlay(asset: ImmichAsset, imageWidth: CGFloat, imageHeight: CGFloat) -> some View {
        Group {
            if !hideImageOverlay {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        LockScreenStyleOverlay(asset: asset, isSlideshowMode: true)
                            .opacity(isTransitioning ? 0.0 : 1.0)
                            .animation(.easeInOut(duration: slideAnimationDuration), value: isTransitioning)
                            .padding(.trailing, 20)
                            .padding(.bottom, 20)
                    }
                }
                .frame(width: imageWidth, height: imageHeight)
            }
        }
    }

    private func videoAuthHeaders() -> [String: String] {
        guard let accessToken = networkService.accessToken else { return [:] }
        if networkService.currentAuthType == .apiKey {
            return ["x-api-key": accessToken]
        }
        return ["Authorization": "Bearer \(accessToken)"]
    }

    private func updateDominantColor(from media: SlideshowMedia) async {
        switch media {
        case .image(_, let image, _):
            let color = await ImageColorExtractor.extractDominantColorAsync(from: image)
            await MainActor.run {
                self.dominantColor = color
            }
        case .video(_, _, let thumbnail, _):
            guard let thumbnail = thumbnail else { return }
            let color = await ImageColorExtractor.extractDominantColorAsync(from: thumbnail)
            await MainActor.run {
                self.dominantColor = color
            }
        }
    }
}

#Preview {
    MemoriesSlideshowView(albumId: nil, personId: nil, tagId: nil, city: nil, startingIndex: 0, isFavorite: false)
}
