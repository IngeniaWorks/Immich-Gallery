import Foundation
import SwiftUI

// MARK: - TransitionPairView
struct TransitionPairView<Outgoing: View, Incoming: View>: View {
    let definition: TransitionManager.TransitionDefinition
    let trigger: Int
    let isOutgoingVideo: Bool
    let isIncomingVideo: Bool
    let outgoingFilmBurnSeed: SIMD2<Float>
    let incomingFilmBurnSeed: SIMD2<Float>
    let outgoing: () -> Outgoing
    let incoming: () -> Incoming

    @State private var outgoingProgress: Double = 0
    @State private var incomingProgress: Double = 0
    @State private var animationTask: Task<Void, Never>?
    @State private var pushSlideDirection: PushSlideTransition.Direction = .left

    init(
        definition: TransitionManager.TransitionDefinition,
        trigger: Int,
        isOutgoingVideo: Bool = false,
        isIncomingVideo: Bool = false,
        outgoingFilmBurnSeed: SIMD2<Float> = SIMD2(0, 0),
        incomingFilmBurnSeed: SIMD2<Float> = SIMD2(0, 0),
        @ViewBuilder outgoing: @escaping () -> Outgoing,
        @ViewBuilder incoming: @escaping () -> Incoming
    ) {
        self.definition = definition
        self.trigger = trigger
        self.isOutgoingVideo = isOutgoingVideo
        self.isIncomingVideo = isIncomingVideo
        self.outgoingFilmBurnSeed = outgoingFilmBurnSeed
        self.incomingFilmBurnSeed = incomingFilmBurnSeed
        self.outgoing = outgoing
        self.incoming = incoming
    }

    var body: some View {
        baseContent
            .clipped()
            .ignoresSafeArea()
            .onAppear {
                startAnimationSequence()
            }
            .onChange(of: trigger) { _ in
                startAnimationSequence()
            }
            .onDisappear {
                animationTask?.cancel()
            }
    }

    private var baseContent: some View {
        ZStack {
            if definition.type == .filmBurn && outgoingProgress < 1.0 {
                // Keep outgoing on top while it's burning
                transitioned(
                    incoming(),
                    progress: incomingProgress,
                    isOutgoing: false
                )
                .opacity(layerOpacity(progress: incomingProgress, isOutgoing: false))

                transitioned(
                    outgoing(),
                    progress: outgoingProgress,
                    isOutgoing: true
                )
                .opacity(layerOpacity(progress: outgoingProgress, isOutgoing: true))
            } else {
                // Standard layering (outgoing then incoming)
                transitioned(
                    outgoing(),
                    progress: outgoingProgress,
                    isOutgoing: true
                )
                .opacity(layerOpacity(progress: outgoingProgress, isOutgoing: true))

                transitioned(
                    incoming(),
                    progress: incomingProgress,
                    isOutgoing: false
                )
                .opacity(layerOpacity(progress: incomingProgress, isOutgoing: false))
            }

            if definition.type == .filmBurn {
                // Add global flash/glow overlays
                FilmBurnSwiftUIFallback(
                    intensity: Float(outgoingProgress),
                    phase: outgoingProgress,
                    seed: outgoingFilmBurnSeed,
                    direction: .consume
                )
                .blendMode(.plusLighter)
                .allowsHitTesting(false)

                FilmBurnSwiftUIFallback(
                    intensity: Float(1.0 - incomingProgress),
                    phase: incomingProgress,
                    seed: incomingFilmBurnSeed,
                    direction: .reveal
                )
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
            }
        }
    }

    private func startAnimationSequence() {
        animationTask?.cancel()
        if definition.type == .pushSlide {
            pushSlideDirection = PushSlideTransition.Direction.random()
        }
        
        // Ensure starting state
        outgoingProgress = 0
        incomingProgress = 0

        animationTask = Task { @MainActor in
            let outgoingDuration = max(definition.outgoingDuration, 0.01)
            let incomingDuration = max(definition.incomingDuration, 0.01)
            
            // Start outgoing animation (and overlapping incoming)
            withAnimation(.easeInOut(duration: outgoingDuration)) {
                outgoingProgress = 1
                if definition.mode == .overlap {
                    incomingProgress = 1
                }
            }

            if definition.mode == .sequential {
                try? await Task.sleep(nanoseconds: UInt64(outgoingDuration * 1_000_000_000))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: incomingDuration)) {
                    incomingProgress = 1
                }
                // Force absolute completion after animation to avoid floating point residuals
                try? await Task.sleep(nanoseconds: 50_000_000)
                incomingProgress = 1.0
            } else {
                // For overlap, also force absolute completion
                try? await Task.sleep(nanoseconds: UInt64(outgoingDuration * 1_000_000_000 + 50_000_000))
                outgoingProgress = 1.0
                incomingProgress = 1.0
            }
        }
    }

    @ViewBuilder
    private func transitioned<Content: View>(
        _ content: Content,
        progress: Double,
        isOutgoing: Bool
    ) -> some View {
        switch definition.type {
        case .fade, .crossDissolve, .random, .overlaySplit:
            content.modifier(FadePairModifier(progress: progress, isOutgoing: isOutgoing))
        case .slide:
            content.modifier(SlidePairModifier(progress: progress, isOutgoing: isOutgoing))
        case .pushSlide:
            content.modifier(PushSlidePairModifier(progress: progress, isOutgoing: isOutgoing, direction: pushSlideDirection))
        case .zoom:
            content.modifier(ZoomPairModifier(progress: progress, isOutgoing: isOutgoing))
        case .wipe:
            content.modifier(WipePairModifier(progress: progress, isOutgoing: isOutgoing))
        case .radialBlur:
            content.modifier(BlurTransitionModifier(progress: progress, isOutgoing: isOutgoing))
        case .filmBurn:
            if isOutgoing {
                content.modifier(FilmBurnPhaseModifier(phase: progress, seed: outgoingFilmBurnSeed))
            } else {
                content.modifier(FilmBurnRevealModifier(phase: progress, seed: incomingFilmBurnSeed))
            }
        }
    }

    private func layerOpacity(progress: Double, isOutgoing: Bool) -> Double {
        switch definition.type {
        case .fade, .crossDissolve:
            return isOutgoing ? (1.0 - progress) : progress
        case .filmBurn:
            // Symmetrical burn: outgoing burns out (stays visible but fades slightly), 
            // incoming reveals from burn (starts transparent then becomes opaque)
            return isOutgoing ? max(0.4, 1.0 - progress * 0.6) : progress
        default:
            return 1.0
        }
    }
}

// MARK: - Modifiers (Inlined for simplicity or porting)
private struct FadePairModifier: ViewModifier {
    let progress: Double
    let isOutgoing: Bool
    func body(content: Content) -> some View {
        content.opacity(isOutgoing ? (1.0 - progress) : progress)
    }
}

private struct SlidePairModifier: ViewModifier {
    let progress: Double
    let isOutgoing: Bool
    func body(content: Content) -> some View {
        GeometryReader { proxy in
            let offset = proxy.size.width
            content.offset(x: isOutgoing ? -offset * progress : offset * (1.0 - progress))
        }
    }
}

private struct PushSlidePairModifier: ViewModifier {
    let progress: Double
    let isOutgoing: Bool
    let direction: PushSlideTransition.Direction
    func body(content: Content) -> some View {
        GeometryReader { proxy in
            let offset = direction.offset(size: proxy.size, progress: progress, isOutgoing: isOutgoing)
            content.offset(offset)
        }
    }
}

private struct ZoomPairModifier: ViewModifier {
    let progress: Double
    let isOutgoing: Bool
    func body(content: Content) -> some View {
        let scale = isOutgoing ? 1.0 + progress * 3.0 : 0.05 + progress * 0.95
        return content
            .scaleEffect(scale, anchor: .center)
            .opacity(isOutgoing ? (1.0 - progress) : progress)
    }
}

private struct WipePairModifier: ViewModifier {
    let progress: Double
    let isOutgoing: Bool
    func body(content: Content) -> some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let maskWidth = isOutgoing ? width * (1.0 - progress) : width * progress
            let offsetX = isOutgoing ? width * progress : 0
            content.mask(
                Rectangle()
                    .frame(width: max(maskWidth, 0.0), height: proxy.size.height)
                    .offset(x: offsetX)
            )
        }
    }
}
