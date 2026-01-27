import SwiftUI
import simd

// MARK: - Configuration

private enum FilmBurnShaderConfig {
    static let defaultIntensity: Float = 1.0
    static let defaultSpeed: Float = 1.0
    static let overlayOpacity: Double = 0.85
    static let fallbackSeed = SIMD2<Float>(0.42, 0.68)
    static let seedRange: ClosedRange<Float> = 0.1...0.9
}

enum FilmBurnSeedGenerator {
    static func randomSeed() -> SIMD2<Float> {
        SIMD2(
            Float.random(in: FilmBurnShaderConfig.seedRange),
            Float.random(in: FilmBurnShaderConfig.seedRange)
        )
    }

    static func seed(from value: UInt64) -> SIMD2<Float> {
        let mixed = (value ^ (value >> 33)) &* 0xff51afd7ed558ccd
        let x = Double(mixed & 0xFFFF) / Double(0xFFFF)
        let y = Double((mixed >> 16) & 0xFFFF) / Double(0xFFFF)
        let lower = Double(FilmBurnShaderConfig.seedRange.lowerBound)
        let upper = Double(FilmBurnShaderConfig.seedRange.upperBound)
        let scaledX = Float(lower + (upper - lower) * x)
        let scaledY = Float(lower + (upper - lower) * y)
        return SIMD2(scaledX, scaledY)
    }
}

enum FilmBurnDirection {
    case consume
    case reveal
}

// MARK: - Modifiers

struct FilmBurnModifier: ViewModifier {
    let intensity: Float
    let speed: Float
    let seed: SIMD2<Float>
    let phase: CGFloat
    let direction: FilmBurnDirection

    func body(content: Content) -> some View {
        content
            .overlay(
                FilmBurnSwiftUIFallback(
                    intensity: intensity,
                    phase: phase,
                    seed: seed,
                    direction: direction
                )
            )
            .compositingGroup()
    }
}

struct FilmBurnPhaseModifier: AnimatableModifier {
    var phase: CGFloat
    let seed: SIMD2<Float>
    let direction: FilmBurnDirection = .consume

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func body(content: Content) -> some View {
        let clampedPhase = CGFloat(max(min(phase, 1.0), 0.0))
        let rawBurnPhase = direction == .reveal ? 1.0 - clampedPhase : clampedPhase
        let burnPhase = rawBurnPhase < 0.05 ? 0.0 : rawBurnPhase // More aggressive threshold
        let intensity = Float(burnPhase) * FilmBurnShaderConfig.defaultIntensity
        content
            .modifier(
                FilmBurnModifier(
                    intensity: intensity,
                    speed: FilmBurnShaderConfig.defaultSpeed,
                    seed: seed,
                    phase: phase,
                    direction: direction
                )
            )
            .scaleEffect(1.0 + 0.02 * phase)
    }
}

struct FilmBurnRevealModifier: AnimatableModifier {
    var phase: CGFloat
    let seed: SIMD2<Float>

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func body(content: Content) -> some View {
        let clampedPhase = CGFloat(max(min(phase, 1.0), 0.0))
        let rawBurnPhase = 1.0 - clampedPhase
        let burnPhase = rawBurnPhase < 0.05 ? 0.0 : rawBurnPhase // More aggressive threshold
        let intensity = Float(burnPhase) * FilmBurnShaderConfig.defaultIntensity
        content
            .modifier(
                FilmBurnModifier(
                    intensity: intensity,
                    speed: FilmBurnShaderConfig.defaultSpeed,
                    seed: seed,
                    phase: phase,
                    direction: .reveal
                )
            )
            .scaleEffect(1.02 - 0.02 * clampedPhase)
    }
}

// MARK: - SwiftUI Fallback Implementation

struct FilmBurnSwiftUIFallback: View {
    let intensity: Float
    let phase: CGFloat
    let seed: SIMD2<Float>
    let direction: FilmBurnDirection

    var body: some View {
        GeometryReader { proxy in
            let widthScale = proxy.size.width / 1920
            let heightScale = proxy.size.height / 1080
            let coverageScale = max(1.25, max(widthScale, heightScale))
            let rawPhase = Double(max(0, min(intensity, 1)))
            let basePhase = rawPhase < 0.05 ? 0.0 : rawPhase
            
            // Optimization: If intensity is near zero, don't render anything
            if basePhase <= 0 {
                Color.clear
            } else {
                let clampedPhase = max(0, min(Double(phase), 1))
                let phaseSplit = FilmBurnSwiftUIFallback.phaseOneFraction
                let phaseOneProgress = min(basePhase / phaseSplit, 1.0)
                let phaseTwoProgress = max(basePhase - phaseSplit, 0.0) / max(1.0 - phaseSplit, 0.001)
                
                // Use flash to drive a screen-wide glow
                let flashPhase = 1.0 - clampedPhase
                let flash = pow(max(0, 1.0 - flashPhase * 1.4), 2)
                
                let flicker = sin(basePhase * 30.0 + Double(seed.x) * 3.4) * 0.1
                let smallSpots = FilmBurnSwiftUIFallback.smallSpots(for: seed)
                let largeSpot = FilmBurnSwiftUIFallback.largeSpot(for: seed)
                let haloPhase = direction == .reveal ? basePhase : clampedPhase
                let burnHalo = max(0, haloPhase - 0.4)
                
                ZStack {
                    // Global flash effect
                    Color.white
                        .opacity(flash * 0.4 * Double(intensity))
                        .blendMode(.screen)

                    RadialGradient(
                        colors: [
                            Color(red: 2.8, green: 1.6, blue: 0.4).opacity(burnHalo * 0.5),
                            Color(red: 1.8, green: 0.8, blue: 0.2).opacity(burnHalo * 0.3),
                            Color.clear
                        ],
                        center: UnitPoint(x: 0.5, y: 0.5),
                        startRadius: 120,
                        endRadius: 620
                    )
                    .blendMode(.screen)
                    .opacity(direction == .reveal ? basePhase : 1.0)

                    ForEach(Array(smallSpots.enumerated()), id: \.offset) { index, spot in
                        let delay = Double(index) * 0.08
                        let progress = max(0, min(1, (phaseOneProgress - delay) / max(0.1, 1 - delay)))
                        BurnSpotLayer(
                            config: spot,
                            progress: progress,
                            brightness: basePhase
                        )
                    }

                    BurnSpotLayer(
                        config: largeSpot,
                        progress: phaseTwoProgress,
                        brightness: basePhase
                    )
                    .blendMode(.screen)
                    .overlay(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(min(1.0, basePhase * phaseTwoProgress)),
                                Color.white.opacity(0)
                            ],
                            center: largeSpot.center,
                            startRadius: 0,
                            endRadius: largeSpot.baseRadius * 0.22 * phaseTwoProgress
                        )
                        .blendMode(.screen)
                    )

                    Color.black
                        .opacity(basePhase * 0.28)
                        .blendMode(.multiply)

                    Color.white
                        .opacity(flicker * basePhase * 0.3)
                        .blendMode(.screen)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .scaleEffect(coverageScale, anchor: .center)
                .ignoresSafeArea()
                .drawingGroup() // High-performance GPU rendering for complex gradients
            }
        }
        .compositingGroup()
        .allowsHitTesting(false)
    }
}

// MARK: - Supporting Views

private struct BurnSpotLayer: View {
    struct Configuration {
        let center: UnitPoint
        let baseRadius: CGFloat
        let color: Color
        let edgeColor: Color
        let coreOpacity: Double
        let stretchX: CGFloat
        let stretchY: CGFloat
    }

    let config: Configuration
    let progress: Double
    let brightness: Double

    var body: some View {
        let clampedProgress = max(0, min(progress, 1))
        let outerRadius = config.baseRadius * clampedProgress
        let coreRadius = outerRadius * 0.28
        let coreIntensity = min(1.0, brightness * (0.65 + 0.85 * pow(clampedProgress, 0.5)))
        let haloIntensity = min(1.0, brightness * (0.5 + 0.7 * clampedProgress))

        return ZStack {
            RadialGradient(
                colors: [
                    Color.white.opacity(coreIntensity * 0.85),
                    config.color.opacity(haloIntensity * 0.9),
                    config.edgeColor.opacity(haloIntensity * 0.6),
                    Color.clear
                ],
                center: config.center,
                startRadius: 10,
                endRadius: max(outerRadius, 10)
            )
            .blendMode(.screen)
            .scaleEffect(x: config.stretchX, y: config.stretchY, anchor: .center)

            RadialGradient(
                colors: [
                    Color.white.opacity(min(1.0, coreIntensity * config.coreOpacity)),
                    Color.white.opacity(0)
                ],
                center: config.center,
                startRadius: 0,
                endRadius: max(coreRadius, 4)
            )
            .blendMode(.screen)
            .scaleEffect(x: config.stretchX, y: config.stretchY, anchor: .center)

            RadialGradient(
                colors: [
                    Color.white.opacity(min(1.0, coreIntensity * 1.15)),
                    Color.white.opacity(0)
                ],
                center: config.center,
                startRadius: 0,
                endRadius: max(coreRadius * 0.45, 2)
            )
            .blendMode(.screen)
            .scaleEffect(x: config.stretchX, y: config.stretchY, anchor: .center)
        }
    }
}

private extension FilmBurnSwiftUIFallback {
    static let phaseOneDuration: Double = 0.3
    static let phaseTwoDuration: Double = 0.5
    static let phaseOneFraction: Double = phaseOneDuration / (phaseOneDuration + phaseTwoDuration)

    static func smallSpots(for seed: SIMD2<Float>) -> [BurnSpotLayer.Configuration] {
        let baseColor = Color(red: 2.8, green: 1.9, blue: 0.45)
        let secondaryColor = Color(red: 2.4, green: 1.5, blue: 0.3)
        let edgeColor = Color(red: 1.7, green: 0.75, blue: 0.15)

        return [
            BurnSpotLayer.Configuration(
                center: UnitPoint(
                    x: 0.18 + Double(seed.x) * 0.2,
                    y: 0.22 + Double(seed.y) * 0.2
                ),
                baseRadius: 240,
                color: baseColor,
                edgeColor: edgeColor,
                coreOpacity: 1.0,
                stretchX: 1.6,
                stretchY: 0.8
            ),
            BurnSpotLayer.Configuration(
                center: UnitPoint(
                    x: 0.78 - Double(seed.y) * 0.25,
                    y: 0.28 + Double(seed.x) * 0.15
                ),
                baseRadius: 270,
                color: secondaryColor,
                edgeColor: edgeColor.opacity(0.85),
                coreOpacity: 1.0,
                stretchX: 1.45,
                stretchY: 0.85
            ),
            BurnSpotLayer.Configuration(
                center: UnitPoint(
                    x: 0.45 + Double(seed.y) * 0.18,
                    y: 0.62 - Double(seed.x) * 0.12
                ),
                baseRadius: 230,
                color: baseColor.opacity(0.9),
                edgeColor: edgeColor.opacity(0.75),
                coreOpacity: 1.0,
                stretchX: 1.55,
                stretchY: 0.78
            )
        ]
    }

    static func largeSpot(for seed: SIMD2<Float>) -> BurnSpotLayer.Configuration {
        BurnSpotLayer.Configuration(
            center: UnitPoint(
                x: 0.45 + Double(seed.x) * 0.1,
                y: 0.48 + Double(seed.y) * 0.1
            ),
            baseRadius: 620,
            color: Color(red: 3.2, green: 2.6, blue: 0.95),
            edgeColor: Color(red: 1.8, green: 0.8, blue: 0.15),
            coreOpacity: 1.0,
            stretchX: 1.35,
            stretchY: 0.88
        )
    }
}
