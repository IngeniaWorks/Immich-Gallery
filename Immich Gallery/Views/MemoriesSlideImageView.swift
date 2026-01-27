import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
typealias UIImage = NSImage
#endif

struct MemoriesSlideImageView: View {
    let slide: MemoriesSlideItem
    let assetService: AssetService
    let thumbnailCache: ThumbnailCache

    @State private var image: UIImage?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            if let image {
                platformImage(image)
                    .resizable()
                    .scaledToFill()
            } else if isLoading {
                ProgressView()
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 32))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .task(id: slide.assetID) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let fetched = try await thumbnailCache.getThumbnail(for: slide.assetID, size: "preview") {
                try await assetService.loadImage(assetId: slide.assetID, size: "preview")
            }
            image = fetched
        } catch {
            image = nil
        }
    }

    private func platformImage(_ image: UIImage) -> Image {
#if canImport(UIKit)
        return Image(uiImage: image)
#else
        return Image(nsImage: image)
#endif
    }
}
