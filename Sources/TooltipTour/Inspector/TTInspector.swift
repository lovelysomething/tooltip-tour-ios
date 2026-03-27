import UIKit
import SwiftUI

// MARK: - TTInspector

@MainActor
final class TTInspector {

    private let sessionId: String
    private let networkClient: TTNetworkClient

    var onEnd: (() -> Void)?

    private var overlayWindow: TTInspectorWindow?
    private var tapView: TTTapInterceptorView?
    private var hostingController: UIHostingController<AnyView>?
    private var closeButton: UIButton?           // UIKit button for banner ✕
    private var modeSegment: UISegmentedControl? // Navigate / Highlight / Select toggle
    private var highlightContainer: UIView?      // holds per-element highlight chips
    private var highlightTimer: Timer?           // refreshes chip positions while scrolling
    private var bannerTopConstraint: NSLayoutConstraint? // updated when user drags banner

    private let state = TTInspectorState()
    private let mode: TTInspectorMode

    init(sessionId: String, networkClient: TTNetworkClient, mode: TTInspectorMode = .element) {
        self.sessionId     = sessionId
        self.networkClient = networkClient
        self.mode          = mode
    }

    // MARK: - Start

    func start() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else { return }

        let window = TTInspectorWindow(windowScene: scene)
        window.windowLevel = .alert + 2
        window.backgroundColor = .clear

        let root = UIViewController()
        root.view.backgroundColor = .clear
        window.rootViewController = root
        window.makeKeyAndVisible()
        overlayWindow = window

        // 1 ── Full-screen tap interceptor (bottom layer, handles element capture)
        //      Starts DISABLED — user begins in Navigate mode to scroll first.
        let tapper = TTTapInterceptorView(frame: window.bounds)
        tapper.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tapper.backgroundColor = .clear
        tapper.isUserInteractionEnabled = false
        tapper.onTap = { [weak self] point in self?.handleTap(at: point, in: window) }
        root.view.addSubview(tapper)
        tapView = tapper

        // 2 ── SwiftUI layer (confirm card only — user interaction DISABLED during tapping)
        let overlay = TTInspectorOverlayView(
            state: state,
            mode: mode,
            onRetry:  { [weak self] in self?.retryCapture() },
            onAccept: { [weak self] finalIdentifier in
                self?.submitCapture(identifier: finalIdentifier, displayName: finalIdentifier)
            }
        )
        let hc = UIHostingController(rootView: AnyView(overlay))
        hc.view.backgroundColor = .clear
        hc.view.isUserInteractionEnabled = false   // taps fall through to tapper
        root.addChild(hc)
        hc.view.frame = root.view.bounds
        hc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        root.view.addSubview(hc.view)
        hc.didMove(toParent: root)
        hostingController = hc

        // 3 ── UIKit banner (always on top, owns the ✕ button)
        addBanner(to: root.view)
    }

    // MARK: - Banner (UIKit — reliable first render)

    private func addBanner(to parent: UIView) {
        let pill = UIView()
        pill.backgroundColor = UIColor(red: 0.098, green: 0.145, blue: 0.667, alpha: 1)
        pill.layer.cornerRadius = 0
        pill.layer.shadowColor = UIColor.black.cgColor
        pill.layer.shadowOpacity = 0.25
        pill.layer.shadowOffset = CGSize(width: 0, height: 4)
        pill.layer.shadowRadius = 10
        pill.translatesAutoresizingMaskIntoConstraints = false

        // ↕ drag handle — leftmost element inside the bar
        let dragIcon = UIImageView(image: UIImage(systemName: "arrow.up.and.down"))
        dragIcon.tintColor = UIColor.white.withAlphaComponent(0.6)
        dragIcon.contentMode = .scaleAspectFit
        dragIcon.translatesAutoresizingMaskIntoConstraints = false

        let close = UIButton(type: .system)
        close.setTitle("✕", for: .normal)
        close.setTitleColor(UIColor.white.withAlphaComponent(0.7), for: .normal)
        close.titleLabel?.font = .systemFont(ofSize: 16)
        close.translatesAutoresizingMaskIntoConstraints = false
        close.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        pill.addSubview(dragIcon)
        pill.addSubview(close)
        parent.addSubview(pill)

        // Pan gesture to drag the banner up/down
        let pan = UIPanGestureRecognizer(target: self, action: #selector(bannerPanned(_:)))
        pill.addGestureRecognizer(pan)

        let topC = pill.topAnchor.constraint(equalTo: parent.safeAreaLayoutGuide.topAnchor, constant: 12)
        bannerTopConstraint = topC

        if mode == .page {
            // Page mode: label + single "Capture this screen" button
            let label = UILabel()
            label.text = "Navigate to your screen"
            label.font = .systemFont(ofSize: 13, weight: .semibold)
            label.textColor = UIColor.white.withAlphaComponent(0.85)
            label.translatesAutoresizingMaskIntoConstraints = false

            let captureBtn = UIButton(type: .system)
            captureBtn.setTitle("Set Page", for: .normal)
            captureBtn.setTitleColor(.white, for: .normal)
            captureBtn.titleLabel?.font = .systemFont(ofSize: 12, weight: .bold)
            captureBtn.backgroundColor = UIColor.white.withAlphaComponent(0.22)
            captureBtn.layer.cornerRadius = 0
            captureBtn.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
            captureBtn.translatesAutoresizingMaskIntoConstraints = false
            captureBtn.addTarget(self, action: #selector(capturePageTapped), for: .touchUpInside)

            pill.addSubview(label)
            pill.addSubview(captureBtn)

            NSLayoutConstraint.activate([
                topC,
                pill.leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: 16),
                pill.trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -16),
                pill.heightAnchor.constraint(equalToConstant: 48),

                dragIcon.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 12),
                dragIcon.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
                dragIcon.widthAnchor.constraint(equalToConstant: 18),
                dragIcon.heightAnchor.constraint(equalToConstant: 18),

                label.leadingAnchor.constraint(equalTo: dragIcon.trailingAnchor, constant: 10),
                label.centerYAnchor.constraint(equalTo: pill.centerYAnchor),

                captureBtn.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 10),
                captureBtn.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
                captureBtn.trailingAnchor.constraint(equalTo: close.leadingAnchor, constant: -8),

                close.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -12),
                close.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
                close.widthAnchor.constraint(equalToConstant: 36),
            ])
        } else {
            // Element mode: Navigate | Highlight | Select segmented control
            let seg = UISegmentedControl(items: ["Navigate", "Highlight", "Select"])
            seg.selectedSegmentIndex = 0
            seg.translatesAutoresizingMaskIntoConstraints = false
            seg.layer.cornerRadius = 0
            seg.layer.masksToBounds = true
            // Replace default rounded background images with flat 1×1 pixel images
            // so neither the control border nor the selected indicator have any rounding.
            let render = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
            let clear = render.image { ctx in
                UIColor.clear.setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
            }.resizableImage(withCapInsets: .zero)
            let selected = render.image { ctx in
                UIColor.white.withAlphaComponent(0.28).setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
            }.resizableImage(withCapInsets: .zero)
            seg.setBackgroundImage(clear,    for: .normal,   barMetrics: .default)
            seg.setBackgroundImage(selected, for: .selected, barMetrics: .default)
            seg.setDividerImage(clear, forLeftSegmentState: .normal, rightSegmentState: .normal, barMetrics: .default)
            seg.backgroundColor = UIColor.white.withAlphaComponent(0.15)
            seg.setTitleTextAttributes(
                [.foregroundColor: UIColor.white.withAlphaComponent(0.6),
                 .font: UIFont.systemFont(ofSize: 12, weight: .semibold)], for: .normal)
            seg.setTitleTextAttributes(
                [.foregroundColor: UIColor.white,
                 .font: UIFont.systemFont(ofSize: 12, weight: .bold)], for: .selected)
            seg.addTarget(self, action: #selector(modeChanged(_:)), for: .valueChanged)
            pill.addSubview(seg)

            NSLayoutConstraint.activate([
                topC,
                pill.leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: 16),
                pill.trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -16),
                pill.heightAnchor.constraint(equalToConstant: 48),

                dragIcon.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 12),
                dragIcon.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
                dragIcon.widthAnchor.constraint(equalToConstant: 18),
                dragIcon.heightAnchor.constraint(equalToConstant: 18),

                seg.leadingAnchor.constraint(equalTo: dragIcon.trailingAnchor, constant: 10),
                seg.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
                seg.trailingAnchor.constraint(equalTo: close.leadingAnchor, constant: -8),
                seg.heightAnchor.constraint(equalToConstant: 32),

                close.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -12),
                close.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
                close.widthAnchor.constraint(equalToConstant: 36),
            ])
            modeSegment = seg
        }

        pill.alpha = 0
        UIView.animate(withDuration: 0.3) { pill.alpha = 1 }
        closeButton = close
    }

    @objc private func bannerPanned(_ gr: UIPanGestureRecognizer) {
        guard let pill = gr.view, let parent = pill.superview,
              let topC = bannerTopConstraint else { return }
        let dy = gr.translation(in: parent).y
        let newConstant = topC.constant + dy
        // Clamp: stay within parent bounds (top safe area to near bottom)
        let minY = -(parent.safeAreaInsets.top)
        let maxY = parent.bounds.height - pill.bounds.height - 20
        topC.constant = min(max(newConstant, minY), maxY)
        gr.setTranslation(.zero, in: parent)
    }

    // MARK: - Navigate / Highlight / Select mode

    @objc private func modeChanged(_ seg: UISegmentedControl) {
        setMode(seg.selectedSegmentIndex)
    }

    /// 0 = Navigate, 1 = Highlight, 2 = Select
    private func setMode(_ index: Int) {
        modeSegment?.selectedSegmentIndex = index

        switch index {
        case 1: // Highlight — show target chips; taps handled by highlightContainer
            overlayWindow?.isNavigating = false
            tapView?.isUserInteractionEnabled = false
            tapView?.backgroundColor = .clear
            guard state.phase == .tapping else { return }
            startHighlighting()

        case 2: // Select — intercept next tap
            overlayWindow?.isNavigating = false
            stopHighlighting()
            guard state.phase == .tapping else { return }
            tapView?.isUserInteractionEnabled = true
            tapView?.backgroundColor = UIColor(red: 0, green: 0, blue: 1, alpha: 0.04)

        default: // 0 = Navigate
            overlayWindow?.isNavigating = true
            stopHighlighting()
            tapView?.isUserInteractionEnabled = false
            tapView?.backgroundColor = .clear
        }
    }

    // MARK: - Highlight overlay

    private func startHighlighting() {
        guard highlightContainer == nil,
              let rootView = overlayWindow?.rootViewController?.view else { return }

        let container = TTHighlightContainer()
        container.backgroundColor = .clear
        container.isUserInteractionEnabled = true
        container.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.frame = rootView.bounds
        // Insert below the banner (which is the last subview) so chips don't cover it
        rootView.insertSubview(container, at: 0)
        highlightContainer = container

        // Single GR on the container — still fires when a chip is the hit view because
        // the container is in the responder chain as the chip's superview. This avoids
        // the 50ms timer removing per-chip GRs mid-tap.
        let tap = UITapGestureRecognizer(target: self, action: #selector(highlightContainerTapped(_:)))
        container.addGestureRecognizer(tap)

        refreshHighlightChips()
        highlightTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refreshHighlightChips() }
        }
    }

    private func stopHighlighting() {
        highlightTimer?.invalidate()
        highlightTimer = nil
        highlightContainer?.removeFromSuperview()
        highlightContainer = nil
    }

    private func refreshHighlightChips() {
        guard let container = highlightContainer else { return }
        container.subviews.forEach { $0.removeFromSuperview() }

        let allFrames = TTViewRegistry.shared.allFrames
        guard !allFrames.isEmpty else {
            // Show a hint when nothing is registered
            let hint = UILabel()
            hint.text = "No .ttTarget() views found"
            hint.font = .systemFont(ofSize: 13, weight: .semibold)
            hint.textColor = UIColor.white.withAlphaComponent(0.85)
            hint.backgroundColor = UIColor.black.withAlphaComponent(0.55)
            hint.textAlignment = .center
            hint.layer.cornerRadius = 0
            hint.layer.masksToBounds = true
            hint.sizeToFit()
            hint.frame = CGRect(
                x: (container.bounds.width - hint.frame.width - 24) / 2,
                y: container.bounds.midY - 20,
                width: hint.frame.width + 24,
                height: hint.frame.height + 12
            )
            hint.isUserInteractionEnabled = false
            container.addSubview(hint)
            return
        }

        for (id, frame) in allFrames {
            guard !frame.isEmpty, frame.width > 0, frame.height > 0 else { continue }

            // Chip border + fill — tappable so touches on chips are captured while
            // everything else falls through TTHighlightContainer to the app (scrolling works).
            let chip = UIView(frame: frame)
            chip.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.12)
            chip.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.6).cgColor
            chip.layer.borderWidth = 2
            chip.layer.cornerRadius = 0
            chip.isUserInteractionEnabled = true   // needed so TTHighlightContainer.hitTest finds it
            container.addSubview(chip)

            // Identifier label badge
            let badge = UILabel()
            badge.text = id
            badge.font = .systemFont(ofSize: 10, weight: .bold)
            badge.textColor = .white
            badge.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.8)
            badge.layer.cornerRadius = 0
            badge.layer.masksToBounds = true
            badge.textAlignment = .center
            badge.sizeToFit()
            let badgeW = min(badge.frame.width + 10, frame.width - 4)
            let badgeH = badge.frame.height + 4
            badge.frame = CGRect(x: 4, y: 4, width: badgeW, height: badgeH)
            badge.isUserInteractionEnabled = false
            chip.addSubview(badge)
        }
    }

    // MARK: - Tap handling

    private func handleTap(at point: CGPoint, in window: UIWindow) {
        guard state.phase == .tapping else { return }

        let screenPoint = window.convert(point, to: nil)
        let (identifier, displayName) = identifyView(at: screenPoint)

        // Show confirm card — enable SwiftUI layer for button interaction
        state.captured = TTCapturedElement(identifier: identifier, displayName: displayName, isConfirmed: false)
        state.phase = .confirming
        tapView?.isUserInteractionEnabled = false
        tapView?.backgroundColor = .clear
        hostingController?.view.isUserInteractionEnabled = true
    }

    @objc private func highlightContainerTapped(_ gr: UITapGestureRecognizer) {
        guard let window = overlayWindow else { return }
        handleTap(at: gr.location(in: window), in: window)
    }

    // MARK: - Page capture

    @objc private func capturePageTapped() {
        guard state.phase == .tapping else { return }
        let (id, name) = currentPageInfo()
        state.captured = TTCapturedElement(identifier: id, displayName: name, isConfirmed: false)
        state.phase = .confirming
        hostingController?.view.isUserInteractionEnabled = true
    }

    /// Returns the (identifier, displayName) for the currently visible screen.
    private func currentPageInfo() -> (String, String) {
        // PRIMARY: .ttPage() modifier — most reliable for SwiftUI apps.
        if let page = TTPageRegistry.shared.currentPage {
            return (page, page)
        }

        // FALLBACK: UIViewController introspection (works for UIKit apps).
        guard let vc = topViewController() else { return ("screen", "Screen") }

        // Use navigation/tab title if set
        if let title = vc.title ?? vc.navigationItem.title, !title.isEmpty {
            let id = title.lowercased()
                .replacingOccurrences(of: " ", with: "-")
                .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-")).inverted)
                .joined()
            return (id, title)
        }

        // Class name, stripped of common suffixes
        var name = String(describing: type(of: vc))
        for suffix in ["ViewController", "Controller", "Screen", "View"] {
            if name.hasSuffix(suffix) { name = String(name.dropLast(suffix.count)); break }
        }
        // Skip SwiftUI hosting controllers — they always resolve to "screen"
        if name.contains("Hosting") || name.hasPrefix("_UI") || name.isEmpty {
            return ("screen", "Screen — add .ttPage(\"identifier\") to your view")
        }
        // CamelCase → kebab-case
        var id = ""
        for (i, char) in name.enumerated() {
            if char.isUppercase && i > 0 { id += "-" }
            id += char.lowercased()
        }
        return (id, name)
    }

    private func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let appWindow = scene.windows.first(where: { !($0 is TTInspectorWindow) })
        else { return nil }
        return findTop(appWindow.rootViewController)
    }

    private func findTop(_ vc: UIViewController?) -> UIViewController? {
        guard let vc else { return nil }
        if let nav = vc as? UINavigationController { return findTop(nav.topViewController) }
        if let tab = vc as? UITabBarController     { return findTop(tab.selectedViewController) }
        if let presented = vc.presentedViewController { return findTop(presented) }
        return vc
    }

    private func retryCapture() {
        state.captured = nil
        state.phase = .tapping
        hostingController?.view.isUserInteractionEnabled = false
        // Return to Navigate so the user can scroll/highlight before re-selecting
        setMode(0)
    }

    // MARK: - Element identification

    private func identifyView(at screenPoint: CGPoint) -> (identifier: String, displayName: String) {
        // PRIMARY: TTViewRegistry — populated by .ttTarget() modifier, most precise.
        if let id = TTViewRegistry.shared.identifier(at: screenPoint) {
            return (id, id)
        }

        guard let appWindow = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { !($0 is TTInspectorWindow) && !($0 is TTOverlayWindow) })
        else { return ("unknown", "Unknown element") }

        // SECONDARY: walk the UIAccessibility semantic tree.
        // This is how XCTest finds SwiftUI elements — it's the correct tree,
        // includes .accessibilityIdentifier() values, and skips internal containers.
        if let result = accessibilityHit(at: screenPoint, in: appWindow) {
            return result
        }

        // FALLBACK: use accessibility label or visible text content as a suggested identifier
        // so the developer knows what to call the view even without an explicit identifier set.
        if let text = accessibilityText(at: screenPoint, in: appWindow), !text.isEmpty {
            return (safe(text), text)
        }

        // Last resort: walk UIKit view hierarchy upward from hit view.
        // Check UILabel/UIButton text first, then accessibilityLabel on any UIView
        // (SwiftUI hosting views set accessibilityLabel even without VoiceOver).
        let localPoint = appWindow.convert(screenPoint, from: nil)
        let hitView = appWindow.hitTest(localPoint, with: nil)
        var view: UIView? = hitView
        while let v = view {
            if let l = v as? UILabel, let t = l.text, !t.isEmpty { return (safe(t), t) }
            if let b = v as? UIButton, let t = b.title(for: .normal), !t.isEmpty { return (safe(t), t) }
            if let label = v.accessibilityLabel, !label.isEmpty {
                let cls = String(describing: type(of: v))
                if !cls.contains("Platform") && !cls.contains("_UIHosting") && !cls.contains("UIWindow") {
                    return (safe(label), label)
                }
            }
            view = v.superview
        }

        return ("unknown", "Unknown")
    }

    /// Screen-space frame for an element. UIViews use their converted bounds because
    /// `accessibilityFrame` is `.zero` on plain SwiftUI container views.
    private func screenFrame(of element: NSObject) -> CGRect {
        if let view = element as? UIView {
            return view.convert(view.bounds, to: nil)
        }
        return element.accessibilityFrame
    }

    /// Collects the logical children of an accessibility element.
    private func axChildren(of element: NSObject) -> [NSObject] {
        if let arr = element.accessibilityElements as? [NSObject] { return arr }
        if element.accessibilityElementCount() > 0 {
            return (0 ..< element.accessibilityElementCount())
                .compactMap { element.accessibilityElement(at: $0) as? NSObject }
        }
        if let view = element as? UIView { return view.subviews.reversed() }
        return []
    }

    /// Recursively search the UIAccessibility element tree for the smallest element
    /// whose frame contains `point` and has an accessibilityIdentifier set.
    private func accessibilityHit(at point: CGPoint, in element: NSObject) -> (String, String)? {
        for child in axChildren(of: element) {
            guard screenFrame(of: child).contains(point) else { continue }
            if let result = accessibilityHit(at: point, in: child) { return result }
        }

        let frame = screenFrame(of: element)
        if frame.contains(point),
           let id = (element as? UIAccessibilityIdentification)?.accessibilityIdentifier,
           !id.isEmpty {
            let cls = String(describing: type(of: element))
            if !cls.contains("Platform") && !cls.contains("_UIHosting") {
                return (id, id)
            }
        }

        return nil
    }

    /// Returns the accessibilityLabel of the most specific element at `point` that has one.
    private func accessibilityText(at point: CGPoint, in element: NSObject) -> String? {
        for child in axChildren(of: element) {
            guard screenFrame(of: child).contains(point) else { continue }
            if let result = accessibilityText(at: point, in: child) { return result }
        }

        let frame = screenFrame(of: element)
        if frame.contains(point), let label = element.accessibilityLabel, !label.isEmpty {
            return label
        }
        return nil
    }

    private func safe(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "-")
            .lowercased()
    }

    // MARK: - Submit

    private func submitCapture(identifier: String, displayName: String) {
        state.phase = .done
        Task {
            try? await networkClient.updateInspectorSession(
                id: sessionId, identifier: identifier, displayName: displayName
            )
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            await MainActor.run { self.tearDown() }
        }
    }

    // MARK: - Cancel / tear down

    @objc private func cancelTapped() { tearDown() }

    private func tearDown() {
        stopHighlighting()
        UIView.animate(withDuration: 0.25, animations: {
            self.overlayWindow?.alpha = 0
        }, completion: { _ in
            self.overlayWindow?.isHidden = true
            self.overlayWindow = nil
            self.onEnd?()
        })
    }
}

// MARK: - Inspector mode

public enum TTInspectorMode {
    case element  // Navigate / Highlight / Select — tap to capture a UI element
    case page     // Navigate freely — tap "Capture this screen" to capture the current VC
}

// MARK: - State

enum TTInspectorPhase { case tapping, confirming, done }

struct TTCapturedElement { let identifier: String; let displayName: String; let isConfirmed: Bool }

@MainActor
final class TTInspectorState: ObservableObject {
    @Published var phase: TTInspectorPhase = .tapping
    @Published var captured: TTCapturedElement? = nil
}

// MARK: - TTInspectorWindow / TTTapInterceptorView

// MARK: - Highlight container (pass-through hit testing)

/// A UIView that only intercepts touches landing on interactive chip subviews.
/// Anything that doesn't hit a chip returns nil so the touch falls through to the app,
/// keeping scrolling alive in Highlight mode.
final class TTHighlightContainer: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit
    }
}

final class TTInspectorWindow: UIWindow {
    /// When true, touches that don't land on a real control (banner) fall through to the app.
    /// When false, the tap interceptor is active and all touches are captured.
    var isNavigating: Bool = true

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        // If only the transparent root background was hit, pass through to the app.
        // This keeps scrolling alive in all modes. TTHighlightContainer and the banner
        // handle their own interactivity — real controls are always returned.
        if hit == nil || hit == rootViewController?.view { return nil }
        return hit
    }
}

final class TTTapInterceptorView: UIView {
    var onTap: ((CGPoint) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        let gr = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
        gr.cancelsTouchesInView = true
        gr.delaysTouchesBegan  = true
        addGestureRecognizer(gr)
    }

    required init?(coder: NSCoder) { super.init(coder: coder) }

    @objc private func tapped(_ gr: UITapGestureRecognizer) {
        onTap?(gr.location(in: self))
    }
}

// MARK: - SwiftUI confirm card overlay

struct TTInspectorOverlayView: View {
    @ObservedObject var state: TTInspectorState
    let mode: TTInspectorMode
    let onRetry: () -> Void
    let onAccept: (String) -> Void   // passes the final (possibly edited) identifier

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear

            if (state.phase == .confirming || state.phase == .done) {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: state.phase)
            }

            if (state.phase == .confirming || state.phase == .done), let cap = state.captured {
                TTConfirmCard(
                    suggestedIdentifier: cap.identifier == "unknown" ? "" : cap.identifier,
                    isDone: state.phase == .done,
                    subtitle: mode == .page ? "Page identified as" : "Name this element",
                    onRetry: onRetry,
                    onAccept: onAccept
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 48)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(duration: 0.35), value: state.phase)
            }
        }
    }
}

struct TTConfirmCard: View {
    let suggestedIdentifier: String
    let isDone: Bool
    let subtitle: String
    let onRetry: () -> Void
    let onAccept: (String) -> Void

    @State private var identifier: String = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text(isDone ? "Sent to dashboard ✓" : "Set identifier")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundColor(Color(red: 0.098, green: 0.145, blue: 0.667).opacity(0.65))
                Text(isDone ? identifier : subtitle)
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(Color(red: 0.051, green: 0.039, blue: 0.11))
                    .lineLimit(1)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Editable identifier field
            if !isDone {
                TextField("e.g. loginButton or welcomeTitle", text: $identifier)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(red: 0.098, green: 0.145, blue: 0.667))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.098, green: 0.145, blue: 0.667).opacity(0.06))
                    .focused($fieldFocused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit { if !identifier.isEmpty { onAccept(identifier) } }
            } else {
                Text(identifier)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(red: 0.098, green: 0.145, blue: 0.667))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 0.098, green: 0.145, blue: 0.667).opacity(0.06))
            }

            if !isDone {
                HStack(spacing: 0) {
                    Button(action: onRetry) {
                        Text("Retry")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.5)
                            .textCase(.uppercase)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .foregroundColor(Color(red: 0.051, green: 0.039, blue: 0.11).opacity(0.4))
                    }
                    Button {
                        if !identifier.isEmpty { onAccept(identifier) }
                    } label: {
                        Text("Use this →")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.5)
                            .textCase(.uppercase)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .foregroundColor(.white)
                            .background(identifier.isEmpty
                                ? Color(red: 0.098, green: 0.145, blue: 0.667).opacity(0.4)
                                : Color(red: 0.098, green: 0.145, blue: 0.667))
                    }
                    .disabled(identifier.isEmpty)
                }
            }
        }
        .background(Color.white)
        .cornerRadius(0)
        .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 8)
        .onAppear {
            identifier = suggestedIdentifier
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { fieldFocused = true }
        }
    }
}
