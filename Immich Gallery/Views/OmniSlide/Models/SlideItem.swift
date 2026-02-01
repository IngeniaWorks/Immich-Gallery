import Foundation

struct SlideItem: Identifiable, Codable, Hashable {
    enum MediaType: String, Codable {
        case image
        case video
    }

    enum Orientation: String, Codable {
        case landscape
        case portrait
    }

    let id: UUID
    let assetId: String // Link to ImmichAsset
    let name: String
    let mediaURL: URL
    let thumbnailURL: URL
    let caption: String
    let mediaType: MediaType
    let orientation: Orientation
    
    // Helper to create from ImmichAsset behavior could be here or in VM
}
