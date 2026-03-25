import SwiftUI
import UIKit

public struct TTLauncherView: View {
    @StateObject private var state = TTLauncherState()
    public init() {}

    public var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear

            if state.isReady, let config = state.config {
                if state.isMinimised {
                    minimisedCircle(config: config)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
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
        .ignoresSafeArea()
        .onAppear { state.load() }
    }

    // MARK: - Minimised circle

    @ViewBuilder
    private func minimisedCircle(config: TTConfig) -> some View {
        let fabBg        = Color(config.styles?.resolvedFabBgColor ?? .systemIndigo)
        let icon         = TTIcon.from(config.styles?.fab?.icon)
        let alignRight   = (config.styles?.fab?.position ?? "right") != "left"
        let bottomOffset = CGFloat(config.styles?.fab?.bottomOffset ?? 40) + bottomSafeArea

        HStack {
            if alignRight { Spacer() }

            Button(action: { state.expandFab() }) {
                ZStack {
                    Circle()
                        .fill(fabBg)
                        .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 0)
                    TTIconView(icon: icon, color: .white, size: 15)
                }
                .frame(width: 44, height: 44)
            }

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

    private var pendingAutoOpen = false

    func load() {
        Task {
            config = await TooltipTour.shared.loadConfig()
            guard let config else { return }
            isReady = true

            // In the new design the circle is always the minimised state,
            // so startMinimized just means "skip the welcome card on this load".
            // If autoOpen is true and the user hasn't dismissed, show the welcome card.
            if config.autoOpen && !isDismissed(config.id) {
                if !config.startMinimized {
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    openWelcome()
                } else {
                    // startMinimized: show circle first, open welcome on first tap
                    isMinimised = true
                    pendingAutoOpen = true
                }
            } else {
                // autoOpen off or already dismissed — show nothing until circle is tapped
                isMinimised = true
            }
        }
    }

    func openWelcome()  { withAnimation(.easeOut(duration: 0.28)) { showWelcome = true } }
    func closeWelcome() { withAnimation(.easeOut(duration: 0.22)) { showWelcome = false } }

    /// X tapped on welcome card → slide down and show minimised circle
    func minimise() {
        withAnimation(.easeOut(duration: 0.25)) {
            showWelcome = false
            isMinimised = true
        }
    }

    /// Tapped the minimised circle → show welcome card
    func expandFab() {
        withAnimation(.easeOut(duration: 0.25)) { isMinimised = false }
        if pendingAutoOpen, let config, !isDismissed(config.id) {
            pendingAutoOpen = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { self.openWelcome() }
        } else {
            openWelcome()
        }
    }

    func startGuide() {
        closeWelcome()
        guard let config else { return }
        // When the session ends (Finish or dismiss), slide the minimised circle back in
        TooltipTour.shared.onSessionEnd = { [weak self] in
            guard let self else { return }
            withAnimation(.easeOut(duration: 0.28)) { self.isMinimised = true }
        }
        TooltipTour.shared.startSession(config: config)
    }

    /// "Don't show again" → dismiss permanently, no minimised circle
    func dontShowAgain() {
        guard let config else { return }
        setDismissed(config.id)
        withAnimation(.easeOut(duration: 0.22)) { showWelcome = false }
    }

    func isDismissed(_ id: String) -> Bool {
        UserDefaults.standard.bool(forKey: "tt-dismissed-\(id)")
    }

    private func setDismissed(_ id: String) {
        UserDefaults.standard.set(true, forKey: "tt-dismissed-\(id)")
    }
}

