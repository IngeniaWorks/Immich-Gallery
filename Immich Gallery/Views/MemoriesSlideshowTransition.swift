import SwiftUI

enum MemoriesSlideshowTransition: String, CaseIterable {
    case fade
    case slide
    case zoom
    case wipe
    case cube
    case flip
    case coverFlow
    case fadeThrough
    case slideLeftRight
    case random
}

struct MemoriesTransitionView<Content: View>: View {
    let transition: AnyTransition
    let animation: Animation
    let trigger: Int
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            content()
                .id(trigger)
                .transition(transition)
        }
        .animation(animation, value: trigger)
    }
}

struct MemoriesTransitionManager {
    static func transition(for type: MemoriesSlideshowTransition, fallback: MemoriesSlideshowTransition) -> AnyTransition {
        let resolved = type == .random ? fallback : type
        switch resolved {
        case .fade:
            return .opacity
        case .slide:
            return .move(edge: .trailing)
        case .zoom:
            return .scale.combined(with: .opacity)
        case .wipe:
            return .asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))
        case .cube:
            return .opacity
        case .flip:
            return .opacity
        case .coverFlow:
            return .opacity
        case .fadeThrough:
            return .opacity
        case .slideLeftRight:
            return .move(edge: .trailing)
        case .random:
            return .opacity
        }
    }

    static func animation(for type: MemoriesSlideshowTransition, overrideDuration: Double? = nil) -> Animation {
        let duration = overrideDuration ?? 1.2
        switch type {
        case .fade:
            return .easeInOut(duration: duration)
        case .slide:
            return .easeInOut(duration: duration)
        case .zoom:
            return .easeInOut(duration: duration)
        case .wipe:
            return .easeInOut(duration: duration)
        case .cube:
            return .easeInOut(duration: duration)
        case .flip:
            return .easeInOut(duration: duration)
        case .coverFlow:
            return .easeInOut(duration: duration)
        case .fadeThrough:
            return .easeInOut(duration: duration)
        case .slideLeftRight:
            return .easeInOut(duration: duration)
        case .random:
            return .easeInOut(duration: duration)
        }
    }

    static func randomNonRandomTransition() -> MemoriesSlideshowTransition {
        let options: [MemoriesSlideshowTransition] = [.fade, .slide, .zoom, .wipe, .fadeThrough, .slideLeftRight]
        return options.randomElement() ?? .fade
    }
}
