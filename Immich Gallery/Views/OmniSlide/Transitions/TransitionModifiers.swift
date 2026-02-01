import SwiftUI

enum PushSlideTransition {
    enum Direction: CaseIterable {
        case left
        case right
        case up
        case down

        static func random() -> Direction {
            allCases.randomElement() ?? .left
        }

        func offset(size: CGSize, progress: Double, isOutgoing: Bool) -> CGSize {
            let width = size.width
            let height = size.height
            switch self {
            case .left:
                let x = isOutgoing ? -width * progress : width * (1.0 - progress)
                return CGSize(width: x, height: 0)
            case .right:
                let x = isOutgoing ? width * progress : -width * (1.0 - progress)
                return CGSize(width: x, height: 0)
            case .up:
                let y = isOutgoing ? -height * progress : height * (1.0 - progress)
                return CGSize(width: 0, height: y)
            case .down:
                let y = isOutgoing ? height * progress : -height * (1.0 - progress)
                return CGSize(width: 0, height: y)
            }
        }
    }
}

enum BlurTransitionConfig {
    static let maxRadius: CGFloat = 24
}

struct BlurTransitionModifier: ViewModifier {
    let progress: Double
    let isOutgoing: Bool

    func body(content: Content) -> some View {
        let blurRadius = isOutgoing
            ? BlurTransitionConfig.maxRadius * progress
            : BlurTransitionConfig.maxRadius * (1.0 - progress)
        let opacity = isOutgoing ? (1.0 - progress) : progress
        content
            .blur(radius: blurRadius, opaque: true)
            .opacity(opacity)
    }
}
