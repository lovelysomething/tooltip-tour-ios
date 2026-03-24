import SwiftUI
import UIKit

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
                            .transition(miniTabTransition(pos: pos))
                    } else {
                        launcher(config: config, pos: pos)
                            .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: fabAnchor(pos))))
                    }
                }
                .ignoresSafeArea()
            }
        }
        .onAppear { state.load() }
    }

    // MARK: - Safe area helpers

    private var topSafeArea: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })?
            .windows.first?.safeAreaInsets.top ?? 44
    }

    private var bottomSafeArea: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })?
            .windows.first?.safeAreaInsets.bottom ?? 0
    }

    // MARK: - Full launcher (FAB + X below + optional welcome card)

    @ViewBuilder
    private func launcher(config: TTConfig, pos: String) -> some View {
        let isTop    = pos.hasPrefix("top")
        let isRight  = pos.contains("right")
        let isCenter = pos.contains("center")
        let fabBg    = Color(config.styles?.resolvedFabBgColor ?? .systemIndigo)
        let fabRadius = config.styles?.fabCornerRadius ?? 24

        let hAlignment: HorizontalAlignment = isRight ? .trailing : (isCenter ? .center : .leading)

        VStack(alignment: hAlignment, spacing: 12) {
            if isTop {
                fabStack(config: config, fabBg: fabBg, fabRadius: fabRadius)
                if state.showWelcome {
                    TTWelcomeCardView(config: config,
                        onStart: { state.startGuide() },
                        onClose: { state.closeWelcome() },
                        onDontShowAgain: { state.dontShowAgain() })
                        .transition(.opacity)
                }
            } else {
                if state.showWelcome {
                    TTWelcomeCardView(config: config,
                        onStart: { state.startGuide() },
                        onClose: { state.closeWelcome() },
                        onDontShowAgain: { state.dontShowAgain() })
                        .transition(.opacity)
                }
                fabStack(config: config, fabBg: fabBg, fabRadius: fabRadius)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top,    isTop ? topSafeArea + 8 : 32)
        .padding(.bottom, isTop ? 32 : 32)
    }

    /// FAB button with dismiss X stacked beneath it
    @ViewBuilder
    private func fabStack(config: TTConfig, fabBg: Color, fabRadius: CGFloat) -> some View {
        VStack(spacing: 8) {
            fabBtn(config: config, fabBg: fabBg, fabRadius: fabRadius)
            dismissBtn(fabBg: fabBg)
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
        let fabRadius = config.styles?.fabCornerRadius ?? 24
        return Button(action: { state.expandFab() }) {
            ZStack {
                fabBg
                miniIconView(icon: config.styles?.fab?.icon)
                    .foregroundColor(.white)
            }
            .frame(width: 44, height: 44)
            .clipShape(miniTabShape(pos: pos, r: fabRadius))
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

    /// Icon for the mini tab — always shows something (falls back to questionmark.circle.fill)
    @ViewBuilder
    private func miniIconView(icon: String?) -> some View {
        if let icon, !icon.isEmpty {
            resolvedIcon(icon)
        } else {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 15, weight: .medium))
        }
    }

    @ViewBuilder
    private func resolvedIcon(_ icon: String) -> some View {
        let sfMap: [String: String] = [
            "question":  "questionmark.circle",
            "compass":   "safari",
            "map":       "map",
            "lightbulb": "lightbulb",
            "search":    "magnifyingglass",
            "book":      "book",
            "rocket":    "paperplane",
            "chat":      "bubble.left",
            "info":      "info.circle",
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
        let isTop    = pos.hasPrefix("top")
        let isRight  = pos.contains("right")
        let isCenter = pos.contains("center")
        let topPad: CGFloat  = topSafeArea + 0   // flush under status bar
        let sidePad: CGFloat = 48                 // left/right tabs: distance from bottom
        let botPad: CGFloat  = bottomSafeArea     // bottom-center: above home indicator
        if isTop && isRight  { return EdgeInsets(top: topPad, leading: 0, bottom: 0, trailing: 0) }
        if isTop             { return EdgeInsets(top: topPad, leading: 0, bottom: 0, trailing: 0) }
        if isRight           { return EdgeInsets(top: 0, leading: 0, bottom: sidePad, trailing: 0) }
        if isCenter          { return EdgeInsets(top: 0, leading: 0, bottom: botPad,  trailing: 0) }
        return                        EdgeInsets(top: 0, leading: 0, bottom: sidePad, trailing: 0)
    }

    // MARK: - Mini tab shape (partial rounded corners matching web CSS)

    private func miniTabShape(pos: String, r: CGFloat) -> PartialRoundedRect {
        let isLeft   = pos.contains("left")
        let isRight  = pos.contains("right")
        let isTop    = pos.hasPrefix("top")
        if isLeft  { return PartialRoundedRect(tl: 0, tr: r, br: r, bl: 0) }
        if isRight { return PartialRoundedRect(tl: r, tr: 0, br: 0, bl: r) }
        if isTop   { return PartialRoundedRect(tl: 0, tr: 0, br: r, bl: r) }
        return         PartialRoundedRect(tl: r, tr: r, br: 0, bl: 0)
    }

    // MARK: - Transition helpers

    private func miniTabTransition(pos: String) -> AnyTransition {
        if pos.contains("right") { return .move(edge: .trailing) }
        if pos.hasPrefix("top")  { return .move(edge: .top) }
        if pos.contains("bottom") && pos.contains("center") { return .move(edge: .bottom) }
        return .move(edge: .leading)  // default bottom-left
    }

    private func fabAnchor(_ pos: String) -> UnitPoint {
        switch pos {
        case "bottom-right":  return .bottomTrailing
        case "bottom-center": return .bottom
        case "top-left":      return .topLeading
        case "top-right":     return .topTrailing
        case "top-center":    return .top
        default:              return .bottomLeading
        }
    }
}

// MARK: - PartialRoundedRect Shape

private struct PartialRoundedRect: Shape {
    var tl: CGFloat; var tr: CGFloat; var br: CGFloat; var bl: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        if tr > 0 { p.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr), radius: tr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false) }
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        if br > 0 { p.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br), radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false) }
        p.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        if bl > 0 { p.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl), radius: bl, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false) }
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        if tl > 0 { p.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl), radius: tl, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false) }
        p.closeSubpath()
        return p
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
