# Architecture Document: OmniSlide TV

## 1. System Overview
The application follows the **MVVM (Model-View-ViewModel)** pattern, which is native to SwiftUI. This ensures that the UI updates reactively to data changes.

## 2. Directory Structure
```
OmniSlideTV/
├── Models/
│   └── SlideItem.swift (Data model for media)
├── ViewModels/
│   └── SlideshowViewModel.swift (ViewModel for slideshow logic)
├── Views/
│   ├── ContentView.swift (Main entry point)
│   ├── SlideshowView.swift (The main player)
│   ├── PauseShelfView.swift (Pause shelf view)
│   ├── TransitionView.swift (Container for transitions)
│   ├── PortraitView.swift (Portrait media background/foreground layout)
│   ├── SlideImageView.swift (Image rendering)
│   ├── SlideVideoView.swift (Video rendering)
│   └── SettingsView.swift (Configuration)
├── Transitions/
│   ├── TransitionManager.swift (Factory pattern)
│   ├── FadeTransition.swift
│   ├── ZoomTransition.swift
│   ├── CubeTransition.swift (Do not implement yet)
│   ├── SlideTransition.swift
│   ├── FlipTransition.swift
│   ├── WipeTransition.swift
│   ├── CoverFlowTransition.swift
│   ├── FadeThroughTransition.swift
│   └── SlideLeftRightTransition.swift
├── Effects /
│   ├── kenBurns.swift 
│   ├── ROIZoom.swift (Zoom to region of interest)
│   ├── Pan.swift (Pan to region of interest)
│   ├── Placeholder.swift 
│   └── randomEffect.swift
├── Resources/
│   └── Assets.xcassets
└── OmniSlideTVApp.swift
```

## 3. Data Flow
1.  `ContentView` initializes the `SlideshowViewModel`.
2.  `SlideshowViewModel` holds the `@Published` state for the current slide index and transition type.
3.  `SlideshowView` observes the ViewModel.
4.  When the user swipes, the ViewModel updates the index.
5.  `TransitionView` receives the new index and applies the specific `AnyTransition` or `Animation` based on the selected effect.

## 4. Key Components

### 4.1 Models (`Models/SlideItem.swift`)
*   **Purpose:** Simple data container.
*   **Properties:** `id` (UUID), `name` (String), `mediaURL` (URL), `caption` (String), `mediaType` (image/video), `orientation` (portrait/landscape).

### 4.2 View Logic (`Views/SlideshowView.swift`)
*   **Purpose:** The main container.
*   **Logic:** Manages the `GeometryReader` to handle aspect ratios and `TabView` or `ZStack` for stacking slides.

### 4.3 Transition System (`Transitions/TransitionManager.swift`)
*   **Purpose:** Centralized logic to return the correct `AnyTransition` or `Namespace.ID` for SwiftUI animations.
*   **Mechanism:** A switch statement returning specific transition modifiers based on an enum `TransitionType`.

### 4.4 Asset Management
*   Images will be loaded from the App Bundle or a local file directory using `UIImage(named:)` or `Image` resources.

### 4.5 tvOS Focus & Input
*   Use `@FocusState` and `.focusable()` for Siri Remote navigation.
*   Group shelf controls with `.focusSection()` and use `.prefersDefaultFocus` for the primary action.
*   Handle direction input with `.onMoveCommand(perform:)` to keep navigation consistent.
*   Reference links:
    *   https://developer.apple.com/documentation/swiftui/view/focusable(_:onfocuschange:)/
    *   https://developer.apple.com/documentation/swiftui/view/focussection()/
    *   https://developer.apple.com/documentation/swiftui/view/prefersdefaultfocus(_:in:)/
    *   https://developer.apple.com/documentation/swiftui/view/onmovecommand(perform:)/
    *   https://developer.apple.com/documentation/uikit/about-focus-interactions-for-apple-tv/
    *   https://developer.apple.com/documentation/uikit/adding-user-focusable-elements-to-a-tvos-app/
    *   https://developer.apple.com/documentation/uikit/debugging-focus-issues-in-your-app/

### 4.6 Media Layout
*   Portrait media uses `PortraitView` to render a blurred `.fill` background with a centered `.fit` foreground.
*   Landscape media uses a full-bleed `.fill` presentation.

---

