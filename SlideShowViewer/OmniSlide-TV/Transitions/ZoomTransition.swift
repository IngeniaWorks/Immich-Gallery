import SwiftUI

enum ZoomTransition {
    static let transition = AnyTransition.asymmetric(
        insertion: .scale(scale: 0.92).combined(with: .opacity),
        removal: .scale(scale: 1.05).combined(with: .opacity)
    )
}
