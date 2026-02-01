import Foundation
import SwiftUI

struct MemoriesSlideItem: Identifiable, Hashable {
    enum MediaType {
        case image
        case video
    }

    enum Orientation {
        case landscape
        case portrait
    }

    let id: UUID
    let assetID: String
    let name: String
    let mediaURL: URL
    let caption: String
    let mediaType: MediaType
    let orientation: Orientation

    init(asset: ImmichAsset, baseURL: String) {
        id = UUID()
        assetID = asset.id
        name = asset.originalFileName
        caption = asset.originalFileName

        let urlString: String
        if asset.type == .video || asset.livePhotoVideoId != nil {
            urlString = "\(baseURL)/api/assets/\(asset.id)/video/playback"
        } else {
            urlString = "\(baseURL)/api/assets/\(asset.id)/thumbnail?format=webp&size=preview"
        }
        mediaURL = URL(string: urlString) ?? URL(string: "about:blank")!

        mediaType = asset.type == .video || asset.livePhotoVideoId != nil ? .video : .image
        let width = CGFloat(asset.exifInfo?.exifImageWidth ?? 0)
        let height = CGFloat(asset.exifInfo?.exifImageHeight ?? 0)
        if height > 0 {
            let ratio = width / height
            orientation = ratio >= 1.33 ? .landscape : .portrait
        } else {
            orientation = .landscape
        }
    }
}
