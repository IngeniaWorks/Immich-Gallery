import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
typealias UIImage = NSImage
#endif

final class ImageCache {
    static let shared = ImageCache()

    private let cache = NSCache<NSURL, UIImage>()
    private var keyTracker: Set<NSURL> = []
    private let lock = NSLock()

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func insert(_ image: UIImage, for url: URL) {
        lock.lock()
        defer { lock.unlock() }
        let key = url as NSURL
        keyTracker.insert(key)
        cache.setObject(image, forKey: key)
    }

    func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAllObjects()
        keyTracker.removeAll()
    }
    
    func prune(keeping keepingURLs: Set<URL>) {
        lock.lock()
        defer { lock.unlock() }
        
        let keepingKeys = Set(keepingURLs.map { $0 as NSURL })
        let keysToRemove = keyTracker.subtracting(keepingKeys)
        
        for key in keysToRemove {
            cache.removeObject(forKey: key)
            keyTracker.remove(key)
        }
        
        if !keysToRemove.isEmpty {
            print("🧹 ImageCache: Pruned \(keysToRemove.count) images. Retaining \(keyTracker.count).")
        }
    }
}
