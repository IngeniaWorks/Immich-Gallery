import SwiftUI

struct PauseShelfView: View {
    @ObservedObject var viewModel: SlideshowViewModel
    let networkService: NetworkService
    let onSettings: () -> Void

    @Namespace private var focusNamespace
    @FocusState private var focusedTarget: FocusTarget?
    @FocusState private var settingsFocus: SettingsFocus?
    @State private var showSettingsPanel = false

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

        static var focusedThumbnailHeight: CGFloat {
            let baseSize = thumbnailSize + thumbnailPadding * 2
            return baseSize * focusedScale + focusedShadowRadius + shadowYOffset
        }

        static var scrollHeight: CGFloat {
            focusedThumbnailHeight + scrollVerticalPadding * 2
        }

        static var horizontalPaddingForCentering: CGFloat {
            // Subtracting half the thumbnail size from half the screen width
            // This allows the first and last items to be centered in the scroll view
            // assuming the scroll view spans the screen narrow (minus shelf padding)
            (1920 - shelfHorizontalPadding * 2) / 2 - thumbnailSize / 2 - thumbnailPadding
        }

        static var preferredHeight: CGFloat {
            shelfTopPadding + buttonSize + headerSpacing + scrollHeight + shelfBottomPadding
        }
    }

    static var preferredHeight: CGFloat {
        Layout.preferredHeight
    }

    private enum FocusTarget: Hashable {
        case settings
        case slide(UUID)
    }

    private enum SettingsFocus: Hashable {
        case autoplay
        case transition
    }

    private var slideItems: [SlideItemRow] {
        viewModel.slides.enumerated().map { index, slide in
            SlideItemRow(id: slide.id, index: index, slide: slide)
        }
    }

    private var currentSlideID: UUID? {
        viewModel.currentSlide?.id
    }

    var body: some View {
        VStack(spacing: Layout.headerSpacing) {
            HStack {
                settingsButton
            }

            if showSettingsPanel {
                settingsPanel
                    .transition(.opacity)
            }

            shelfScroll
        }
        .padding(.horizontal, Layout.shelfHorizontalPadding)
        .padding(.top, Layout.shelfTopPadding)
        .padding(.bottom, Layout.shelfBottomPadding)
        .onChange(of: showSettingsPanel) { _, newValue in
            if newValue {
                settingsFocus = .autoplay
            } else {
                settingsFocus = nil
                focusedTarget = currentSlideID.map { .slide($0) }
            }
        }
        .focusScope(focusNamespace)
        .onChange(of: focusedTarget) { _, newValue in
            guard case let .slide(slideID) = newValue else { return }
            if let index = viewModel.slides.firstIndex(where: { $0.id == slideID }) {
                viewModel.jumpToSlideDebounced(index: index)
            }
        }
        .onChange(of: viewModel.currentSlideIndex) {
            if case let .slide(focusID) = focusedTarget, focusID != currentSlideID {
                focusedTarget = currentSlideID.map { .slide($0) }
            }
        }
        .onMoveCommand { direction in
            guard settingsFocus == nil else { return }
            switch direction {
            case .up: focusedTarget = .settings
            case .down:
                if focusedTarget == .settings {
                    focusedTarget = currentSlideID.map { .slide($0) }
                }
            default: break
            }
        }
        .onExitCommand {
            if showSettingsPanel {
                showSettingsPanel = false
            }
        }
    }

    private var shelfScroll: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: Layout.itemSpacing) {
                    ForEach(slideItems) { item in
                        slideThumbnail(for: item.slide, index: item.index)
                            .id(item.slide.id)
                            .focusable(true)
                            .focused($focusedTarget, equals: .slide(item.slide.id))
                    }
                }
                .padding(.horizontal, Layout.horizontalPaddingForCentering)
            }
            .frame(height: Layout.scrollHeight)
            .onChange(of: focusedTarget) { _, newValue in
                if case let .slide(slideID) = newValue {
                    withAnimation { proxy.scrollTo(slideID, anchor: .center) }
                }
            }
            .task {
                // Ensure we focus and scroll to the current slide when the shelf appears
                if let currentID = viewModel.currentSlide?.id {
                    focusedTarget = .slide(currentID)
                    // Small delay to ensure the ScrollView is laid out
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    withAnimation {
                        proxy.scrollTo(currentID, anchor: .center)
                    }
                } else {
                    focusedTarget = .settings
                }
            }
        }
    }

    private var settingsButton: some View {
        Button {
            showSettingsPanel.toggle()
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
        }
        .buttonStyle(.plain)
        .focused($focusedTarget, equals: .settings)
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Autoplay")
                    .font(.headline)
                    .frame(width: 140, alignment: .leading)
                Picker("Autoplay", selection: $viewModel.autoplayInterval) {
                    ForEach([5.0, 8.0, 10.0, 15.0], id: \.self) { value in
                        Text("\(Int(value))s").tag(value)
                    }
                }
                .pickerStyle(.segmented)
                .focused($settingsFocus, equals: .autoplay)
            }

            HStack {
                Text("Transition")
                    .font(.headline)
                    .frame(width: 140, alignment: .leading)
                Picker("Transition", selection: $viewModel.selectedTransition) {
                    ForEach(TransitionType.allCases, id: \.self) { type in
                        Text(type.rawValue.capitalized).tag(type)
                    }
                }
                .focused($settingsFocus, equals: .transition)
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 18).fill(.ultraThinMaterial))
    }

    @ViewBuilder
    private func slideThumbnail(for slide: SlideItem, index: Int) -> some View {
        let isFocused: Bool = {
            if case let .slide(id) = focusedTarget {
                return id == slide.id
            }
            return false
        }()
        let isCurrent = viewModel.currentSlideIndex == index
        
        VStack {
            SlideThumbnailView(slide: slide, networkService: networkService)
                .frame(width: Layout.thumbnailSize, height: Layout.thumbnailSize)
                .clipShape(RoundedRectangle(cornerRadius: Layout.thumbnailCornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: Layout.thumbnailCornerRadius)
                        .strokeBorder(Color.white.opacity(isCurrent ? 0.85 : 0.2), lineWidth: 2)
                }
                .scaleEffect(isFocused ? Layout.focusedScale : 1.0)
                .shadow(radius: isFocused ? 10 : 0)
        }
        .padding(Layout.thumbnailPadding)
        .animation(.easeInOut, value: isFocused)
    }
}

private struct SlideItemRow: Identifiable {
    let id: UUID
    let index: Int
    let slide: SlideItem
}

private struct SlideThumbnailView: View {
    let slide: SlideItem
    let networkService: NetworkService

    var body: some View {
        ZStack {
            SlideImageView(slide: slide, imageURL: slide.thumbnailURL, networkService: networkService)
            if slide.mediaType == .video {
                Color.black.opacity(0.3)
                Image(systemName: "play.fill")
                    .font(.title)
                    .foregroundColor(.white)
            }
        }
    }
}
