import SwiftUI

struct SlideImageView: View {
    let slide: SlideItem
    let imageURL: URL
    @StateObject private var loader: ImageLoader
    @State private var computedOrientation: SlideItem.Orientation?
    var onFailure: (() -> Void)? = nil
    private let networkService: NetworkService

    @State private var didNotifyFailure = false

    init(slide: SlideItem, imageURL: URL? = nil, networkService: NetworkService, onFailure: (() -> Void)? = nil) {
        self.slide = slide
        let resolvedURL = imageURL ?? slide.mediaURL
        self.imageURL = resolvedURL
        self.networkService = networkService
        _loader = StateObject(wrappedValue: ImageLoader(url: resolvedURL, thumbnailURL: slide.thumbnailURL, networkService: networkService))
        self.onFailure = onFailure
    }

    var body: some View {
        ZStack {
            switch loader.state {
            case .idle, .loading:
                LoadingView(label: "Loading")
            case .success(let image, _):
                let resolvedOrientation = computedOrientation ?? Self.orientation(for: image.size)
                imageContent(for: image, orientation: resolvedOrientation)
                    .onAppear {
                        if computedOrientation == nil {
                            computedOrientation = Self.orientation(for: image.size)
                        }
                    }
            case .failure:
                Color.clear
            }
        }
        .onReceive(loader.$state) { newValue in
            guard case .failure = newValue else { return }
            guard !didNotifyFailure else { return }
            didNotifyFailure = true
            onFailure?()
        }
        .task(id: imageURL) {
            didNotifyFailure = false
            await loader.load()
        }
    }

    @ViewBuilder
    private func imageContent(for image: UIImage, orientation: SlideItem.Orientation) -> some View {
        if orientation == .portrait {
            PortraitView {
                Image(uiImage: image)
                    .resizable()
            }
        } else {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        }
    }

    private static func orientation(for size: CGSize) -> SlideItem.Orientation {
        guard size.height > 0 else { return .landscape }
        let ratio = size.width / size.height
        return ratio >= 1.33 ? .landscape : .portrait
    }
}
