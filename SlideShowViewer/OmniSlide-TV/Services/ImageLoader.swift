import Combine
import Foundation
import UIKit

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
    private let cacheManager: CacheManager
    private let session: URLSession

    init(url: URL, cacheManager: CacheManager = .shared) {
        self.url = url
        self.cacheManager = cacheManager
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .useProtocolCachePolicy
        self.session = URLSession(configuration: configuration)
    }

    func load() async {
        let isLoading = await MainActor.run { () -> Bool in
            if case .loading = state {
                return true
            }
            state = .loading
            return false
        }
        if isLoading {
            return
        }

        do {
            let request = URLRequest(
                url: url,
                cachePolicy: .reloadIgnoringLocalCacheData,
                timeoutInterval: 30
            )
            let (data, _) = try await session.data(for: request)
            guard let image = UIImage(data: data) else {
                await MainActor.run { self.state = .failure }
                return
            }
            try cacheManager.storeImageData(data, for: url)
            await MainActor.run { self.state = .success(image, source: .network) }
        } catch {
            if let data = cacheManager.cachedImageData(for: url), let image = UIImage(data: data) {
                await MainActor.run { self.state = .success(image, source: .cache) }
            } else {
                await MainActor.run { self.state = .failure }
            }
        }
    }
}
