import SwiftUI
import Foundation

enum TransitionType: String, CaseIterable, Codable {
    case fade
    case slide
    case pushSlide
    case zoom
    case wipe
    case filmBurn
    case crossDissolve
    case radialBlur
    case overlaySplit
    case random
}

extension TransitionType {
    var requiresCoreImage: Bool {
        false
    }
}
