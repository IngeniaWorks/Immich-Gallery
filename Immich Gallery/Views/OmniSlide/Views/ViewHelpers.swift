import SwiftUI

struct PortraitView<Foreground: View>: View {
    private let foreground: Foreground

    init(@ViewBuilder foreground: () -> Foreground) {
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
                .fill(.thickMaterial)
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

struct LoadingView: View {
    let label: String?

    var body: some View {
        HStack(spacing: 12) {
            SpinnerView()
            if let label {
                Text(label)
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.35))
        )
    }
}

private struct SpinnerView: View {
    @State private var isAnimating = false

    var body: some View {
        Circle()
            .trim(from: 0.2, to: 1.0)
            .stroke(Color.white.opacity(0.85), lineWidth: 3)
            .frame(width: 22, height: 22)
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: isAnimating)
            .onAppear {
                isAnimating = true
            }
    }
}
