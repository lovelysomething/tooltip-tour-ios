import SwiftUI
import UIKit

public struct TTLauncherView: View {
    @StateObject private var state = TTLauncherState()
    public init() {}

    public var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear

            if state.isReady, let config = state.config {
                let alignRight = (config.styles?.fab?.position ?? "right") != "left"

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
        .ignoresSafeArea()
        .onAppear { state.load() }
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
            // Shadow outside the button so it isn't clipped by the button frame
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

    private var pendingAutoOpen = false

    func load() {
        Task {
            config = await TooltipTour.shared.loadConfig()
            guard let config else { return }
            isReady = true

            // New design: welcome card shows on every launch unless the user
            // has previously tapped "Don't show again" (isDismissed).
            // startMinimized skips the welcome card and goes straight to circle.
            if !isDismissed(config.id) {
                if config.startMinimized {
                    // Circle first; welcome card opens on first tap
                    isMinimised = true
                    pendingAutoOpen = true
                } else {
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    openWelcome()
                }
            } else {
                // Permanently dismissed — sit as circle until tapped
                isMinimised = true
            }
        }
    }

    func openWelcome()  { withAnimation(.easeOut(duration: 0.28)) { showWelcome = true } }
    func closeWelcome() { withAnimation(.easeOut(duration: 0.22)) { showWelcome = false } }

    /// X tapped on welcome card → slide card down, slide circle in from edge
    func minimise() {
        withAnimation(.easeOut(duration: 0.28)) {
            showWelcome = false
            isMinimised = true
        }
    }

    /// Tapped the minimised circle → slide circle out, show welcome card
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
        // When the session ends (Finish or dismiss) → slide the circle back in from edge
        TooltipTour.shared.onSessionEnd = { [weak self] in
            guard let self else { return }
            withAnimation(.easeOut(duration: 0.35)) { self.isMinimised = true }
        }
        TooltipTour.shared.startSession(config: config)
    }

    /// "Don't show again" → dismiss permanently
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
