# OmniSlide TV TODO

## Phase 0: Architecture & Structure
- [x] Set up MVVM file structure per `ARCHITECTURE.md`
- [x] Wire `ContentView` → `SlideshowViewModel` → `SlideshowView`
- [x] Ensure MVVM flow matches `ARCHITECTURE.md` data flow

## Phase 1: Core Slideshow + Remote Image Loading
- [x] Implement `Models/SlideItem.swift`
- [x] Implement `Services/PicsumProvider.swift` with 20 fixed URLs
- [x] Build `Services/ImageLoader.swift` with NSCache + Caches directory storage
- [x] Add `Services/CacheManager.swift` for disk eviction
- [x] Implement `ViewModels/SlideshowViewModel.swift` with autoplay task + loop
- [x] Build `Views/SlideImageView.swift` with placeholder/offline state
- [x] Build `Views/SlideshowView.swift` with `TransitionView` integration

## Phase 2: Transition System
- [x] Implement Fade, Slide, Zoom, Wipe transitions
- [x] Add `TransitionManager` factory
- [x] Wire `selectedTransition` into slideshow

## Phase 3: tvOS Controls
- [x] Add swipe left/right gestures
- [x] Add pause/resume control to slideshow.
- [ ] Research TVCatalog horizontal Shelf (read apple documentation using @Perplexity and Apple-docs mcp)
- [x] Build `PauseShelfView` with focusable thumbnails using TVCatalog horizontal Shelf
- [x] Add settings button to pause state
- [x] Add vertical blurred background tvOS 26 glass behind PauseShelfView
- [x] Fade in Pause shelf when paused
- [x] Fade out Pause shelf when resumed after 3 seconds
- [x] Add D‑pad navigation for pause state

## Phase 4: Settings
- [ ] Add `SettingsView`
- [ ] Add `SettingsManager` (UserDefaults only)
- [ ] Hook Random transition option

## Phase 5: Deferred
- [ ] Implement CoverFlow transition
- [ ] Add Effects subsystem (Ken Burns, ROI zoom, pan)
