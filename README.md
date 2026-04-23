# Tooltip Tour — iOS SDK

Native Swift/SwiftUI SDK for [Tooltip Tour](https://app.lovelysomething.com) — the guided walkthrough tool for web, iOS, Android, and React Native.

---

## Installation

### Swift Package Manager (recommended)

In Xcode, go to **File → Add Package Dependencies** and paste:

```
https://github.com/lovelysomething/tooltip-tour-ios
```

Select **Up to Next Major Version** and click **Add Package**.

Or add it directly to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/lovelysomething/tooltip-tour-ios", from: "1.0.0"),
],
targets: [
    .target(name: "YourApp", dependencies: ["TooltipTour"]),
]
```

---

## Setup

### 1. Configure the SDK

Call `configure` once at app startup — in your `@main` App struct or `AppDelegate`:

```swift
import TooltipTour

@main
struct MyApp: App {
    init() {
        TooltipTour.shared.configure(siteKey: "sk_your_key")

        // Optional: prefetch all tour configs at startup for instant first load
        Task { await TooltipTour.shared.prefetchAll() }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### 2. Add the launcher to each screen

Wrap your screen content in a `ZStack`, register the screen with `.ttPage()`, and add `TTLauncherView()`:

```swift
import TooltipTour

struct HomeView: View {
    var body: some View {
        ZStack {
            // Your screen content here
            YourContent()

            // Launcher overlay — shows welcome card / FAB automatically
            TTLauncherView()
        }
        .ttPage("home")   // registers this screen with the SDK
    }
}
```

### 3. Tag targetable elements

Add `.ttTarget("identifier")` to any element you want the tour to highlight:

```swift
Button("Get started") { /* … */ }
    .ttTarget("get-started")
```

The identifier must match the **selector** set in the Tooltip Tour dashboard.

---

## Scrollable lists

To let the SDK scroll a `ScrollView` to a target element, add `.ttScrollable()` to the scroll content:

```swift
ScrollView {
    VStack {
        ForEach(items) { item in
            Row(item: item)
                .ttTarget(item.id)
        }
    }
    .ttScrollable()
}
```

---

## Visual Inspector

The Visual Inspector lets you capture element identifiers directly from your device and send them to the dashboard without leaving the app.

### Enable deep link handling

In your `@main` App struct:

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    TooltipTour.shared.handleDeepLink(url)
                }
        }
    }
}
```

### Register the URL scheme

In `Info.plist`, add a URL type with the scheme `tooltiptour`. Or add to your `Info.plist` directly:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>tooltiptour</string>
        </array>
    </dict>
</array>
```

The dashboard will generate a QR code you scan with your device to launch the inspector.

The inspector has two modes:

- **Navigate** — touches pass through to your app; scroll and explore freely
- **Highlight** — blue chips appear over every registered `.ttTarget()` view; tap a chip to capture its identifier

---

## Requirements

- iOS 15.0+
- SwiftUI (UIKit apps are also supported — see below)

---

## UIKit support

For apps using UIKit, call `TooltipTour.shared.handleDeepLink(_:)` from `application(_:open:options:)` in your `AppDelegate`:

```swift
func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    TooltipTour.shared.handleDeepLink(url)
    return true
}
```

For mixed UIKit/SwiftUI apps, `.ttPage()` and `.ttTarget()` work inside any SwiftUI view regardless of how it's hosted.

---

## Other SDKs

- [tooltip-tour-android](https://github.com/lovelysomething/tooltip-tour-android) — Kotlin/Jetpack Compose
- [tooltip-tour-react-native](https://github.com/lovelysomething/tooltip-tour-react-native) — Pure JS, Expo-compatible

---

## License

MIT © Lovely Something Ltd
