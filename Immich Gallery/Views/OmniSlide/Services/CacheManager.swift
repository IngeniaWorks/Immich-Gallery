import CryptoKit
import Foundation

final class CacheManager {
    static let shared = CacheManager()

    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let memoryCache = NSCache<NSURL, NSData>()
    private let maxCacheSizeBytes: Int = 200 * 1024 * 1024

    private init() {
        cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OmniSlideTVImages", isDirectory: true)
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }

    func cachedImageData(for url: URL) -> Data? {
        if let cached = memoryCache.object(forKey: url as NSURL) {
            return cached as Data
        }

        let fileURL = cacheFileURL(for: url)
        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        memoryCache.setObject(data as NSData, forKey: url as NSURL)
        return data
    }

    func storeImageData(_ data: Data, for url: URL) throws {
        memoryCache.setObject(data as NSData, forKey: url as NSURL)
        let fileURL = cacheFileURL(for: url)
        try data.write(to: fileURL, options: [.atomic])
        try enforceCacheLimit()
    }

    private func cacheFileURL(for url: URL) -> URL {
        let hashedName = sha256(url.absoluteString)
        return cacheDirectory.appendingPathComponent(hashedName).appendingPathExtension("img")
    }

    private func sha256(_ value: String) -> String {
        let hash = SHA256.hash(data: Data(value.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private func enforceCacheLimit() throws {
        let resourceKeys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey]
        let fileURLs = try fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: Array(resourceKeys)
        )
        var totalSize = 0
        var fileInfos: [(url: URL, size: Int, date: Date)] = []

        for url in fileURLs {
            let values = try url.resourceValues(forKeys: resourceKeys)
            let size = values.fileSize ?? 0
            let date = values.contentModificationDate ?? .distantPast
            totalSize += size
            fileInfos.append((url, size, date))
        }

        guard totalSize > maxCacheSizeBytes else { return }

        let sortedFiles = fileInfos.sorted { $0.date < $1.date }
        var bytesToFree = totalSize - maxCacheSizeBytes

        for file in sortedFiles {
            try fileManager.removeItem(at: file.url)
            bytesToFree -= file.size
            if bytesToFree <= 0 {
                break
            }
        }
    }
}
