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
        let tapper = TTTapInterceptorView(frame: window.bounds)
        tapper.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tapper.backgroundColor = UIColor(red: 0, green: 0, blue: 1, alpha: 0.04)
        tapper.onTap = { [weak self] point in self?.handleTap(at: point, in: window) }
        root.view.addSubview(tapper)
        tapView = tapper

        // 2 ── SwiftUI layer (confirm card only — user interaction DISABLED during tapping)
        let overlay = TTInspectorOverlayView(
            state: state,
            onRetry:  { [weak self] in self?.retryCapture() },
            onAccept: { [weak self] in
                guard let self, let cap = self.state.captured else { return }
                self.submitCapture(identifier: cap.identifier, displayName: cap.displayName)
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

        let label = UILabel()
        label.text = "Tap any element to capture it"
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false

        let close = UIButton(type: .system)
        close.setTitle("✕", for: .normal)
        close.setTitleColor(UIColor.white.withAlphaComponent(0.7), for: .normal)
        close.titleLabel?.font = .systemFont(ofSize: 16)
        close.translatesAutoresizingMaskIntoConstraints = false
        close.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        pill.addSubview(label)
        pill.addSubview(close)
        parent.addSubview(pill)

        NSLayoutConstraint.activate([
            pill.topAnchor.constraint(equalTo: parent.safeAreaLayoutGuide.topAnchor, constant: 12),
            pill.leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: 16),
            pill.trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -16),
            pill.heightAnchor.constraint(equalToConstant: 48),

            label.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 16),
            label.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
            label.trailingAnchor.constraint(equalTo: close.leadingAnchor, constant: -8),

            close.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -12),
            close.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
            close.widthAnchor.constraint(equalToConstant: 36),
        ])

        pill.alpha = 0
        UIView.animate(withDuration: 0.3) { pill.alpha = 1 }
        closeButton = close
    }

    // MARK: - Tap handling

    private func handleTap(at point: CGPoint, in window: UIWindow) {
        guard state.phase == .tapping else { return }

        let screenPoint = window.convert(point, to: nil)
        let (identifier, displayName) = identifyView(at: screenPoint)

        // Show confirm card — enable SwiftUI layer for button interaction
        state.captured = TTCapturedElement(identifier: identifier, displayName: displayName)
        state.phase = .confirming
        tapView?.isUserInteractionEnabled = false
        tapView?.backgroundColor = .clear
        hostingController?.view.isUserInteractionEnabled = true
    }

    private func retryCapture() {
        state.captured = nil
        state.phase = .tapping
        tapView?.isUserInteractionEnabled = true
        tapView?.backgroundColor = UIColor(red: 0, green: 0, blue: 1, alpha: 0.04)
        hostingController?.view.isUserInteractionEnabled = false
    }

    // MARK: - Element identification

    private func identifyView(at screenPoint: CGPoint) -> (identifier: String, displayName: String) {
        guard let appWindow = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { !($0 is TTInspectorWindow) && !($0 is TTOverlayWindow) })
        else { return ("unknown", "Unknown element") }

        let localPoint = appWindow.convert(screenPoint, from: nil)
        let hitView = appWindow.hitTest(localPoint, with: nil)

        // Walk UP the hierarchy — SwiftUI sets accessibilityIdentifier on internal
        // container views (PlatformGroupContainer etc.), so keep going up until we
        // find a meaningful identifier, label, or text content.
        var view: UIView? = hitView
        while let v = view {
            let cls = String(describing: type(of: v))
            let isInternalContainer = cls.contains("Platform") || cls.contains("Hosting") || cls.contains("_UI")

            if let id = v.accessibilityIdentifier, !id.isEmpty, !isInternalContainer {
                return (id, id)
            }
            // Accept accessibilityIdentifier even on containers as last resort
            if let id = v.accessibilityIdentifier, !id.isEmpty {
                return (id, id)
            }
            if let lbl = v.accessibilityLabel, !lbl.isEmpty, !isInternalContainer {
                let safe = safe(lbl)
                return (safe, lbl)
            }
            if let l = v as? UILabel, let t = l.text, !t.isEmpty {
                return (safe(t), t)
            }
            if let b = v as? UIButton, let t = b.title(for: .normal), !t.isEmpty {
                return (safe(t), t)
            }
            view = v.superview
        }

        // Fallback: first sibling or parent with a real identifier
        var search: UIView? = hitView?.superview
        while let v = search {
            for sub in v.subviews {
                if let id = sub.accessibilityIdentifier, !id.isEmpty {
                    return (id, id)
                }
            }
            search = v.superview
        }

        let cls = String(describing: type(of: hitView as AnyObject))
        return (cls, cls)
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

struct TTCapturedElement { let identifier: String; let displayName: String }

@MainActor
final class TTInspectorState: ObservableObject {
    @Published var phase: TTInspectorPhase = .tapping
    @Published var captured: TTCapturedElement? = nil
}

// MARK: - TTInspectorWindow / TTTapInterceptorView

final class TTInspectorWindow: UIWindow {}

final class TTTapInterceptorView: UIView {
    var onTap: ((CGPoint) -> Void)?
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        onTap?(touch.location(in: self))
    }
}

// MARK: - SwiftUI confirm card overlay (shown only during confirming/done)

struct TTInspectorOverlayView: View {
    @ObservedObject var state: TTInspectorState
    let onRetry: () -> Void
    let onAccept: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear
            if (state.phase == .confirming || state.phase == .done), let cap = state.captured {
                TTConfirmCard(
                    displayName: cap.displayName,
                    identifier: cap.identifier,
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
    let displayName: String
    let identifier: String
    let isDone: Bool
    let onRetry: () -> Void
    let onAccept: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isDone ? "Sent to dashboard ✓" : "Captured")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundColor(Color(red: 0.098, green: 0.145, blue: 0.667).opacity(0.65))
                Text(displayName)
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(Color(red: 0.051, green: 0.039, blue: 0.11))
                    .lineLimit(1)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(identifier)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(Color(red: 0.098, green: 0.145, blue: 0.667))
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 0.098, green: 0.145, blue: 0.667).opacity(0.06))

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
                    Button(action: onAccept) {
                        Text("Use this →")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.5)
                            .textCase(.uppercase)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .foregroundColor(.white)
                            .background(Color(red: 0.098, green: 0.145, blue: 0.667))
                    }
                }
            }
        }
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 8)
    }
}
