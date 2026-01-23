//
//  MemoriesView.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-09-05.
//

import SwiftUI

struct MemoriesView: View {
    @ObservedObject var exploreService: ExploreService
    @ObservedObject var assetService: AssetService
    @ObservedObject var authService: AuthenticationService
    @ObservedObject var userManager: UserManager
    
    @State private var assets: [ImmichAsset] = []
    @State private var exploreItems: [ExploreAsset] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedAsset: ImmichAsset?
    @State private var showingFullScreen = false
    @State private var currentAssetIndex: Int = 0
    @State private var showingStats = false
    @State private var selectedExploreItem: ExploreAsset?
    @State private var belowFold = false
    @State private var showcaseHeight: CGFloat = 0
    @State private var showcaseHighlightedItem: ExploreAsset?
    @State private var focusedItemID: String?
    @State private var navigationDirection: BackgroundImageView.NavigationDirection = .none
    @State private var previousFocusedItemID: String?
    @State private var randomizedFirstRowItems: [ExploreAsset] = []
    @AppStorage("enableMemoriesSlideshow") var enableMemoriesSlideshow = false
    
    // Computed property to get the focused explore item
    private var focusedExploreItem: ExploreAsset? {
        guard let focusedItemID = focusedItemID else {
            print("🎯 MemoriesView: No focused item ID, using first randomized item")
            return randomizedFirstRowItems.first
        }
        let item = exploreItems.first { $0.id == focusedItemID }
        print("🎯 MemoriesView: Focused item - ID: \(focusedItemID), Found: \(item?.primaryTitle ?? "nil")")
        return item
    }

    private var remainingGridItems: [ExploreAsset] {
        exploreItems.filter { item in
            randomizedFirstRowItems.contains { $0.id == item.id } == false
        }
    }

    private var isRemainingGridFocused: Bool {
        guard let focusedItemID = focusedItemID else {
            return false
        }
        return remainingGridItems.contains { $0.id == focusedItemID }
    }

    private var isFirstRowFocused: Bool {
        guard let focusedItemID = focusedItemID else {
            return false
        }
        return randomizedFirstRowItems.contains { $0.id == focusedItemID }
    }
    
    var body: some View {
        ZStack {
            // Background with gradient mask
            BackgroundImageView(
                selectedItem: focusedExploreItem ?? exploreItems.first,
                assetService: assetService,
                belowFold: belowFold,
                exploreItems: exploreItems,
                navigationDirection: navigationDirection
            )
            .onAppear {
                print("🎯 BackgroundImageView: Initial item - \((focusedExploreItem ?? exploreItems.first)?.primaryTitle ?? "nil")")
            }
            
            if isLoading {
                ProgressView("Loading explore data...")
                    .foregroundColor(.white)
                    .scaleEffect(1.5)
            } else if let errorMessage = errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    Text("Error")
                        .font(.title)
                        .foregroundColor(.white)
                    Text(errorMessage)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Retry") {
                        loadExploreData()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if exploreItems.isEmpty {
                VStack {
                    Image(systemName: "photo")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("No Places Found")
                        .font(.title)
                        .foregroundColor(.white)
                    Text("Photos with location data will appear here")
                        .foregroundColor(.gray)
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            Color.clear
                                .frame(height: 0)
                                .id("showcaseTop")
                            // Above-the-fold showcase section
                            VStack(alignment: .leading) {
                                if let displayItem = focusedExploreItem ?? exploreItems.first {
                                    HStack(alignment: .center, spacing: 40) {
                                        VStack(alignment: .leading, spacing: 20) {
                                            Spacer(minLength: 40)
                                            
                                            Text(displayItem.primaryTitle.isEmpty == true ? "Unknown City" : displayItem.primaryTitle )
                                                .font(.largeTitle)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                                .animation(.easeInOut(duration: 0.3), value: displayItem.id)
                                            
                                            Text("\(displayItem.secondaryTitle ?? "")")
                                                .font(.title2)
                                                .foregroundColor(.white.opacity(0.8))
                                            
                                            //Spacer(minLength: 20)
                                        }
                                        
                                        //Spacer()
                                    }
                                    .padding(.horizontal, 60)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .focusSection()
                            .containerRelativeFrame(.vertical, alignment: .topLeading) {
                                length, _ in length * 0.70
                            }
                            
                            //.frame(height: calculateShowcaseHeight())
                            .onScrollVisibilityChange { visible in
                                withAnimation {
                                    belowFold = !visible
                                }
                            }
                            
                            // First Row (Above the fold)
                            Text("Watch now")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                                .padding(.top, 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            ExploreFirstRow(
                                exploreItems: randomizedFirstRowItems,
                                assetService: assetService,
                                focusedItemID: $focusedItemID,
                                onItemSelected: { item in
                                    NotificationCenter.default.post(name: NSNotification.Name("stopAutoSlideshowTimer"), object: nil)
                                    selectedExploreItem = item
                                    
                                }
                            )
                            .padding(.horizontal)
                            
                            // Remaining Grid Items (Below the fold)
                            if exploreItems.count > GridConfig.peopleStyle.columns.count {
                                Text("Random Location Albums")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal)
                                    .padding(.top, 12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .opacity(belowFold ? 1 : 0)
                                    .animation(.easeInOut(duration: 0.5), value: belowFold)
                                ExploreRemainingGrid(
                                    exploreItems: remainingGridItems,
                                    assetService: assetService,
                                    focusedItemID: $focusedItemID,
                                    onItemSelected: { item in
                                        NotificationCenter.default.post(name: NSNotification.Name("stopAutoSlideshowTimer"), object: nil)
                                        selectedExploreItem = item
                                    }
                                )
                                .padding(.vertical)
                            }
                        }
                    }
                    .onChange(of: focusedItemID) { _, newValue in
                        guard newValue != nil else {
                            print("🎯 MemoriesView: Focus cleared, skipping scroll")
                            return
                        }
                        guard isFirstRowFocused else {
                            print("🎯 MemoriesView: Focus moved outside first row, no scroll")
                            return
                        }
                        print("🎯 MemoriesView: First row focused, scrolling to showcase")
                        withAnimation(.easeInOut) {
                            proxy.scrollTo("showcaseTop", anchor: .top)
                        }
                    }
                }
                //                .scrollTargetBehavior(
                //                    FoldSnappingScrollTargetBehavior(
                //                        aboveFold: !belowFold,
                //                        showcaseHeight: showcaseHeight
                //                    )
                //                )
            }
        }
        .fullScreenCover(isPresented: $showingStats) {
            //StatsView(statsService: createStatsService())
        }
        .fullScreenCover(item: $selectedExploreItem) { exploreItem in
            if enableMemoriesSlideshow {
                MemoriesSlideshowView(
                    albumId: nil,
                    personId: nil,
                    tagId: nil,
                    city: exploreItem.primaryTitle,
                    startingIndex: 0,
                    isFavorite: false
                )
            } else {
                SlideshowView(
                    albumId: nil,
                    personId: nil,
                    tagId: nil,
                    city: exploreItem.primaryTitle,
                    startingIndex: 0,
                    isFavorite: false
                )
            }
        }
        .onAppear {
            if assets.isEmpty {
                loadExploreData()
            } else if randomizedFirstRowItems.isEmpty {
                // If data is already loaded but first row items aren't randomized yet
                randomizeFirstRowItems()
            }
        }
        .onChange(of: focusedItemID) { oldValue, newValue in
            print("🎯 MemoriesView: focusedItemID changed from \(oldValue ?? "nil") to \(newValue ?? "nil")")
            print("🎯 MemoriesView: Focused in first row = \(isFirstRowFocused)")
            
            // Determine navigation direction based on index changes
            if let oldValue = oldValue, let newValue = newValue,
               let oldIndex = exploreItems.firstIndex(where: { $0.id == oldValue }),
               let newIndex = exploreItems.firstIndex(where: { $0.id == newValue }) {
                
                if newIndex > oldIndex {
                    navigationDirection = .forward
                } else if newIndex < oldIndex {
                    navigationDirection = .backward
                } else {
                    navigationDirection = .none
                }
            } else {
                navigationDirection = .none
            }
            
            if let newValue = newValue, let item = exploreItems.first(where: { $0.id == newValue }) {
                print("🎯 MemoriesView: Above-the-fold should update to: \(item.primaryTitle), direction: \(navigationDirection)")
            }
            
            previousFocusedItemID = oldValue
        }
        .onChange(of: isRemainingGridFocused) { _, newValue in
            print("🎯 MemoriesView: Remaining grid focus state = \(newValue)")
        }
    }
    
    private func loadExploreData() {
        guard authService.isAuthenticated else {
            errorMessage = "Not authenticated. Please check your credentials."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let result = try await exploreService.fetchExploreData()
                await MainActor.run {
                    self.assets = result
                    self.exploreItems = result.map { ExploreAsset(asset: $0) }
                    self.isLoading = false
                    self.randomizeFirstRowItems()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    //    private func calculateShowcaseHeight() -> CGFloat {
    //        let screenHeight = UIScreen.main.bounds.height
    //        let screenWidth = UIScreen.main.bounds.width
    //
    //        // Detect 4K vs 1080p based on screen dimensions
    //        if screenHeight >= 2160 || screenWidth >= 3840 {
    //            // 4K Apple TV
    //            let height: CGFloat = 1600
    //            showcaseHeight = height
    //            return height
    //        } else {
    //            // 1080p Apple TV
    //            let height: CGFloat = 800
    //            showcaseHeight = height
    //            return height
    //        }
    //    }
    
    private func randomizeFirstRowItems() {
        let columnsCount = GridConfig.peopleStyle.columns.count
        if exploreItems.count > columnsCount {
            randomizedFirstRowItems = Array(exploreItems.shuffled().prefix(columnsCount))
        } else {
            randomizedFirstRowItems = exploreItems
        }
        print("🎯 MemoriesView: Randomized first row items: \(randomizedFirstRowItems.map { $0.primaryTitle })")
    }
    
}

#Preview {
    let (networkService, userManager, authService, assetService, _, _, _, _) =
        MockServiceFactory.createMockServices()
    let exploreService = ExploreService(networkService: networkService)

    MemoriesView(
        exploreService: exploreService,
        assetService: assetService,
        authService: authService,
        userManager: userManager
    )
}
