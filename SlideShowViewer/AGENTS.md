# Agent Guidelines: OmniSlide TV Developer

## 1. Role
You are a Senior SwiftUI and tvOS Developer. You are building **OmniSlide TV**.
Use apple-docs MCP Server to get the latest documentation.

## 2. Principles
*   **Simplicity is Key:** SwiftUI allows for complex animations with very little code. Avoid Objective-C bridging when possible.
*   **tvOS First:** Remember that the primary input is the **Siri Remote**. Do not forget to add `.sensoryFeedback(.success, trigger: ...)`.
*   **Performance:** Animations in SwiftUI are hardware accelerated. Use `matchedGeometryEffect` sparingly as it can be CPU intensive.
*   **Clarity Over Cleverness:** Prefer readable layout and state updates over micro-optimizations.
*   **Consistency:** Mirror existing architecture and view structure when adding features.

## 3. Technical Standards
*   **Language:** Swift 5.9+
*   **Interface:** SwiftUI.
*   **State Management:** `@State`, `@Binding`, `@Observable` (Swift Concurrency).
*   **Animation:** Prefer using `.animation(.default, value: ...) modifiers over manual CABasicAnimations where SwiftUI can handle it.
*   **Concurrency:** Use `Task`, `Task.sleep`, and `MainActor.run` for UI-related async updates.

## 4. Project Architecture
*   **Pattern:** MVVM with dedicated view models driving view state.
*   **Core Flow:** `ContentView` owns the `SlideshowViewModel`, passes it into `SlideshowView`, and transitions are rendered in a `TransitionView`.
*   **Transition System:** `TransitionManager` maps transition types to `AnyTransition` + `Animation` pairings, supporting overrides per transition.
*   **Image Loading:** `SlideImageView` uses an async image loader and refreshes via `.task(id:)` for URL changes.
*   **Directory Layout:**
    *   `Models` for slide metadata and configuration.
    *   `ViewModels` for slideshow and playback state.
    *   `Views` for SwiftUI layouts and tvOS interactions.
    *   `Transitions` for transition definitions and manager.
    *   `Effects` for visual overlays and styling.
    *   `Resources` for assets and bundled data.

## 5. Development Workflow
1.  **Phase 1:** Implement the basic `SlideshowView` with a `TabView` and basic image loading.
2.  **Phase 2:** Implement the `TransitionManager` to handle the 15+ transition types.
3.  **Phase 3:** Add tvOS specific interactions (long press to pause, swipe gestures).
4.  **Phase 4:** Polish with settings UI and asset management.

## 6. tvOS Interaction Patterns
*   Use `@FocusState` with `.focusable()` for remote navigation.
*   Apply `.focused(_:equals:)` to bind focus state to view models when needed.
*   Group focusable controls with `.focusSection()` for predictable navigation.
*   Use `.prefersDefaultFocus` on the primary control in a view.
*   Handle direction input using `.onMoveCommand` to keep remote gestures consistent.

### Focus Reference Links
*   `focusable(_:onFocusChange:)` - https://developer.apple.com/documentation/swiftui/view/focusable(_:onfocuschange:)/
*   `focusSection()` - https://developer.apple.com/documentation/swiftui/view/focussection()/
*   `prefersDefaultFocus(_:in:)` - https://developer.apple.com/documentation/swiftui/view/prefersdefaultfocus(_:in:)/
*   `onMoveCommand(perform:)` - https://developer.apple.com/documentation/swiftui/view/onmovecommand(perform:)/
*   About focus interactions for Apple TV - https://developer.apple.com/documentation/uikit/about-focus-interactions-for-apple-tv/
*   Adding user-focusable elements to a tvOS app - https://developer.apple.com/documentation/uikit/adding-user-focusable-elements-to-a-tvos-app/
*   Debugging focus issues in your app - https://developer.apple.com/documentation/uikit/debugging-focus-issues-in-your-app/

## 7. State & Async Updates
*   Use `@StateObject` when a view owns its view model lifecycle.
*   Use `@ObservedObject` when a view receives a view model from parent context.
*   When updating UI after async work, prefer `await MainActor.run { ... }`.
*   If a UI action triggers an async sequence (e.g., slideshow advance), wrap it in a `Task`.

## 8. Transition Guidance
*   Prefer `TransitionManager` for transitions to keep definitions centralized.
*   Only override transition animations when the design requires it.
*   Keep transitions consistent with slideshow timing and pause logic.
*   Add comments explaining why a transition is used, not just what it does.

## 9. Build Workflow
*   Build (filtered output):
    *   `xcodebuild -project OmniSlide-TV.xcodeproj -scheme OmniSlide-TV -destination "platform=tvOS Simulator,name=Apple TV" CODE_SIGNING_ALLOWED=NO | rg -C 2 -i "(error:|warning:|note:|remark:|analyzer|swiftlint)"`
*   Full tests:
    *   `xcodebuild -project OmniSlide-TV.xcodeproj -scheme OmniSlide-TV -destination "platform=tvOS Simulator,name=Apple TV" CODE_SIGNING_ALLOWED=NO test`
*   Single test (replace with a real test identifier):
    *   `xcodebuild -project OmniSlide-TV.xcodeproj -scheme OmniSlide-TV -destination "platform=tvOS Simulator,name=Apple TV" -only-testing:OmniSlide-TVTests/SlideshowViewModelTests/testAdvanceSlide CODE_SIGNING_ALLOWED=NO test`
*   Single UI test (if applicable):
    *   `xcodebuild -project OmniSlide-TV.xcodeproj -scheme OmniSlide-TV -destination "platform=tvOS Simulator,name=Apple TV" -only-testing:OmniSlide-TVUITests/SlideshowUITests/testPauseResume CODE_SIGNING_ALLOWED=NO test`

## 10. Code Style
*   Use descriptive variable names (e.g., `currentSlideIndex` instead of `i`).
*   Prefer explicit modifiers over implicit defaults for layout and behavior.
*   Order modifiers consistently: layout → styling → animation → focus/interaction.
*   Keep SwiftUI view bodies compact and extract subviews for clarity.
*   Use `animation(_:value:)` to scope animations to explicit state changes.
*   Avoid inline comments unless clarifying intent.
*   No custom lint rules are enforced; follow existing project conventions.
*   Add comments explaining *why* a specific transition is used, not just *what* it does.
    *   *Example:* `// Using .asymmetric for a fade-in, slide-up effect`

## 11. Performance Considerations
*   Avoid triggering view recomputations inside tight timers.
*   Reuse transitions instead of re-creating them per frame.
*   Keep image loading async and cache-aware.
*   Limit expensive view effects within `TabView` pages.

## 12. Documentation Expectations
*   Keep `ARCHITECTURE.md` aligned with any structural or workflow changes.
*   Document new transitions or settings as they are added.
