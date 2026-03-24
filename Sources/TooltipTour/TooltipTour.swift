import UIKit

/// Main entry point for the Tooltip Tour iOS SDK.
///
/// Setup (AppDelegate or @main):
/// ```swift
/// TooltipTour.shared.configure(siteKey: "sk_your_key")
/// ```
///
/// Add the launcher to your root SwiftUI view:
/// ```swift
/// ZStack {
///     ContentView()
///     TTLauncherView()
/// }
/// ```
@MainActor
public final class TooltipTour {

    public static let shared = TooltipTour()

    private var siteKey: String = ""
    private var baseURL: String = "https://app.lovelysomething.com"
    private var networkClient: TTNetworkClient?
    private var tracker: TTEventTracker?
    private var activeSession: TTWalkthroughSession?

    private init() {}

    /// Configure the SDK. Call once at app startup.
    /// - Parameters:
    ///   - siteKey: Your site key from the Tooltip Tour dashboard.
    ///   - baseURL: Override the API base URL (optional, for self-hosted).
    public func configure(siteKey: String, baseURL: String = "https://app.lovelysomething.com") {
        self.siteKey      = siteKey
        self.baseURL      = baseURL
        self.networkClient = TTNetworkClient(baseURL: baseURL)
        self.tracker       = TTEventTracker(baseURL: baseURL)
    }

    /// Fetch the walkthrough config. Used by TTLauncherView.
    public func loadConfig() async -> TTConfig? {
        try? await networkClient?.fetchConfig(siteKey: siteKey)
    }

    /// Start the walkthrough with a pre-loaded config. Used internally by TTLauncherView.
    public func startSession(config: TTConfig) {
        guard activeSession == nil else { return }
        guard let tracker else { return }
        let session = TTWalkthroughSession(config: config, siteKey: siteKey, tracker: tracker)
        session.onEnd = { [weak self] in self?.activeSession = nil }
        activeSession = session
        session.start()
    }

    /// End the active session programmatically.
    public func endSession() {
        activeSession?.dismiss()
        activeSession = nil
    }
}
