import SwiftUI
import UIKit

public struct TTLauncherView: View {
    @StateObject private var state = TTLauncherState()
    /// Subscribe to page changes so we can react while still on-screen
    @ObservedObject private var pageRegistry = TTPageRegistry.shared
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
        .onAppear { state.load() }
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

        HStack {
            if alignRight { Spacer() }

            Button(action: { state.expandFab() }) {
                ZStack {
                    Circle().fill(fabBg)
                    TTIconView(icon: icon, color: .white, size: 18)
                }
                .frame(width: 44, height: 44)
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
    /// The page this launcher was on when it first loaded.
    private var homePage: String? = nil

    // MARK: - Load

    func load() {
        guard !hasLoaded else { return }
        hasLoaded = true
        // Remember which page we belong to
        homePage = TTPageRegistry.shared.currentPage
        Task {
            config = await TooltipTour.shared.loadConfig()
            guard let config else { return }
            isReady = true

            if !isDismissed(config.id) {
                if config.startMinimized {
                    isMinimised = true
                    pendingAutoOpen = true
                } else if !hasReachedMaxShows(config) {
                    incrementShowCount(config.id)
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    openWelcome()
                } else {
                    isMinimised = true
                }
            } else {
                isMinimised = true
            }
        }
    }

    // MARK: - Page change (called from onChange while view is still visible)

    func handlePageChange(_ newPage: String?) {
        guard isReady else { return }
        let onHomePage = (homePage == nil) || (newPage == homePage)
        if onHomePage {
            // Returning to our page — slide in
            isOnScreen = true
        } else {
            // Leaving our page — slide off and close welcome card
            isOnScreen  = false
            showWelcome = false
        }
    }

    // MARK: - Welcome card

    func openWelcome()  { withAnimation(.easeOut(duration: 0.28)) { showWelcome = true } }
    func closeWelcome() { withAnimation(.easeOut(duration: 0.22)) { showWelcome = false } }

    func minimise() {
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
        TooltipTour.shared.onSessionEnd = { [weak self] in
            guard let self else { return }
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
