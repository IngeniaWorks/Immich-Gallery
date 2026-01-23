import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
typealias UIImage = NSImage
#endif

struct SlideImageView: View {
    let slide: SlideItem
    @StateObject private var loader: ImageLoader
    @State private var computedOrientation: SlideItem.Orientation?

    init(slide: SlideItem) {
        self.slide = slide
        _loader = StateObject(wrappedValue: ImageLoader(url: slide.mediaURL))
    }

    var body: some View {
        ZStack {
            switch loader.state {
            case .idle, .loading:
                ProgressView("Loading")
            case .success(let image, let source):
                let resolvedOrientation = computedOrientation ?? Self.orientation(for: image.size)
                imageContent(for: image, orientation: resolvedOrientation)
                    .overlay(alignment: .topLeading) {
                        if source == .cache {
                            Text("Offline")
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.65))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .padding()
                        }
                    }
                    .onAppear {
                        if computedOrientation == nil {
                            let orientation = Self.orientation(for: image.size)
                            let ratio = image.size.width / max(image.size.height, 1)
                            computedOrientation = orientation
                            let ratioText = String(format: "%.2f", ratio)
                            print("Image media: \(slide.name) | size=\(Int(image.size.width))x\(Int(image.size.height)) | ratio=\(ratioText) | computed=\(orientation) | slide=\(slide.orientation) | url=\(slide.mediaURL)")
                        }
                    }
            case .failure:
                VStack(spacing: 12) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 42))
                    Text("Unable to load image")
                        .font(.headline)
                }
            }
        }
        .task(id: slide.mediaURL) {
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
