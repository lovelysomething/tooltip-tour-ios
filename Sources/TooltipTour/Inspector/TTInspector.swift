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
    private var closeButton: UIButton?          // UIKit button for banner ✕
    private var modeSegment: UISegmentedControl? // Navigate / Select toggle

    private let state = TTInspectorState()

    init(sessionId: String, networkClient: TTNetworkClient) {
        self.sessionId     = sessionId
        self.networkClient = networkClient
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
        pill.layer.cornerRadius = 12
        pill.layer.shadowColor = UIColor.black.cgColor
        pill.layer.shadowOpacity = 0.25
        pill.layer.shadowOffset = CGSize(width: 0, height: 4)
        pill.layer.shadowRadius = 10
        pill.translatesAutoresizingMaskIntoConstraints = false

        // Navigate | Select segmented control
        let seg = UISegmentedControl(items: ["Navigate", "Select"])
        seg.selectedSegmentIndex = 0   // start in Navigate mode
        seg.translatesAutoresizingMaskIntoConstraints = false
        seg.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        seg.selectedSegmentTintColor = UIColor.white.withAlphaComponent(0.28)
        seg.setTitleTextAttributes(
            [.foregroundColor: UIColor.white.withAlphaComponent(0.6),
             .font: UIFont.systemFont(ofSize: 12, weight: .semibold)], for: .normal)
        seg.setTitleTextAttributes(
            [.foregroundColor: UIColor.white,
             .font: UIFont.systemFont(ofSize: 12, weight: .bold)], for: .selected)
        seg.addTarget(self, action: #selector(modeChanged(_:)), for: .valueChanged)

        let close = UIButton(type: .system)
        close.setTitle("✕", for: .normal)
        close.setTitleColor(UIColor.white.withAlphaComponent(0.7), for: .normal)
        close.titleLabel?.font = .systemFont(ofSize: 16)
        close.translatesAutoresizingMaskIntoConstraints = false
        close.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        pill.addSubview(seg)
        pill.addSubview(close)
        parent.addSubview(pill)

        NSLayoutConstraint.activate([
            pill.topAnchor.constraint(equalTo: parent.safeAreaLayoutGuide.topAnchor, constant: 12),
            pill.leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: 16),
            pill.trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -16),
            pill.heightAnchor.constraint(equalToConstant: 48),

            seg.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 12),
            seg.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
            seg.trailingAnchor.constraint(equalTo: close.leadingAnchor, constant: -8),
            seg.heightAnchor.constraint(equalToConstant: 32),

            close.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -12),
            close.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
            close.widthAnchor.constraint(equalToConstant: 36),
        ])

        pill.alpha = 0
        UIView.animate(withDuration: 0.3) { pill.alpha = 1 }
        closeButton = close
        modeSegment = seg
    }

    // MARK: - Navigate / Select mode

    @objc private func modeChanged(_ seg: UISegmentedControl) {
        setNavigating(seg.selectedSegmentIndex == 0)
    }

    private func setNavigating(_ navigating: Bool) {
        overlayWindow?.isNavigating = navigating
        modeSegment?.selectedSegmentIndex = navigating ? 0 : 1

        if navigating {
            // Navigate: all touches fall through to the app (scroll, tap, swipe, etc.)
            tapView?.isUserInteractionEnabled = false
            tapView?.backgroundColor = .clear
        } else {
            // Select: intercept next tap to capture an element
            guard state.phase == .tapping else { return }
            tapView?.isUserInteractionEnabled = true
            tapView?.backgroundColor = UIColor(red: 0, green: 0, blue: 1, alpha: 0.04)
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

    private func retryCapture() {
        state.captured = nil
        state.phase = .tapping
        hostingController?.view.isUserInteractionEnabled = false
        // Return to Navigate so the user can scroll to a different element before re-selecting
        setNavigating(true)
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
        UIView.animate(withDuration: 0.25, animations: {
            self.overlayWindow?.alpha = 0
        }, completion: { _ in
            self.overlayWindow?.isHidden = true
            self.overlayWindow = nil
            self.onEnd?()
        })
    }
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

final class TTInspectorWindow: UIWindow {
    /// When true, touches that don't land on a real control (banner) fall through to the app.
    /// When false, the tap interceptor is active and all touches are captured.
    var isNavigating: Bool = true

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        guard isNavigating else { return hit }
        // In navigate mode only intercept touches that hit a real control (banner pill etc.).
        // If the result is just the transparent root background, return nil so UIKit
        // routes the event to the next window (the app) — enabling free scroll/tap.
        if hit == rootViewController?.view { return nil }
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
    let onRetry: () -> Void
    let onAccept: (String) -> Void   // passes the final (possibly edited) identifier

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear
            if (state.phase == .confirming || state.phase == .done), let cap = state.captured {
                TTConfirmCard(
                    suggestedIdentifier: cap.identifier == "unknown" ? "" : cap.identifier,
                    isDone: state.phase == .done,
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
                Text(isDone ? identifier : "Name this element")
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
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 8)
        .onAppear {
            identifier = suggestedIdentifier
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { fieldFocused = true }
        }
    }
}
