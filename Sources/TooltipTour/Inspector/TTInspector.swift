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
    private var tapInterceptor: TTTapInterceptorView?
    private var confirmHostingController: UIHostingController<AnyView>?

    init(sessionId: String, networkClient: TTNetworkClient) {
        self.sessionId     = sessionId
        self.networkClient = networkClient
    }

    // MARK: - Start

    func start() {
        setupOverlayWindow()
        showBanner()
        installTapInterceptor()
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

        let root = UIViewController()
        root.view.backgroundColor = .clear
        window.rootViewController = root
        window.makeKeyAndVisible()
        overlayWindow = window
    }

    // MARK: - Banner

    private func showBanner() {
        guard let root = overlayWindow?.rootViewController else { return }

        let banner = UIView()
        banner.backgroundColor = UIColor(red: 0.098, green: 0.145, blue: 0.667, alpha: 1) // #1925AA
        banner.translatesAutoresizingMaskIntoConstraints = false
        banner.layer.cornerRadius = 10
        banner.layer.shadowColor = UIColor.black.cgColor
        banner.layer.shadowOpacity = 0.25
        banner.layer.shadowOffset = CGSize(width: 0, height: 4)
        banner.layer.shadowRadius = 12

        let label = UILabel()
        label.text = "Tap any element to capture it"
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false

        let closeBtn = UIButton(type: .system)
        closeBtn.setTitle("✕", for: .normal)
        closeBtn.setTitleColor(UIColor.white.withAlphaComponent(0.7), for: .normal)
        closeBtn.titleLabel?.font = .systemFont(ofSize: 16, weight: .regular)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        closeBtn.addTarget(self, action: #selector(cancelInspector), for: .touchUpInside)

        banner.addSubview(label)
        banner.addSubview(closeBtn)
        root.view.addSubview(banner)

        NSLayoutConstraint.activate([
            banner.topAnchor.constraint(equalTo: root.view.safeAreaLayoutGuide.topAnchor, constant: 12),
            banner.leadingAnchor.constraint(equalTo: root.view.leadingAnchor, constant: 16),
            banner.trailingAnchor.constraint(equalTo: root.view.trailingAnchor, constant: -16),
            banner.heightAnchor.constraint(equalToConstant: 48),

            label.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 16),
            label.centerYAnchor.constraint(equalTo: banner.centerYAnchor),
            label.trailingAnchor.constraint(equalTo: closeBtn.leadingAnchor, constant: -8),

            closeBtn.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -12),
            closeBtn.centerYAnchor.constraint(equalTo: banner.centerYAnchor),
            closeBtn.widthAnchor.constraint(equalToConstant: 36),
        ])

        banner.alpha = 0
        UIView.animate(withDuration: 0.3) { banner.alpha = 1 }
    }

    // MARK: - Tap interceptor

    private func installTapInterceptor() {
        guard let root = overlayWindow?.rootViewController else { return }

        let interceptor = TTTapInterceptorView(frame: root.view.bounds)
        interceptor.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        interceptor.backgroundColor = UIColor.blue.withAlphaComponent(0.05)
        interceptor.onTap = { [weak self] point in
            self?.handleTap(at: point)
        }
        root.view.addSubview(interceptor)
        // Keep interceptor below the banner (banner was added first, so just insert below top)
        root.view.sendSubviewToBack(interceptor)
        tapInterceptor = interceptor
    }

    private func removeTapInterceptor() {
        tapInterceptor?.removeFromSuperview()
        tapInterceptor = nil
    }

    // MARK: - Tap handling

    private func handleTap(at point: CGPoint) {
        guard let overlayWindow else { return }

        // Convert point from overlay window → screen → app window
        let screenPoint = overlayWindow.convert(point, to: nil)
        let (identifier, displayName) = identifyView(at: screenPoint)

        removeTapInterceptor()
        showConfirmCard(identifier: identifier, displayName: displayName)
    }

    // MARK: - Element identification

    /// Walk the app window's view hierarchy to find the deepest tapped view,
    /// then extract the best available identifier.
    private func identifyView(at screenPoint: CGPoint) -> (identifier: String, displayName: String) {
        guard let appWindow = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { !($0 is TTInspectorWindow) && !($0 is TTOverlayWindow) })
        else { return ("unknown", "Unknown element") }

        let localPoint = appWindow.convert(screenPoint, from: nil)
        let hitView = appWindow.hitTest(localPoint, with: nil)

        // Walk up the hierarchy looking for the first useful identifier
        var view: UIView? = hitView
        while let v = view {
            // 1. Explicit accessibilityIdentifier
            if let id = v.accessibilityIdentifier, !id.isEmpty {
                return (id, id)
            }
            // 2. Accessibility label
            if let label = v.accessibilityLabel, !label.isEmpty {
                let safe = label.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: " ", with: "-")
                    .lowercased()
                return (safe, label)
            }
            // 3. UILabel text
            if let lbl = v as? UILabel, let text = lbl.text, !text.isEmpty {
                let safe = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: " ", with: "-")
                    .lowercased()
                return (safe, text)
            }
            // 4. UIButton title
            if let btn = v as? UIButton, let text = btn.title(for: .normal), !text.isEmpty {
                let safe = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: " ", with: "-")
                    .lowercased()
                return (safe, text)
            }
            view = v.superview
        }

        // Fallback: class name + position
        let className = String(describing: type(of: hitView as AnyObject))
        return (className, className)
    }

    // MARK: - Confirmation card

    private func showConfirmCard(identifier: String, displayName: String) {
        guard let root = overlayWindow?.rootViewController else { return }

        let card = TTInspectorConfirmView(
            displayName: displayName,
            identifier: identifier,
            onAccept: { [weak self] in
                self?.submitCapture(identifier: identifier, displayName: displayName)
            },
            onRetry: { [weak self] in
                self?.dismissConfirmCard()
                self?.installTapInterceptor()
            }
        )

        let hc = UIHostingController(rootView: AnyView(card))
        hc.view.backgroundColor = .clear
        root.addChild(hc)
        root.view.addSubview(hc.view)
        hc.didMove(toParent: root)
        confirmHostingController = hc

        hc.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hc.view.leadingAnchor.constraint(equalTo: root.view.leadingAnchor, constant: 16),
            hc.view.trailingAnchor.constraint(equalTo: root.view.trailingAnchor, constant: -16),
            hc.view.centerYAnchor.constraint(equalTo: root.view.centerYAnchor),
        ])
    }

    private func dismissConfirmCard() {
        confirmHostingController?.willMove(toParent: nil)
        confirmHostingController?.view.removeFromSuperview()
        confirmHostingController?.removeFromParent()
        confirmHostingController = nil
    }

    // MARK: - Submit

    private func submitCapture(identifier: String, displayName: String) {
        Task {
            try? await networkClient.updateInspectorSession(
                id: sessionId,
                identifier: identifier,
                displayName: displayName
            )
            await MainActor.run { tearDown() }
        }
    }

    // MARK: - Tear down

    @objc private func cancelInspector() {
        tearDown()
    }

    private func tearDown() {
        UIView.animate(withDuration: 0.25, animations: {
            self.overlayWindow?.alpha = 0
        }, completion: { _ in
            self.overlayWindow?.isHidden = true
            self.overlayWindow = nil
            self.tapInterceptor = nil
            self.confirmHostingController = nil
            self.onEnd?()
        })
    }
}

// MARK: - TTInspectorWindow

final class TTInspectorWindow: UIWindow {}

// MARK: - TTTapInterceptorView

/// Full-screen transparent view that intercepts the first tap.
final class TTTapInterceptorView: UIView {
    var onTap: ((CGPoint) -> Void)?

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        onTap?(touch.location(in: self))
    }
}

// MARK: - TTInspectorConfirmView

struct TTInspectorConfirmView: View {
    let displayName: String
    let identifier: String
    let onAccept: () -> Void
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Element captured")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundColor(Color(red: 0.098, green: 0.145, blue: 0.667).opacity(0.7))
                Text(displayName)
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(Color(red: 0.051, green: 0.039, blue: 0.11))
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 0.098, green: 0.145, blue: 0.667).opacity(0.06))

            // Identifier pill
            HStack {
                Text(identifier)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(red: 0.098, green: 0.145, blue: 0.667))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(red: 0.098, green: 0.145, blue: 0.667).opacity(0.06))

            // Buttons
            HStack(spacing: 0) {
                Button(action: onRetry) {
                    Text("Retry")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.5)
                        .textCase(.uppercase)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .foregroundColor(Color(red: 0.051, green: 0.039, blue: 0.11).opacity(0.45))
                .background(Color(red: 0.051, green: 0.039, blue: 0.11).opacity(0.05))

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
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.2), radius: 24, x: 0, y: 8)
    }
}
