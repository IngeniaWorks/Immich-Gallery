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

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func insert(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }

    func removeAll() {
        cache.removeAllObjects()
    }
}
