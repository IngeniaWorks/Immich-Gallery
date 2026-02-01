import SwiftUI

enum TransitionPhase {
    case entering
    case idle
    case exiting
}

enum OverlaySplitTransitionTiming {
    static let enterExitDuration: TimeInterval = 0.6
}

struct OverlaySplitTransitionView<LeftContent: View, RightContent: View, BackgroundContent: View, RevealContent: View>: View {
    let trigger: Int
    let leftContent: () -> LeftContent
    let rightContent: () -> RightContent
    let backgroundContent: () -> BackgroundContent
    let revealContent: () -> RevealContent
    var onReveal: (() -> Void)? = nil

    var duration: TimeInterval
    var idleDurationOverride: TimeInterval
    var debugEnabled: Bool = false

    private var enterExitDuration: TimeInterval {
        max(duration * 0.5, OverlaySplitTransitionTiming.enterExitDuration)
    }
    private var idleDuration: TimeInterval {
        max(idleDurationOverride, 0.1)
    }

    @State private var currentPhase: TransitionPhase = .entering
    @State private var leftScale: CGFloat = 1.0
    @State private var rightScale: CGFloat = 1.0
    @State private var leftMovesFromTop: Bool = Bool.random()
    @State private var idleOffsetTop: CGFloat = 0
    @State private var idleOffsetBottom: CGFloat = 0
    @State private var revealOpacity: Double = 0.0
    @State private var animationTask: Task<Void, Never>?

    init(
        trigger: Int,
        duration: TimeInterval,
        idleDurationOverride: TimeInterval,
        debugEnabled: Bool = false,
        onReveal: (() -> Void)? = nil,
        @ViewBuilder leftContent: @escaping () -> LeftContent,
        @ViewBuilder rightContent: @escaping () -> RightContent,
        @ViewBuilder backgroundContent: @escaping () -> BackgroundContent,
        @ViewBuilder revealContent: @escaping () -> RevealContent
    ) {
        self.trigger = trigger
        self.duration = duration
        self.idleDurationOverride = idleDurationOverride
        self.debugEnabled = debugEnabled
        self.onReveal = onReveal
        self.leftContent = leftContent
        self.rightContent = rightContent
        self.backgroundContent = backgroundContent
        self.revealContent = revealContent
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                backgroundContent()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .opacity(1 - revealOpacity)

                revealContent()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .opacity(revealOpacity)

                HStack(spacing: 0) {
                    splitContent(isLeft: true, size: proxy.size)

                    Rectangle()
                        .fill(Color.black)
                        .frame(width: dividerWidth, height: proxy.size.height)

                    splitContent(isLeft: false, size: proxy.size)
                }
            }
        }
        .onAppear {
            debug("🐢 [OVERLAY] onAppear")
            startAnimationSequence()
            startKenBurns()
        }
        .onChange(of: trigger) { _ in
            debug("🐢 [OVERLAY] onChange(trigger) - trigger: \(trigger)")
            animationTask?.cancel()
            currentPhase = .entering
            leftMovesFromTop = Bool.random()
            idleOffsetTop = 0
            idleOffsetBottom = 0
            revealOpacity = 0
            startAnimationSequence()
        }
        .onDisappear {
            animationTask?.cancel()
        }
    }

    private func splitContent(isLeft: Bool, size: CGSize) -> some View {
        let width = size.width / 2
        let borderWidth = width

        let imageView = Group {
            if isLeft {
                leftContent()
            } else {
                rightContent()
            }
        }
        .scaleEffect(isLeft ? leftScale : rightScale)
        .frame(width: width, height: size.height)
        .clipped()
        .offset(y: verticalOffset(isLeft: isLeft, height: size.height))

        let topBorder = Color.black
            .frame(width: borderWidth, height: borderHeight)
            .offset(y: -size.height / 2 + borderHeight / 2 + verticalOffset(isLeft: isLeft, height: size.height) + idleOffsetTop)

        let bottomBorder = Color.black
            .frame(width: borderWidth, height: borderHeight)
            .offset(y: size.height / 2 - borderHeight / 2 + verticalOffset(isLeft: isLeft, height: size.height) + idleOffsetBottom)

        return ZStack {
            imageView
            topBorder
            bottomBorder
        }
    }

    private func startAnimationSequence() {
        debug("🐢 [OVERLAY] startAnimationSequence() called")
        debug("🐢 [OVERLAY]   idle duration: \(idleDuration)s")
        debug("🐢 [OVERLAY]   enter/exit duration: \(enterExitDuration)s")

        animationTask?.cancel()
        animationTask = Task { @MainActor in
            currentPhase = .entering
            idleOffsetTop = 0
            idleOffsetBottom = 0
            revealOpacity = 0

            withAnimation(.easeInOut(duration: enterExitDuration)) {
                currentPhase = .idle
                idleOffsetTop = -borderHeight
                idleOffsetBottom = borderHeight
            }

            try? await Task.sleep(nanoseconds: UInt64(enterExitDuration * 1_000_000_000))
            guard !Task.isCancelled else { return }

            if idleDuration > 0 {
                try? await Task.sleep(nanoseconds: UInt64(idleDuration * 1_000_000_000))
            }

            guard !Task.isCancelled else { return }

            withAnimation(.easeInOut(duration: enterExitDuration)) {
                currentPhase = .exiting
                idleOffsetTop = 0
                idleOffsetBottom = 0
                revealOpacity = 1
            }

            try? await Task.sleep(nanoseconds: UInt64(enterExitDuration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            onReveal?()
        }
    }

    private func startKenBurns() {
        withAnimation(.easeInOut(duration: idleDuration + 5.0).repeatForever(autoreverses: true)) {
            leftScale = 1.05
            rightScale = 1.05
        }
    }

    private var dividerWidth: CGFloat {
        switch currentPhase {
        case .entering: return 0
        case .idle: return 12
        case .exiting: return 0
        }
    }

    private var borderHeight: CGFloat { 12 }

    private func verticalOffset(isLeft: Bool, height: CGFloat) -> CGFloat {
        let direction: CGFloat = leftMovesFromTop ? 1 : -1
        let sideMultiplier: CGFloat = isLeft ? 1 : -1

        switch currentPhase {
        case .entering:
            return height * direction * sideMultiplier * -1
        case .idle:
            return 0
        case .exiting:
            return height * direction * sideMultiplier * 1.0
        }
    }

    private func debug(_ message: String) {
        guard debugEnabled else { return }
        print(message)
    }
}
