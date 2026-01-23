import SwiftUI

struct TransitionView<Content: View>: View {
    private let content: Content
    private let transition: AnyTransition
    private let animation: Animation
    private let trigger: Int

    init(
        transition: AnyTransition,
        animation: Animation,
        trigger: Int,
        @ViewBuilder content: () -> Content
    ) {
        self.transition = transition
        self.animation = animation
        self.trigger = trigger
        self.content = content()
    }

    var body: some View {
        ZStack {
            content
                .id(trigger)
                .transition(transition)
        }
        .animation(animation, value: trigger)
    }
}
