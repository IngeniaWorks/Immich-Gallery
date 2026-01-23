import SwiftUI

struct PortraitView<Foreground: View>: View {
    private let foreground: Foreground

    init(
        @ViewBuilder foreground: () -> Foreground
    ) {
        self.foreground = foreground()
    }

    var body: some View {
        ZStack {
            foreground
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .ignoresSafeArea()
                .zIndex(0)
            Rectangle()
                .background(.thickMaterial)
                .ignoresSafeArea()
                .zIndex(1)

            foreground
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .zIndex(2)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
        }
    }
}
