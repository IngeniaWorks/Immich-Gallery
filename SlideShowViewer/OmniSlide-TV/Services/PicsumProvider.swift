import Foundation

struct PicsumProvider {
    static func makeSlides(count: Int = 20) -> [SlideItem] {
        let portraitSeeds = [9, 14, 22, 31, 37, 44, 58, 63]
        let videoURLs = [
            URL(string: "https://devstreaming-cdn.apple.com/videos/wwdc/2025/367/2/56654673-9cbe-4dc1-bdbe-7960bd7d92c2/downloads/wwdc2025-367_sd.mp4?dl=1")!
        ]
        let portraitImageCount = min(8, count)
        let portraitVideoCount = min(3, max(0, count - portraitImageCount))
        let forcedCount = portraitImageCount + portraitVideoCount
        let remainingCount = max(0, count - forcedCount)
        var forcedSlides: [SlideItem] = []
        forcedSlides.reserveCapacity(forcedCount)

        var nextIndex = 1
        for _ in 0..<portraitImageCount {
            let seed = portraitSeeds[nextIndex % portraitSeeds.count]
            forcedSlides.append(
                SlideItem(
                    id: UUID(),
                    name: "Portrait \(nextIndex)",
                    mediaURL: URL(string: "https://picsum.photos/1080/1920?random=\(seed)")!,
                    caption: "Portrait \(nextIndex)",
                    mediaType: .image,
                    orientation: .portrait
                )
            )
            nextIndex += 1
        }

        for _ in 0..<portraitVideoCount {
            let videoURL = videoURLs[nextIndex % videoURLs.count]
            forcedSlides.append(
                SlideItem(
                    id: UUID(),
                    name: "Portrait Video \(nextIndex)",
                    mediaURL: videoURL,
                    caption: "Portrait Video \(nextIndex)",
                    mediaType: .video,
                    orientation: .portrait
                )
            )
            nextIndex += 1
        }

        let shuffledForcedSlides = forcedSlides.shuffled()
        let remainingSlides = (1...remainingCount).compactMap { offset -> SlideItem? in
            let nextIndex = forcedCount + offset
            let isVideo = nextIndex % 6 == 0
            let isPortrait = portraitSeeds.contains(nextIndex % 70)
            if isVideo {
                let videoURL = videoURLs[nextIndex % videoURLs.count]
                return SlideItem(
                    id: UUID(),
                    name: "Video \(nextIndex)",
                    mediaURL: videoURL,
                    caption: "Video \(nextIndex)",
                    mediaType: .video,
                    orientation: isPortrait ? .portrait : .landscape
                )
            }

            let size = isPortrait ? "1080/1920" : "1920/1080"
            return SlideItem(
                id: UUID(),
                name: "Slide \(nextIndex)",
                mediaURL: URL(string: "https://picsum.photos/\(size)?random=\(nextIndex)")!,
                caption: "Photo \(nextIndex)",
                mediaType: .image,
                orientation: isPortrait ? .portrait : .landscape
            )
        }

        return shuffledForcedSlides + remainingSlides
    }
}
