import Foundation
import SwiftUI

struct TransitionManager {
    enum PairMode {
        case sequential
        case overlap
    }

    struct TransitionDefinition {
        let type: TransitionType
        let outgoingDuration: TimeInterval
        let incomingDuration: TimeInterval
        let mode: PairMode
    }

    static func definition(
        for type: TransitionType,
        overrideDuration: Double? = nil,
        fallback: TransitionType = .fade
    ) -> TransitionDefinition {
        let resolvedType = type == .random ? fallback : type
        let base = baseDefinition(for: resolvedType)
        guard let overrideDuration else { return base }

        let adjustedIncoming = overrideDuration
        let adjustedOutgoing = overrideDuration
        return TransitionDefinition(
            type: resolvedType,
            outgoingDuration: adjustedOutgoing,
            incomingDuration: adjustedIncoming,
            mode: base.mode
        )
    }

    static func totalDuration(for definition: TransitionDefinition) -> TimeInterval {
        switch definition.mode {
        case .sequential:
            return definition.outgoingDuration + definition.incomingDuration
        case .overlap:
            return max(definition.outgoingDuration, definition.incomingDuration)
        }
    }

    static func randomNonRandomTransition() -> TransitionType {
        let options = TransitionType.allCases.filter { $0 != .random && $0 != .overlaySplit }
        return options.randomElement() ?? .fade
    }

    private static func baseDefinition(for type: TransitionType) -> TransitionDefinition {
        switch type {
        case .fade:
            return TransitionDefinition(type: type, outgoingDuration: 0.6, incomingDuration: 0.6, mode: .sequential)
        case .filmBurn:
            return TransitionDefinition(type: type, outgoingDuration: 0.4, incomingDuration: 0.8, mode: .sequential)
        case .wipe:
            return TransitionDefinition(type: type, outgoingDuration: 0.5, incomingDuration: 0.5, mode: .sequential)
        case .pushSlide:
            return TransitionDefinition(type: type, outgoingDuration: 0.6, incomingDuration: 0.6, mode: .overlap)
        case .zoom:
            return TransitionDefinition(type: type, outgoingDuration: 0.6, incomingDuration: 0.6, mode: .overlap)
        case .crossDissolve:
            return TransitionDefinition(type: type, outgoingDuration: 0.6, incomingDuration: 0.6, mode: .overlap)
        case .slide:
            return TransitionDefinition(type: type, outgoingDuration: 0.5, incomingDuration: 0.5, mode: .sequential)
        case .radialBlur:
            return TransitionDefinition(type: type, outgoingDuration: 0.7, incomingDuration: 0.7, mode: .sequential)
        case .overlaySplit:
            return TransitionDefinition(type: type, outgoingDuration: 1.0, incomingDuration: 1.0, mode: .overlap)
        case .random:
            return TransitionDefinition(type: .random, outgoingDuration: 0.6, incomingDuration: 0.6, mode: .overlap)
        }
    }
}
