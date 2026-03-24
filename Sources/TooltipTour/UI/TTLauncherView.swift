import SwiftUI

public struct TTLauncherView: View {
    @StateObject private var state = TTLauncherState()
    public init() {}

    public var body: some View {
        GeometryReader { _ in
            if state.isReady, let config = state.config {
                let pos = config.styles?.fab?.position ?? "bottom-left"
                ZStack(alignment: alignment(for: pos)) {
                    Color.clear
                    if state.isMinimised {
                        miniTab(config: config, pos: pos)
                    } else {
                        launcher(config: config, pos: pos)
                    }
                }
                .ignoresSafeArea()
            }
        }
        .onAppear { state.load() }
    }

    // MARK: - Full launcher (FAB + X + optional welcome card)

    @ViewBuilder
    private func launcher(config: TTConfig, pos: String) -> some View {
        let isTop = pos.hasPrefix("top")
        let isRight = pos.contains("right")
        let fabBg = Color(config.styles?.resolvedFabBgColor ?? .systemIndigo)
        let fabRadius = config.styles?.fabCornerRadius ?? 24

        VStack(alignment: isRight ? .trailing : .leading, spacing: 12) {
            if isTop {
                fabRow(config: config, isRight: isRight, fabBg: fabBg, fabRadius: fabRadius)
                if state.showWelcome {
                    TTWelcomeCardView(config: config,
                        onStart: { state.startGuide() },
                        onClose: { state.closeWelcome() },
                        onDontShowAgain: { state.dontShowAgain() })
                }
            } else {
                if state.showWelcome {
                    TTWelcomeCardView(config: config,
                        onStart: { state.startGuide() },
                        onClose: { state.closeWelcome() },
                        onDontShowAgain: { state.dontShowAgain() })
                }
                fabRow(config: config, isRight: isRight, fabBg: fabBg, fabRadius: fabRadius)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 32)
    }

    @ViewBuilder
    private func fabRow(config: TTConfig, isRight: Bool, fabBg: Color, fabRadius: CGFloat) -> some View {
        HStack(spacing: 10) {
            if isRight {
                // right-side: FAB first (inner), X outermost (closest to right edge)
                fabBtn(config: config, fabBg: fabBg, fabRadius: fabRadius)
                dismissBtn(fabBg: fabBg)
            } else {
                // left-side: X outermost (closest to left edge), FAB inner
                dismissBtn(fabBg: fabBg)
                fabBtn(config: config, fabBg: fabBg, fabRadius: fabRadius)
            }
        }
    }

    private func fabBtn(config: TTConfig, fabBg: Color, fabRadius: CGFloat) -> some View {
        Button(action: {
            if state.isDismissed(config.id) {
                state.startGuide()
            } else {
                state.showWelcome ? state.closeWelcome() : state.openWelcome()
            }
        }) {
            HStack(spacing: 8) {
                iconView(icon: config.styles?.fab?.icon)
                Text(config.fabLabel ?? "Take a tour")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(fabBg)
            .clipShape(RoundedRectangle(cornerRadius: fabRadius))
            .shadow(color: fabBg.opacity(0.4), radius: 10, x: 0, y: 4)
        }
    }

    private func dismissBtn(fabBg: Color) -> some View {
        Button(action: { state.minimiseFab() }) {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 22, height: 22)
                .background(Color.black.opacity(0.18))
                .clipShape(Circle())
        }
    }

    // MARK: - Mini tab

    private func miniTab(config: TTConfig, pos: String) -> some View {
        let fabBg = Color(config.styles?.resolvedFabBgColor ?? .systemIndigo)
        return Button(action: { state.expandFab() }) {
            ZStack {
                fabBg
                miniIconView(icon: config.styles?.fab?.icon)
                    .foregroundColor(.white)
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: fabBg.opacity(0.4), radius: 8, x: 0, y: 3)
        }
        .padding(miniTabPadding(pos: pos))
    }

    // MARK: - Icons

    /// Icon for the full FAB button — no icon shows nothing (label-only)
    @ViewBuilder
    private func iconView(icon: String?) -> some View {
        if let icon, !icon.isEmpty {
            resolvedIcon(icon)
        }
    }

    /// Icon for the mini tab — always shows something (falls back to questionmark)
    @ViewBuilder
    private func miniIconView(icon: String?) -> some View {
        if let icon, !icon.isEmpty {
            resolvedIcon(icon)
        } else {
            Image(systemName: "questionmark")
                .font(.system(size: 16, weight: .semibold))
        }
    }

    @ViewBuilder
    private func resolvedIcon(_ icon: String) -> some View {
        let sfMap: [String: String] = [
            "question": "questionmark.circle", "compass": "location.north.circle",
            "map": "map", "lightbulb": "lightbulb", "search": "magnifyingglass",
            "book": "book", "rocket": "paperplane.fill", "chat": "bubble.left.fill",
            "info": "info.circle",
        ]
        if let sf = sfMap[icon] {
            Image(systemName: sf).font(.system(size: 16, weight: .medium))
        } else {
            Text(icon).font(.system(size: 16))
        }
    }

    // MARK: - Position helpers

    private func alignment(for pos: String) -> Alignment {
        switch pos {
        case "bottom-right":  return .bottomTrailing
        case "bottom-center": return .bottom
        case "top-left":      return .topLeading
        case "top-right":     return .topTrailing
        case "top-center":    return .top
        default:              return .bottomLeading
        }
    }

    private func miniTabPadding(pos: String) -> EdgeInsets {
        let isTop = pos.hasPrefix("top")
        let isRight = pos.contains("right")
        let v: CGFloat = 48
        let h: CGFloat = 0
        if isTop && isRight  { return EdgeInsets(top: v, leading: 0,  bottom: 0, trailing: h) }
        if isTop             { return EdgeInsets(top: v, leading: h,  bottom: 0, trailing: 0) }
        if isRight           { return EdgeInsets(top: 0, leading: 0,  bottom: v, trailing: h) }
        return EdgeInsets(top: 0, leading: h, bottom: v, trailing: 0)
    }
}

// MARK: - State

@MainActor
final class TTLauncherState: ObservableObject {
    @Published var config: TTConfig?
    @Published var isReady = false
    @Published var isMinimised = false
    @Published var showWelcome = false

    private var pendingAutoOpen = false

    func load() {
        Task {
            config = await TooltipTour.shared.loadConfig()
            guard let config else { return }
            isReady = true

            if config.startMinimized {
                isMinimised = true
                if config.autoOpen && !isDismissed(config.id) {
                    pendingAutoOpen = true
                }
            } else if config.autoOpen && !isDismissed(config.id) {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                openWelcome()
            }
        }
    }

    func openWelcome()  { withAnimation(.easeOut(duration: 0.25)) { showWelcome = true } }
    func closeWelcome() { withAnimation(.easeOut(duration: 0.25)) { showWelcome = false } }

    func minimiseFab() {
        withAnimation(.easeOut(duration: 0.22)) { isMinimised = true; showWelcome = false }
    }

    func expandFab() {
        withAnimation(.easeOut(duration: 0.22)) { isMinimised = false }
        if pendingAutoOpen, let config, !isDismissed(config.id) {
            pendingAutoOpen = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { self.openWelcome() }
        }
    }

    func startGuide() {
        closeWelcome()
        guard let config else { return }
        TooltipTour.shared.startSession(config: config)
    }

    func dontShowAgain() {
        guard let config else { return }
        setDismissed(config.id)
        closeWelcome()
    }

    func isDismissed(_ id: String) -> Bool {
        UserDefaults.standard.bool(forKey: "tt-dismissed-\(id)")
    }

    private func setDismissed(_ id: String) {
        UserDefaults.standard.set(true, forKey: "tt-dismissed-\(id)")
    }
}
