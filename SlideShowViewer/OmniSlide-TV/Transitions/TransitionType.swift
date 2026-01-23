import Foundation

enum TransitionType: String, CaseIterable, Codable {
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
