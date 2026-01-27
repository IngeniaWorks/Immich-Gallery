import SwiftUI

struct MemoriesPauseShelfView: View {
    let slides: [MemoriesSlideItem]
    let currentIndex: Int
    let onJumpToSlide: (Int) -> Void
    let onSettings: () -> Void
    let assetService: AssetService
    let thumbnailCache: ThumbnailCache
    let isFocusRequested: Bool

    @Namespace private var focusNamespace
    @FocusState private var focusedTarget: FocusTarget?

    private enum Layout {
        static let thumbnailSize: CGFloat = 168
        static let thumbnailPadding: CGFloat = 15
        static let thumbnailCornerRadius: CGFloat = 22
        static let focusedScale: CGFloat = 1.16
        static let focusedShadowRadius: CGFloat = 18
        static let unfocusedShadowRadius: CGFloat = 8
        static let shadowYOffset: CGFloat = 6
        static let unfocusedOpacity: CGFloat = 0.85
        static let focusAnimationDuration: CGFloat = 0.2
        static let itemSpacing: CGFloat = 24
        static let scrollHorizontalPadding: CGFloat = 30
        static let scrollVerticalPadding: CGFloat = 12
        static let shelfHorizontalPadding: CGFloat = 32
        static let shelfTopPadding: CGFloat = 8
        static let shelfBottomPadding: CGFloat = 50
        static let headerSpacing: CGFloat = 16
        static let buttonSize: CGFloat = 56
        static let buttonBorderWidth: CGFloat = 2
        static let fadeDuration: CGFloat = 0.6

        static var focusedThumbnailHeight: CGFloat {
            let baseSize = thumbnailSize + thumbnailPadding * 2
            return baseSize * focusedScale + focusedShadowRadius + shadowYOffset
        }

        static var scrollHeight: CGFloat {
            focusedThumbnailHeight + scrollVerticalPadding * 2
        }

        static var preferredHeight: CGFloat {
            shelfTopPadding + buttonSize + headerSpacing + scrollHeight + shelfBottomPadding
        }
    }

    static var fadeAnimation: Animation {
        Animation.easeInOut(duration: Layout.fadeDuration)
    }

    private enum FocusTarget: Hashable {
        case settings
        case slide(UUID)
    }

    private var slideItems: [SlideItemRow] {
        slides.enumerated().map { index, slide in
            SlideItemRow(index: index, slide: slide)
        }
    }

    private var currentSlideID: UUID? {
        guard slides.indices.contains(currentIndex) else { return nil }
        return slides[currentIndex].id
    }

    private var slideFocusID: UUID? {
        guard case let .slide(slideID) = focusedTarget else { return nil }
        return slideID
    }

    static var preferredHeight: CGFloat {
        Layout.preferredHeight
    }

    var body: some View {
        VStack(spacing: Layout.headerSpacing) {
            HStack {
                Spacer()
                settingsButton
            }

            ScrollView(.horizontal) {
                LazyHStack(spacing: Layout.itemSpacing) {
                    ForEach(slideItems, id: \.id) { item in
                        slideRow(item)
                    }
                }
                .padding(.horizontal, Layout.scrollHorizontalPadding)
            }
            .padding(.vertical, Layout.scrollVerticalPadding)
            .frame(height: Layout.scrollHeight)
            .focusSection()
        }
        .padding(.horizontal, Layout.shelfHorizontalPadding)
        .padding(.top, Layout.shelfTopPadding)
        .padding(.bottom, Layout.shelfBottomPadding)
        .onAppear {
            let current = currentSlideID
            focusedTarget = current.map { .slide($0) } ?? .settings
        }
        .onChange(of: isFocusRequested) { _, newValue in
            guard newValue else { return }
            let current = currentSlideID
            focusedTarget = current.map { .slide($0) } ?? .settings
        }
        .focusScope(focusNamespace)
        .prefersDefaultFocus(true, in: focusNamespace)
        .onChange(of: focusedTarget) { _, newValue in
            guard case let .slide(slideID) = newValue else { return }
            if let index = slides.firstIndex(where: { $0.id == slideID }) {
                onJumpToSlide(index)
            }
        }
        .onChange(of: currentIndex) {
            guard slideFocusID != currentSlideID else { return }
            focusedTarget = currentSlideID.map { .slide($0) }
        }
        .onMoveCommand { direction in
            switch direction {
            case .up:
                focusedTarget = .settings
            case .down:
                if focusedTarget == .settings {
                    focusedTarget = currentSlideID.map { .slide($0) }
                }
            default:
                break
            }
        }
        .transition(.opacity.animation(Self.fadeAnimation))
    }
}


private extension MemoriesPauseShelfView {
    var settingsButton: some View {
        let isFocused = focusedTarget == .settings
        return Button(action: onSettings) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: Layout.buttonSize, height: Layout.buttonSize)
        }
        .buttonStyle(.plain)
        .background {
            Circle()
                .fill(Color.white.opacity(0.16))
        }
        .overlay {
            Circle()
                .strokeBorder(Color.white.opacity(isFocused ? 0.85 : 0.35), lineWidth: Layout.buttonBorderWidth)
        }
        .scaleEffect(isFocused ? 1.08 : 1.0)
        .animation(Animation.easeInOut(duration: Layout.focusAnimationDuration), value: isFocused)
        .focusable(true)
        .focused($focusedTarget, equals: .settings)
        .prefersDefaultFocus(true, in: focusNamespace)
    }

    func slideRow(_ item: SlideItemRow) -> some View {
        let isFocused = slideFocusID == item.slide.id
        let isCurrent = currentIndex == item.index
        return slideThumbnail(for: item.slide, isFocused: isFocused, isCurrent: isCurrent)
            .focusable(true)
            .focused($focusedTarget, equals: FocusTarget.slide(item.slide.id))
    }
}

private struct SlideItemRow: Identifiable {
    let id: UUID
    let index: Int
    let slide: MemoriesSlideItem

    init(index: Int, slide: MemoriesSlideItem) {
        id = slide.id
        self.index = index
        self.slide = slide
    }
}

private extension MemoriesPauseShelfView {
    @ViewBuilder
    func slideThumbnail(for slide: MemoriesSlideItem, isFocused: Bool, isCurrent: Bool) -> some View {
        MemoriesSlideThumbnailView(
            slide: slide,
            assetService: assetService,
            thumbnailCache: thumbnailCache
        )
        .frame(width: Layout.thumbnailSize, height: Layout.thumbnailSize)
        .clipShape(RoundedRectangle(cornerRadius: Layout.thumbnailCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Layout.thumbnailCornerRadius)
                .strokeBorder(Color.white.opacity(isCurrent ? 0.85 : 0.2), lineWidth: 2)
        }
        .shadow(
            color: Color.black.opacity(isFocused ? 0.80 : 0.25),
            radius: isFocused ? Layout.focusedShadowRadius : Layout.unfocusedShadowRadius,
            x: 0,
            y: Layout.shadowYOffset
        )
        .scaleEffect(isFocused ? Layout.focusedScale : 1.0)
        .opacity(isFocused ? 1.0 : Layout.unfocusedOpacity)
        .padding(Layout.thumbnailPadding)
        .animation(Animation.easeInOut(duration: Layout.focusAnimationDuration), value: isFocused)
    }
}

private struct MemoriesSlideThumbnailView: View {
    let slide: MemoriesSlideItem
    let assetService: AssetService
    let thumbnailCache: ThumbnailCache

    var body: some View {
        switch slide.mediaType {
        case .image:
            MemoriesSlideImageView(slide: slide, assetService: assetService, thumbnailCache: thumbnailCache)
        case .video:
            MemoriesVideoThumbnailPlaceholderView()
        }
    }
}

private struct MemoriesVideoThumbnailPlaceholderView: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.8))
            Image(systemName: "play.fill")
                .font(.system(size: 38, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}
