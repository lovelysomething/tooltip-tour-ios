# Tooltip Tour — iOS Swift SDK

## What this is

Native iOS SDK for Tooltip Tour. Integrates with a customer's iOS app to display guided walkthroughs fetched from the Tooltip Tour dashboard. Renders as a UIKit overlay window on top of the host app — zero changes to the app's own view hierarchy required.

---

## Package

- **Swift Package Manager** (SPM)
- **Minimum deployment**: iOS 15
- **Swift Tools Version**: 5.9
- **Library target**: `TooltipTour`

Add to Xcode via: File → Add Package Dependencies → paste repo URL.

---

## Quick start

```swift
// AppDelegate or @main App struct
TooltipTour.configure(siteKey: "YOUR_SITE_KEY", baseURL: "https://app.lovelysomething.com")
```

Targeting elements:

```swift
// SwiftUI — use the .ttTarget() modifier
Text("Welcome").ttTarget("welcome-title")

// UIKit — use accessibilityIdentifier
loginButton.accessibilityIdentifier = "loginButton"
```

---

## Repo layout

```
Sources/TooltipTour/
  TooltipTour.swift             Main entry point — @MainActor singleton, configure()
  TTViewRegistry.swift          .ttTarget() SwiftUI modifier; stores CGRect per ID
  Models/
    TTModels.swift              All data models: TTConfig, TTStep, TTStyles, TTFabStyle, etc.
  Networking/
    TTNetworkClient.swift       Fetches /api/walkthrough/{siteKey} from the dashboard API
    TTEventTracker.swift        Sends usage events back to the API
  Session/
    TTWalkthroughSession.swift  Session lifecycle — starts/stops tour, manages beacons + spotlight
  UI/
    TTLauncherView.swift        FAB launcher: 6 positions, mini tab, welcome card, X dismiss
    TTBeaconView.swift          Numbered / dot / ring beacon with sonar-ping animation
    TTSpotlightView.swift       Dimmed overlay with cutout highlight around target view
    TTStepCardView.swift        Step content card (title, body, prev/next buttons)
    TTWelcomeCardView.swift     Welcome screen (emoji, title, message, CTA, don't show again)
Tests/TooltipTourTests/
  TooltipTourTests.swift
```

---

## Architecture

### Overlay window
All SDK UI runs inside `TTOverlayWindow`, a `UIWindow` subclass that floats above the host app's key window. It is excluded from the responder/view hierarchy search so it doesn't intercept the host app's touches except where intentional.

### View targeting
Two mechanisms:
1. **SwiftUI**: `.ttTarget("id")` modifier → `TTViewRegistry` stores the view's `CGRect` in screen coordinates
2. **UIKit**: `view.accessibilityIdentifier = "id"` → SDK traverses the UIView tree to find and measure the view

### Styles
`TTStyles` is a nested struct (`fab`, `card`, `type`, `btn`, `beacon`) decoded from the same JSON shape served by the dashboard API and consumed by the web `embed.js`. All colour helpers live on `TTStyles` (`resolvedFabBgColor`, `resolvedBeaconBgColor`, etc.) — UI files never parse hex directly.

### Beacon animations
Sonar-ping: border-only `CALayer` ring, scale `1 → 1.7`, opacity `0.6 → 0`, 1.8s ease-out infinite. Matches the web embed animation exactly. `clipsToBounds = false` on the host view so the ring extends beyond bounds.

### Launcher state
`TTLauncherState` persists minimised/dismissed state and "don't show again" via `UserDefaults`. Supports 6 positions: `bottom-left` (default), `bottom-right`, `bottom-center`, `top-left`, `top-right`. (`top-center` is intentionally disabled in the dashboard for iOS sites.)

---

## Conventions

- **`@MainActor`** on all UI and session classes — never dispatch UI updates off the main actor
- **`CodingKeys`** use `snake_case` to match API JSON (`bg_color`, `border_radius`, `bg_opacity`, etc.)
- **UIKit / SwiftUI boundary** — keep them separate; don't import UIKit in SwiftUI-only files
- **Colour resolution** — always go through `TTStyles` helpers, never parse hex inline in views
- **No force unwraps** in UI code — use `guard let` / `if let` with graceful fallbacks
