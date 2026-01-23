import SwiftUI

enum WipeTransition {
    static let transition = AnyTransition.asymmetric(
        insertion: .move(edge: .trailing).combined(with: .opacity),
        removal: .opacity
    )
}
