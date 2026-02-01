import Combine
import Foundation
import ImageIO
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
typealias UIImage = NSImage
#endif

enum ImageSource {
    case network
    case cache
}

enum ImageLoadState {
    case idle
    case loading
    case success(UIImage, source: ImageSource)
    case failure
}

final class ImageLoader: ObservableObject {
    @Published private(set) var state: ImageLoadState = .idle

    private let url: URL
    private let thumbnailURL: URL?
    private let cacheManager: CacheManager
    private let imageCache: ImageCache
    private let networkService: NetworkService
    private let session: URLSession
    private static let maxPixelSize: CGFloat = 3840 // Increased for 4K tvOS

    init(url: URL, thumbnailURL: URL? = nil, networkService: NetworkService, cacheManager: CacheManager = .shared, imageCache: ImageCache = .shared) {
        self.url = url
        self.thumbnailURL = thumbnailURL
        self.networkService = networkService
        self.cacheManager = cacheManager
        self.imageCache = imageCache
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .useProtocolCachePolicy
        self.session = URLSession(configuration: configuration)
        
        // Immediate synchronous cache check
        if let cachedImage = imageCache.image(for: url) {
            self.state = .success(cachedImage, source: .cache)
        } else if let data = cacheManager.cachedImageData(for: url),
                  let image = Self.decodeImage(from: data) {
            imageCache.insert(image, for: url)
            self.state = .success(image, source: .cache)
        }
    }

    func load() async {
        let isLoading = await MainActor.run { () -> Bool in
            switch state {
            case .loading, .success:
                return true
            default:
                state = .loading
                return false
            }
        }
        if isLoading {
            return
        }

        if let cachedImage = imageCache.image(for: url) {
            await MainActor.run { self.state = .success(cachedImage, source: .cache) }
            if let thumbnailURL, thumbnailURL != url {
                Self.prefetch(urls: [thumbnailURL], networkService: networkService, cacheManager: cacheManager, imageCache: imageCache)
            }
            return
        }

        if let data = cacheManager.cachedImageData(for: url),
           let image = Self.decodeImage(from: data) {
            imageCache.insert(image, for: url)
            await MainActor.run { self.state = .success(image, source: .cache) }
            if let thumbnailURL, thumbnailURL != url {
                Self.prefetch(urls: [thumbnailURL], networkService: networkService, cacheManager: cacheManager, imageCache: imageCache)
            }
            return
        }

        do {
            var request = URLRequest(
                url: url,
                cachePolicy: .reloadIgnoringLocalCacheData,
                timeoutInterval: 30
            )
            // Inject Auth Headers
            if let token = networkService.accessToken {
                if networkService.currentAuthType == .apiKey {
                    request.setValue(token, forHTTPHeaderField: "x-api-key")
                } else {
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
            }

            let (data, response) = try await session.data(for: request)
            guard Self.isValidImageResponse(response) else {
                await MainActor.run { self.state = .failure }
                return
            }
            guard let image = Self.decodeImage(from: data) else {
                await MainActor.run { self.state = .failure }
                return
            }
            imageCache.insert(image, for: url)
            try cacheManager.storeImageData(data, for: url)
            await MainActor.run { self.state = .success(image, source: .network) }
            if let thumbnailURL, thumbnailURL != url {
                Self.prefetch(urls: [thumbnailURL], networkService: networkService, cacheManager: cacheManager, imageCache: imageCache)
            }
        } catch {
            if let data = cacheManager.cachedImageData(for: url), let image = Self.decodeImage(from: data) {
                imageCache.insert(image, for: url)
                await MainActor.run { self.state = .success(image, source: .cache) }
            } else {
                print("ImageLoader: Failed to load \(url) - \(error)")
                await MainActor.run { self.state = .failure }
            }
        }
    }

    static func prefetch(urls: [URL], networkService: NetworkService, cacheManager: CacheManager = .shared, imageCache: ImageCache = .shared) {
        for url in urls {
            Task.detached(priority: .utility) {
                let hasCachedImage = await MainActor.run {
                    imageCache.image(for: url) != nil
                }
                if hasCachedImage {
                    return
                }
                let hasCachedData = await MainActor.run {
                    cacheManager.cachedImageData(for: url) != nil
                }
                if hasCachedData {
                    if let data = cacheManager.cachedImageData(for: url),
                       let image = decodeImage(from: data) {
                        await MainActor.run {
                            imageCache.insert(image, for: url)
                        }
                    }
                    return
                }
                
                let configuration = URLSessionConfiguration.default
                configuration.requestCachePolicy = .useProtocolCachePolicy
                let session = URLSession(configuration: configuration)
                do {
                    var request = URLRequest(
                        url: url,
                        cachePolicy: .reloadIgnoringLocalCacheData,
                        timeoutInterval: 30
                    )
                     // Inject Auth Headers (thread-safe access needed? NetworkService is ObservableObject, accessing published props from detached task might be racy if not careful. But here we usually pass values. 
                     // Wait, prefetch is static. We pass networkService instance. Accessing its properties from background thread is technically unsafe if they are being modified on main thread. 
                     // However, credentials usually don't change rapidly during slideshow.
                     // To be safe, we should capture token before task. But prefetch iterates multiple URLs.
                     // Let's rely on standard access; usually fine for read-mostly. 
                     // Better: Capture token in the caller or main actor block? 
                     // For now, let's access responsibly.)
                     
                    if let token = await MainActor.run(body: { networkService.accessToken }) {
                        let authType = await MainActor.run(body: { networkService.currentAuthType })
                        if authType == .apiKey {
                            request.setValue(token, forHTTPHeaderField: "x-api-key")
                        } else {
                            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                        }
                    }

                    let (data, response) = try await session.data(for: request)
                    guard isValidImageResponse(response) else {
                        return
                    }
                    if let image = decodeImage(from: data) {
                        await MainActor.run {
                            imageCache.insert(image, for: url)
                        }
                    }
                    try await MainActor.run {
                        try cacheManager.storeImageData(data, for: url)
                    }
                } catch {
                    return
                }
            }
        }
    }

    private static func decodeImage(from data: Data) -> UIImage? {
        #if canImport(UIKit)
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        guard CGImageSourceGetCount(imageSource) > 0 else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        if let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) {
            return UIImage(cgImage: cgImage)
        }
        return UIImage(data: data)
        #elseif canImport(AppKit)
        return NSImage(data: data)
        #else
        return nil
        #endif
    }

    private static func isValidImageResponse(_ response: URLResponse?) -> Bool {
        guard let httpResponse = response as? HTTPURLResponse else { return true }
        guard (200...299).contains(httpResponse.statusCode) else { return false }
        guard let mimeType = httpResponse.mimeType else { return true }
        return mimeType.hasPrefix("image")
    }
}
