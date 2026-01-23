import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = SlideshowViewModel()

    var body: some View {
        SlideshowView(viewModel: viewModel)
    }
}
