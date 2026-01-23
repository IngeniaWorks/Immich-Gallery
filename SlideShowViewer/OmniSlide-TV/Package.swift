// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OmniSlideTV",
    platforms: [
        .tvOS(.v17)
    ],
    products: [
        .library(
            name: "OmniSlideTV",
            targets: ["OmniSlideTV"]
        )
    ],
    targets: [
        .target(
            name: "OmniSlideTV",
            path: ".",
            exclude: [
                "Assets.xcassets",
                "Models",
                "Services",
                "ViewModels",
                "Views/ContentView.swift",
                "Views/PauseShelfView.swift",
                "Views/PortraitView.swift",
                "Views/SlideImageView.swift",
                "Views/SlideVideoView.swift",
                "Views/SlideshowView.swift",
                "OmniSlide_TV.swift",
                ".DS_Store"
            ],
            sources: [
                "Transitions",
                "Views/TransitionView.swift"
            ]
        )
    ]
)
