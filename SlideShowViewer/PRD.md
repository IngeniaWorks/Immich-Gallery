# Product Requirements Document: Apple TVOS SwiftUI Slideshow

## 1. Executive Summary
**Project Name:** OmniSlide TV
**Version:** 1.0
**Platform:** tvOS (tvOS 16+)
**Language:** Swift
**Framework:** SwiftUI

**OmniSlide TV** is a high-performance, immersive slideshow application designed specifically for the Apple TV. It moves beyond standard image viewers by offering a comprehensive suite of transition effects and animations that leverage the unique capabilities of tvOS (Siri Remote, focus management, and animations).

## 2. Problem Statement
Existing slideshow apps on tvOS often feel clunky, lack visual flair, or fail to take advantage of SwiftUI's declarative animation capabilities. Users want a slideshow that feels like a premium media experience, with smooth, hardware-accelerated transitions and intuitive navigation using the Siri Remote.

## 3. Goals & Objectives
*   **Goal 1:** Create a performant slideshow engine using SwiftUI.
*   **Goal 2:** Implement a robust transition system supporting 5+ distinct visual effects.
*   **Goal 3:** Ensure native tvOS feel (Siri Remote gestures, focus interactions).
*   **Goal 4:** Support local image assets (JPG, PNG).

## 4. User Stories
1.  As a user, I want to swipe left/right to navigate slides.
2.  As a user, I want to pinch to zoom into the current image.
3.  As a user, I want to select different transition effects from a settings menu.
4.  As a user, I want the slideshow to auto-play with a specific transition.
5.  As a user, I want to view high-resolution images without lag.

## 5. Functional Requirements
*   **Core Playback:** Play, Pause, Next, Previous, and Loop.
*   **Transitions:** Support for the following effects:
    1.  Fade (Crossfade)
    2.  Zoom (In/Out)
    3.  Slide (Left/Right)
    4.  Wipe (Top/Bottom/Left/Right)
    5.  CoverFlow (3D Horizontal)
*   **Controls:** On pause show On-screen D-Pad for navigation and PauseShelfView with horizontal scrollable list of image thumbnails.
*   **Settings:** Ability to cycle through transitions manually or set to "Random".

## 6. Non-Functional Requirements
*   **Performance:** Must maintain 60 FPS on the Apple TV (M-series chip).
*   **Usability:** Must support pause/resume.
*   **Compatibility:** Minimum deployment target tvOS 16.0.

---