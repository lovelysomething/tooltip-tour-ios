import UIKit
import SwiftUI

// MARK: - TTInspector

/// Overlay inspector: tap any element → capture its identifier → send to dashboard.
@MainActor
final class TTInspector {

    private let sessionId: String
    private let networkClient: TTNetworkClient

    var onEnd: (() -> Void)?

    private var overlayWindow: TTInspectorWindow?
    private var hostingController: UIHostingController<AnyView>?
    private var tapOverlayView: TTTapInterceptorView?

    // Published state driven by SwiftUI overlay
    private var state: TTInspectorState = TTInspectorState()

    init(sessionId: String, networkClient: TTNetworkClient) {
        self.sessionId     = sessionId
        self.networkClient = networkClient
    }

    // MARK: - Start

    func start() {
        setupOverlayWindow()
    }

    // MARK: - Window

    private func setupOverlayWindow() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else { return }

        let window = TTInspectorWindow(windowScene: scene)
        window.windowLevel = .alert + 2
        window.backgroundColor = .clear
        window.isUserInteractionEnabled = true

        // Root VC with clear background
        let root = UIViewController()
        root.view.backgroundColor = .clear
        window.rootViewController = root
        window.makeKeyAndVisible()
        overlayWindow = window

        // Full-screen tap interceptor (gets touches, forwards to handler)
        let tapper = TTTapInterceptorView(frame: window.bounds)
        tapper.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tapper.backgroundColor = UIColor.blue.withAlphaComponent(0.04)
        tapper.onTap = { [weak self] point in
            self?.handleTap(at: point, in: window)
        }
        root.view.addSubview(tapper)
        tapOverlayView = tapper

        // SwiftUI overlay (banner + confirm card) on top
        let overlayView = TTInspectorOverlayView(
            state: state,
            onCancel: { [weak self] in self?.tearDown() },
            onRetry: { [weak self] in self?.retryCapture() },
            onAccept: { [weak self] in
                guard let self, let cap = self.state.captured else { return }
                self.submitCapture(identifier: cap.identifier, displayName: cap.displayName)
            }
        )
        let hc = UIHostingController(rootView: AnyView(overlayView))
        hc.view.backgroundColor = .clear
        root.addChild(hc)
        hc.view.frame = root.view.bounds
        hc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hc.view.isUserInteractionEnabled = true
        root.view.addSubview(hc.view)
        hc.didMove(toParent: root)
        hostingController = hc
    }

    // MARK: - Tap handling

    private func handleTap(at point: CGPoint, in window: UIWindow) {
        guard state.phase == .tapping else { return }

        let screenPoint = window.convert(point, to: nil)
        let (identifier, displayName) = identifyView(at: screenPoint)

        state.captured = TTCapturedElement(identifier: identifier, displayName: displayName)
        state.phase = .confirming
        tapOverlayView?.isUserInteractionEnabled = false
        tapOverlayView?.backgroundColor = .clear
    }

    private func retryCapture() {
        state.captured = nil
        state.phase = .tapping
        tapOverlayView?.isUserInteractionEnabled = true
        tapOverlayView?.backgroundColor = UIColor.blue.withAlphaComponent(0.04)
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

        var view: UIView? = hitView
        while let v = view {
            if let id = v.accessibilityIdentifier, !id.isEmpty {
                return (id, id)
            }
            if let label = v.accessibilityLabel, !label.isEmpty {
                let safe = label.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: " ", with: "-").lowercased()
                return (safe, label)
            }
            if let lbl = v as? UILabel, let text = lbl.text, !text.isEmpty {
                let safe = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: " ", with: "-").lowercased()
                return (safe, text)
            }
            if let btn = v as? UIButton, let text = btn.title(for: .normal), !text.isEmpty {
                let safe = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: " ", with: "-").lowercased()
                return (safe, text)
            }
            view = v.superview
        }

        let className = String(describing: type(of: hitView as AnyObject))
        return (className, className)
    }

    // MARK: - Submit

    private func submitCapture(identifier: String, displayName: String) {
        state.phase = .done
        Task {
            try? await networkClient.updateInspectorSession(
                id: sessionId,
                identifier: identifier,
                displayName: displayName
            )
            try? await Task.sleep(nanoseconds: 1_200_000_000) // 1.2s to show success
            await MainActor.run { tearDown() }
        }
    }

    // MARK: - Tear down

    private func tearDown() {
        UIView.animate(withDuration: 0.25, animations: {
            self.overlayWindow?.alpha = 0
        }, completion: { _ in
            self.overlayWindow?.isHidden = true
            self.overlayWindow = nil
            self.hostingController = nil
            self.tapOverlayView = nil
            self.onEnd?()
        })
    }
}

// MARK: - State

enum TTInspectorPhase { case tapping, confirming, done }

struct TTCapturedElement {
    let identifier: String
    let displayName: String
}

@MainActor
final class TTInspectorState: ObservableObject {
    @Published var phase: TTInspectorPhase = .tapping
    @Published var captured: TTCapturedElement? = nil
}

// MARK: - TTInspectorWindow

final class TTInspectorWindow: UIWindow {}

// MARK: - TTTapInterceptorView

final class TTTapInterceptorView: UIView {
    var onTap: ((CGPoint) -> Void)?
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        onTap?(touch.location(in: self))
    }
}

// MARK: - TTInspectorOverlayView

struct TTInspectorOverlayView: View {
    @ObservedObject var state: TTInspectorState
    let onCancel: () -> Void
    let onRetry: () -> Void
    let onAccept: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear

            VStack {
                // Banner
                HStack {
                    Text(state.phase == .tapping ? "Tap any element to capture it" : "Element captured")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: onCancel) {
                        Text("✕")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(red: 0.098, green: 0.145, blue: 0.667))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 4)
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Spacer()

                // Confirm card
                if state.phase == .confirming || state.phase == .done, let cap = state.captured {
                    TTInspectorConfirmCard(
                        displayName: cap.displayName,
                        identifier: cap.identifier,
                        isDone: state.phase == .done,
                        onRetry: onRetry,
                        onAccept: onAccept
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .allowsHitTesting(state.phase != .tapping) // let taps through when in tapping mode except banner
        .overlay(alignment: .top) {
            if state.phase == .tapping {
                Color.clear
                    .frame(height: 80)
                    .allowsHitTesting(false)
                    // Banner area needs to allow its own button hits
            }
        }
    }
}

// MARK: - TTInspectorConfirmCard

struct TTInspectorConfirmCard: View {
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
                    }
                    .foregroundColor(Color(red: 0.051, green: 0.039, blue: 0.11).opacity(0.4))

                    Button(action: onAccept) {
                        Text("Use this →")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.5)
                            .textCase(.uppercase)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .foregroundColor(.white)
                    .background(Color(red: 0.098, green: 0.145, blue: 0.667))
                }
            }
        }
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 8)
    }
}
