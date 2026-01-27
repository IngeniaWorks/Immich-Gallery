import SwiftUI
import AVKit

struct MemoriesSlideshowView: View {
    let albumId: String?
    let personId: String?
    let tagId: String?
    let city: String?
    let startingIndex: Int
    let isFavorite: Bool
    @Environment(\.dismiss) private var dismiss

    private let assetService: AssetService
    private let albumService: AlbumService?
    private let networkService: NetworkService

    @State private var viewState: ViewState = .loading
    @State private var loadAssetsTask: Task<Void, Never>?

    enum ViewState {
        case loading
        case ready(assets: [ImmichAsset])
        case error(String)
        case empty
    }

    init(albumId: String? = nil, personId: String? = nil, tagId: String? = nil, city: String? = nil, startingIndex: Int = 0, isFavorite: Bool = false) {
        self.albumId = albumId
        self.personId = personId
        self.tagId = tagId
        self.city = city
        self.startingIndex = startingIndex
        self.isFavorite = isFavorite

        let userManager = UserManager()
        let networkService = NetworkService(userManager: userManager)
        self.networkService = networkService
        self.assetService = AssetService(networkService: networkService)
        self.albumService = AlbumService(networkService: networkService)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch viewState {
            case .loading:
                ProgressView("Loading Slideshow...")
                    .foregroundColor(.white)
            case .ready(let assets):
                OmniSlideshowView(
                    viewModel: SlideshowViewModel(
                        assets: assets,
                        networkService: networkService,
                        startingIndex: startingIndex
                    ),
                    networkService: networkService
                )
            case .error(let message):
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    Text(message)
                        .foregroundColor(.white)
                    Button("Close") { dismiss() }
                }
            case .empty:
                VStack(spacing: 20) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No items to display")
                        .foregroundColor(.white)
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear {
            initializeSlideshow()
        }
        .onDisappear {
            loadAssetsTask?.cancel()
        }
    }

    private func initializeSlideshow() {
        loadAssetsTask?.cancel()
        loadAssetsTask = Task {
            do {
                let assets = try await fetchAssets()
                await MainActor.run {
                    if assets.isEmpty {
                        self.viewState = .empty
                    } else {
                        self.viewState = .ready(assets: assets)
                    }
                }
            } catch {
                await MainActor.run {
                    self.viewState = .error(error.localizedDescription)
                }
            }
        }
    }

    private func fetchAssets() async throws -> [ImmichAsset] {
        let assetProvider = AssetProviderFactory.createProvider(
            albumId: albumId,
            personId: personId,
            tagId: tagId,
            city: city,
            isAllPhotos: false,
            isFavorite: isFavorite,
            assetService: assetService,
            albumService: albumService
        )

        // Load a good chunk of assets for the slideshow
        let result = try await assetProvider.fetchAssets(page: 1, limit: 500)
        
        // Filter for images and videos
        return result.assets.filter { $0.type == .image || $0.type == .video }
    }
}
