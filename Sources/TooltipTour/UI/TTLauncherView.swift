import SwiftUI
import UIKit

public struct TTLauncherView: View {
    @StateObject private var state = TTLauncherState()
    /// Subscribe to page changes so we can react while still on-screen
    @ObservedObject private var pageRegistry = TTPageRegistry.shared
    /// Reads the page identifier injected by the nearest .ttPage() ancestor.
    /// Available before onAppear, so no tab-switching timing races.
    @Environment(\.ttPageIdentifier) private var ttPageIdentifier
    public init() {}

    public var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear

            // Dim overlay — shown behind the welcome card so the user must interact with it
            if state.showWelcome {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { state.minimise() }
            }

            if state.isReady, let config = state.config {
                let alignRight = (config.styles?.fab?.position ?? "right") != "left"

                if state.isOnScreen {
                    if state.isMinimised {
                        minimisedCircle(config: config, alignRight: alignRight)
                            .transition(.move(edge: alignRight ? .trailing : .leading))
                    } else if state.showWelcome {
                        TTWelcomeCardView(
                            config: config,
                            onStart:          { state.startGuide() },
                            onDismiss:        { state.minimise() },
                            onDontShowAgain:  { state.dontShowAgain() }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        }
        .ignoresSafeArea()
        .animation(.easeOut(duration: 0.25), value: state.showWelcome)
        .animation(.easeInOut(duration: 0.35), value: state.isOnScreen)
        .onAppear { state.load(page: ttPageIdentifier) }
        // React to page changes while this view is still visible —
        // fires BEFORE the tab transition, unlike onDisappear.
        .onChange(of: pageRegistry.currentPage) { newPage in
            state.handlePageChange(newPage)
        }
    }

    // MARK: - Minimised circle

    @ViewBuilder
    private func minimisedCircle(config: TTConfig, alignRight: Bool) -> some View {
        let fabBg        = Color(config.styles?.resolvedFabBgColor ?? .systemIndigo)
        let icon         = TTIcon.from(config.styles?.fab?.icon)
        let bottomOffset = CGFloat(config.styles?.fab?.bottomOffset ?? 40) + bottomSafeArea
        let fabSize      = CGFloat(config.styles?.fab?.size ?? 44)
        // Cap corner radius at half the frame so max value = perfect circle
        let fabRadius    = min(CGFloat(config.styles?.fab?.borderRadius ?? fabSize / 2), fabSize / 2)
        // Icon scales proportionally with the button (baseline: 18pt icon in 44pt frame)
        let iconSize     = round(fabSize * (18 / 44))

        HStack {
            if alignRight { Spacer() }

            Button(action: { state.expandFab() }) {
                ZStack {
                    RoundedRectangle(cornerRadius: fabRadius).fill(fabBg)
                    TTIconView(icon: icon, color: .white, size: iconSize)
                }
                .frame(width: fabSize, height: fabSize)
            }
            .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 0)

            if !alignRight { Spacer() }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, bottomOffset)
    }

    // MARK: - Safe area

    private var bottomSafeArea: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })?
            .windows.first?.safeAreaInsets.bottom ?? 0
    }
}

// MARK: - State

@MainActor
final class TTLauncherState: ObservableObject {
    @Published var config: TTConfig?
    @Published var isReady      = false
    @Published var isMinimised  = false
    @Published var showWelcome  = false
    @Published var isOnScreen   = true

    private var pendingAutoOpen = false
    private var hasLoaded       = false
    /// The page this launcher is bound to.
    private var homePage: String? = nil
    /// True when no ttPageIdentifier was injected — launcher follows page changes globally.
    private var isGlobal        = false
    /// Tour IDs the user has manually minimised this session — won't auto-open until they tap the circle.
    private var sessionMinimised: Set<String> = []
    private var inspectorObserver: Any?

    init() {
        // Minimise any visible tour card when the Visual Inspector launches.
        inspectorObserver = NotificationCenter.default.addObserver(
            forName: .ttInspectorDidStart, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                self.showWelcome = false
                self.isMinimised = true
            }
        }
    }

    deinit {
        if let obs = inspectorObserver { NotificationCenter.default.removeObserver(obs) }
    }

    // MARK: - Load

    func load(page: String?) {
        guard !hasLoaded else { return }
        hasLoaded = true
        isGlobal  = (page == nil)
        homePage  = page ?? TTPageRegistry.shared.currentPage
        if homePage != nil {
            fetchAndShow()
        }
        // If homePage is still nil, handlePageChange will call fetchAndShow
        // once the first page identifier arrives via onChange.
    }

    // MARK: - Page change (called from onChange while view is still visible)

    func handlePageChange(_ newPage: String?) {
        if isGlobal {
            // Global launcher: re-fetch for every new page, show if a tour exists.
            guard let newPage else { isOnScreen = false; return }
            guard newPage != homePage else { return }
            homePage    = newPage
            config      = nil
            isReady     = false
            isOnScreen  = false
            isMinimised = false
            showWelcome = false
            fetchAndShow()
        } else {
            // Per-page launcher: slide in/out based on homePage.
            if homePage == nil, let newPage {
                homePage = newPage
                isOnScreen = true
                fetchAndShow()
                return
            }
            guard let myPage = homePage else { return }
            if newPage == myPage {
                isOnScreen = true
            } else {
                isOnScreen  = false
                showWelcome = false
            }
        }
    }

    // MARK: - Config fetch

    private func fetchAndShow() {
        let page = homePage   // capture before entering Task
        Task {
            // Don't launch tours while the Visual Inspector is open.
            guard !TooltipTour.shared.isInspectorActive else { return }
            guard let config = await TooltipTour.shared.loadConfig(page: page) else { return }
            self.config  = config
            isReady    = true
            isOnScreen = true   // make visible once we know a tour exists

            if !isDismissed(config.id) {
                if sessionMinimised.contains(config.id) {
                    // User manually closed this tour earlier this session — keep it minimised.
                    isMinimised = true
                } else if config.startMinimized {
                    isMinimised = true
                    pendingAutoOpen = true
                } else if !hasReachedMaxShows(config) {
                    incrementShowCount(config.id)
                    try? await Task.sleep(nanoseconds: 300_000_000)  // 0.3s — just enough for the app to settle
                    openWelcome()
                } else {
                    isMinimised = true
                }
            } else {
                isMinimised = true
            }
        }
    }

    // MARK: - Welcome card

    func openWelcome()  { withAnimation(.easeOut(duration: 0.28)) { showWelcome = true } }
    func closeWelcome() { withAnimation(.easeOut(duration: 0.22)) { showWelcome = false } }

    func minimise() {
        // Remember that the user manually closed this tour so it stays minimised
        // for the rest of the session (until they tap the circle again).
        if let config { sessionMinimised.insert(config.id) }
        withAnimation(.easeInOut(duration: 0.5)) {
            showWelcome = false
            isMinimised = true
        }
    }

    func expandFab() {
        withAnimation(.easeInOut(duration: 0.45)) { isMinimised = false }
        if pendingAutoOpen, let config, !isDismissed(config.id) {
            pendingAutoOpen = false
            if !hasReachedMaxShows(config) { incrementShowCount(config.id) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { self.openWelcome() }
        } else {
            openWelcome()
        }
    }

    func startGuide() {
        closeWelcome()
        guard let config else { return }
        let tourId = config.id
        TooltipTour.shared.onSessionEnd = { [weak self] in
            guard let self else { return }
            // Mark as session-minimised so coming back to this page doesn't re-launch the welcome card.
            self.sessionMinimised.insert(tourId)
            withAnimation(.easeInOut(duration: 0.5)) { self.isMinimised = true }
        }
        TooltipTour.shared.startSession(config: config)
    }

    func dontShowAgain() {
        guard let config else { return }
        setDismissed(config.id)
        withAnimation(.easeOut(duration: 0.22)) { showWelcome = false }
    }

    // MARK: - Dismiss persistence

    func isDismissed(_ id: String) -> Bool {
        UserDefaults.standard.bool(forKey: "tt-dismissed-\(id)")
    }

    private func setDismissed(_ id: String) {
        UserDefaults.standard.set(true, forKey: "tt-dismissed-\(id)")
    }

    // MARK: - Show count (max_shows)

    private func getShowCount(_ id: String) -> Int {
        UserDefaults.standard.integer(forKey: "tt-shows-\(id)")
    }

    private func incrementShowCount(_ id: String) {
        UserDefaults.standard.set(getShowCount(id) + 1, forKey: "tt-shows-\(id)")
    }

    private func hasReachedMaxShows(_ config: TTConfig) -> Bool {
        guard let max = config.maxShows else { return false }
        return getShowCount(config.id) >= max
    }
}
