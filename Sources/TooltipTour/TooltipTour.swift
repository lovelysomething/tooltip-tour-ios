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
    private var activeInspector: TTInspector?

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

    /// Called by TTLauncherState after the session ends so the launcher can show the minimised circle.
    var onSessionEnd: (() -> Void)?

    /// Start the walkthrough with a pre-loaded config. Used internally by TTLauncherView.
    public func startSession(config: TTConfig) {
        guard activeSession == nil else { return }
        guard let tracker else { return }
        let session = TTWalkthroughSession(config: config, siteKey: siteKey, tracker: tracker)
        session.onEnd = { [weak self] in
            self?.activeSession = nil
            self?.onSessionEnd?()
        }
        activeSession = session
        session.start()
    }

    /// End the active session programmatically.
    public func endSession() {
        activeSession?.dismiss()
        activeSession = nil
    }

    // MARK: - Inspector

    /// Handle a deep link URL. Call from `.onOpenURL` in SwiftUI or `application(_:open:)` in UIKit.
    ///
    /// Supported scheme: `tooltiptour://inspect?session={id}&base={encodedURL}`
    public func handleDeepLink(_ url: URL) {
        guard url.scheme == "tooltiptour",
              url.host == "inspect",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let sessionId = components.queryItems?.first(where: { $0.name == "session" })?.value,
              let baseEncoded = components.queryItems?.first(where: { $0.name == "base" })?.value,
              let inspectorBase = baseEncoded.removingPercentEncoding ?? Optional(baseEncoded)
        else { return }
        startInspector(sessionId: sessionId, baseURL: inspectorBase)
    }

    /// Start the visual inspector overlay for the given session.
    public func startInspector(sessionId: String, baseURL: String) {
        guard activeInspector == nil else { return }
        let client = TTNetworkClient(baseURL: baseURL)
        let inspector = TTInspector(sessionId: sessionId, networkClient: client)
        inspector.onEnd = { [weak self] in
            self?.activeInspector = nil
        }
        activeInspector = inspector
        inspector.start()
    }
}
