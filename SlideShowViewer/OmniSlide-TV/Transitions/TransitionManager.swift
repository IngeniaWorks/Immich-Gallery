import SwiftUI

struct TransitionManager {
    static func transition(for type: TransitionType, fallback: TransitionType = .fade) -> AnyTransition {
        let resolvedType = type == .random ? fallback : type
        switch resolvedType {
        case .fade:
            return FadeTransition.transition
        case .slide:
            return SlideTransition.transition
        case .zoom:
            return ZoomTransition.transition
        case .wipe:
            return WipeTransition.transition
        case .cube:
            // Placeholder uses a simple fade until cube is implemented.
            return CubeTransition.transition
        case .flip:
            // Placeholder uses a simple fade until flip is implemented.
            return FlipTransition.transition
        case .coverFlow:
            // Placeholder uses a simple fade until cover flow is implemented.
            return CoverFlowTransition.transition
        case .fadeThrough:
            // Placeholder keeps a gentle fade until fade-through is implemented.
            return FadeThroughTransition.transition
        case .slideLeftRight:
            // Placeholder keeps slide motion until left/right variant is implemented.
            return SlideLeftRightTransition.transition
        case .random:
            return FadeTransition.transition
        }
    }

    static func animation(for type: TransitionType, overrideDuration: Double? = nil) -> Animation {
        let duration = overrideDuration ?? defaultDuration(for: type)
        return .easeInOut(duration: duration)
    }

    private static func defaultDuration(for type: TransitionType) -> Double {
        switch type {
        case .fade:
            return 1.0
        case .slide:
            return 0.9
        case .zoom:
            return 1.1
        case .wipe:
            return 1.0
        case .cube:
            return 1.0
        case .flip:
            return 1.0
        case .coverFlow:
            return 1.0
        case .fadeThrough:
            return 1.0
        case .slideLeftRight:
            return 0.9
        case .random:
            return 1.0
        }
    }

    static func randomNonRandomTransition() -> TransitionType {
        let options = TransitionType.allCases.filter { $0 != .random }
        return options.randomElement() ?? .fade
    }
}
