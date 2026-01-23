# OmniSlide TV — Updated Implementation Plan (Apple‑aligned)

## Key Adjustments from Apple Docs
- UserDefaults only for small settings (autoplay interval, transition type, loop)
- Image data stored in Caches directory (purgeable), not UserDefaults
- AsyncImage acceptable for display, but offline support requires a custom loader + cache
- Autoplay should be task‑scoped (cancel on view disappear)
- Use focus engine (`focusable`, `preferredFocusedView`) rather than manual focus moves

---

## Phase 0: Architecture & Structure (PRD + ARCHITECTURE)
**Goal:** Match prescribed MVVM structure and directory layout.

- [ ] Set up directory structure per `ARCHITECTURE.md`
- [ ] Wire `ContentView` → `SlideshowViewModel` → `SlideshowView`
- [ ] Ensure MVVM flow matches `ARCHITECTURE.md` data flow

---

## Phase 1: Core Slideshow + Remote Image Loading
**Goal:** Auto‑play slideshow with 20 Picsum images, 5s interval.

### 1.1 Models
- [ ] `Models/SlideItem.swift`
  - `id`, `name`, `imageURL`, `caption`
  - `Codable` only for metadata, not image bytes

### 1.2 Image Loading + Offline Cache (Apple‑aligned)
- [ ] `Services/ImageLoader.swift`
  - Custom URLSession
  - Memory cache via `NSCache<NSURL, UIImage>`
  - Disk cache via Caches directory (purgeable)
  - Offline read policy: `.returnCacheDataDontLoad`
  - Async decoding off main actor

- [ ] `Services/CacheManager.swift`
  - Manages Caches directory files
  - Eviction strategy (max size or LRU)

### 1.3 Picsum Provider
- [ ] `Services/PicsumProvider.swift`
  - Generate 20 fixed URLs: `https://picsum.photos/1920/1080?random={1..20}`

### 1.4 ViewModel
- [ ] `ViewModels/SlideshowViewModel.swift`
  - `@Published currentSlideIndex`
  - `@Published slides`
  - `@Published isPlaying`
  - `@Published selectedTransition`
  - `@Published autoplayInterval` (default 5.0)
  - Auto‑play driven by task with cancellation
  - Looping enabled by default (PRD)

### 1.5 Views
- [ ] `Views/ContentView.swift` → app entry
- [ ] `Views/SlideshowView.swift`
  - `GeometryReader`
  - `TransitionView` for animation
  - On slide change: `.sensoryFeedback(.success, trigger:)`
- [ ] `Views/SlideImageView.swift`
  - Uses `ImageLoader`
  - Placeholder + offline badge on cached load

**PRD Coverage**
- Core playback: Play/Pause/Next/Prev/Loop
- Auto‑play on launch
- High‑res images without lag

---

## Phase 2: Transition System (PRD Required 5+ Effects)
**Goal:** Implement 4 core transitions now, CoverFlow deferred to Phase 5.

- [ ] `Transitions/TransitionManager.swift`
  - Enum `TransitionType`
  - Factory returns `AnyTransition` + `Animation`

- [ ] Transition files:
  - [ ] `FadeTransition.swift`
  - [ ] `ZoomTransition.swift`
  - [ ] `SlideTransition.swift`
  - [ ] `WipeTransition.swift`
  - [ ] `CoverFlowTransition.swift` deferred to Phase 5

- [ ] `Views/TransitionView.swift`
  - Apply transition based on `selectedTransition`

**PRD Coverage**
- Fade, Zoom, Slide, Wipe
- CoverFlow flagged as Phase 5 (still required by PRD, but deferred)

---

## Phase 3: tvOS Interactions + Pause Shelf
**Goal:** Siri Remote input, pause state, thumbnail shelf.

### 3.1 Remote Input
- [ ] Short-press gesture → pause/resume
- [ ] Swipe‑left/right → next/prev (PRD)
- [ ] Press handling for D‑pad navigation

### 3.2 Pause Shelf
- [ ] `Views/PauseShelfView.swift`
  - Horizontal thumbnail list
  - Focusable items
  - Jump to selected slide
  - Remembers last focused index

### 3.3 Focus & Navigation
- [ ] Apply `focusable` to shelf items
- [ ] Use `preferredFocusedView` patterns

**PRD Coverage**
- Pause shelf with thumbnails
- D‑pad navigation overlay when paused

---

## Phase 4: Settings + UserDefaults
**Goal:** Settings UI with persistence.

- [ ] `Views/SettingsView.swift`
  - Transition picker (includes Random)
  - Autoplay interval (1–10s)
  - Loop toggle
  - Clear cache button

- [ ] `Services/SettingsManager.swift`
  - UserDefaults for settings only
  - Load at launch, save on change

**PRD Coverage**
- Transition selection (manual + Random)
- Auto‑play with specific transition
- Pause/resume usability

---

## Phase 5: Deferred Enhancements (PRD coverage completion)
- [ ] `CoverFlowTransition.swift` (PRD item 5)
- [ ] Effects folder (kenBurns, ROI zoom, pan, random effects)

---

# Full Todo List (Updated)

## Foundation
- [ ] Set up MVVM file structure per `ARCHITECTURE.md`
- [ ] Implement `SlideItem` model
- [ ] Implement `PicsumProvider` with 20 fixed URLs
- [ ] Build `ImageLoader` with NSCache + Caches directory storage
- [ ] Add `CacheManager` for disk eviction

## Slideshow Core
- [ ] Implement `SlideshowViewModel` with autoplay task + loop
- [ ] Build `SlideImageView` with placeholder/offline state
- [ ] Build `SlideshowView` with `TransitionView` integration

## Transitions
- [ ] Implement Fade, Slide, Zoom, Wipe transitions
- [ ] Add `TransitionManager` factory
- [ ] Wire `selectedTransition` into slideshow

## tvOS Controls
- [ ] Add swipe left/right gestures
- [ ] Add long‑press pause/resume
- [ ] Build `PauseShelfView` with focusable thumbnails
- [ ] D‑pad navigation for pause state

## Settings
- [ ] Add `SettingsView`
- [ ] Add `SettingsManager` (UserDefaults only)
- [ ] Hook Random transition option

## Deferred (Phase 5)
- [ ] Implement CoverFlow transition
- [ ] Add Effects subsystem (Ken Burns, ROI zoom, pan)

---

# Coverage Check (PRD + ARCHITECTURE)

- MVVM structure and file layout matches `ARCHITECTURE.md`
- Core playback, transitions, pause shelf, settings covered per `PRD.md`
- PRD mentions local assets (JPG/PNG); plan currently uses Picsum and can add local assets as a later enhancement if needed
