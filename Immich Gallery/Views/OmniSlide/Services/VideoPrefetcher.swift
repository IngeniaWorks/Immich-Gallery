import AVFoundation

@MainActor
final class VideoPrefetcher {
    static let shared = VideoPrefetcher()
    private var cachedAssets: [URL: AVURLAsset] = [:]
    private var cachedItems: [URL: AVPlayerItem] = [:]
    private let defaultBufferDuration: TimeInterval = 5.0

    func prefetch(url: URL, headers: [String: String] = [:]) {
        let asset: AVURLAsset
        if let existing = cachedAssets[url] {
            asset = existing
        } else {
            let options = headers.isEmpty ? nil : ["AVURLAssetHTTPHeaderFieldsKey": headers]
            asset = AVURLAsset(url: url, options: options)
            cachedAssets[url] = asset
        }
        
        Task {
            _ = try? await asset.load(.isPlayable)
            _ = try? await asset.load(.tracks)
            _ = try? await asset.load(.duration)
            if cachedItems[url] == nil {
                cachedItems[url] = makePlayerItem(for: asset)
            }
        }
    }

    func playerItem(for url: URL, headers: [String: String] = [:]) -> AVPlayerItem {
        let asset: AVURLAsset
        if let existing = cachedAssets[url] {
            asset = existing
        } else {
            let options = headers.isEmpty ? nil : ["AVURLAssetHTTPHeaderFieldsKey": headers]
            asset = AVURLAsset(url: url, options: options)
            cachedAssets[url] = asset
        }
        
        if let item = cachedItems.removeValue(forKey: url) {
            return item
        }
        return makePlayerItem(for: asset)
    }

    func freshPlayerItem(for url: URL, headers: [String: String] = [:]) -> AVPlayerItem {
        let asset: AVURLAsset
        if let existing = cachedAssets[url] {
            asset = existing
        } else {
            let options = headers.isEmpty ? nil : ["AVURLAssetHTTPHeaderFieldsKey": headers]
            asset = AVURLAsset(url: url, options: options)
            cachedAssets[url] = asset
        }
        return makePlayerItem(for: asset)
    }

    private func makePlayerItem(for asset: AVURLAsset) -> AVPlayerItem {
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = defaultBufferDuration
        return item
    }
}
