import UIKit
import SwiftUI

/// Manages a single active walkthrough — overlay window, step progression, events.
@MainActor
final class TTWalkthroughSession {

    private let config: TTConfig
    private let siteKey: String
    private let tracker: TTEventTracker

    private var currentStep = 0
    private var overlayWindow: UIWindow?
    private var spotlightView: TTSpotlightView?
    private var beaconView: TTBeaconView?
    private var cardHostingController: UIHostingController<AnyView>?

    init(config: TTConfig, siteKey: String, tracker: TTEventTracker) {
        self.config  = config
        self.siteKey = siteKey
        self.tracker = tracker
    }

    func start() {
        guard !config.steps.isEmpty else { return }
        setupOverlayWindow()
        tracker.track(event: .guideShown, walkthroughId: config.id, siteKey: siteKey)
        showStep(0)
    }

    func dismiss() {
        tracker.track(event: .guideDismissed, walkthroughId: config.id, siteKey: siteKey, stepIndex: currentStep)
        tearDown()
    }

    // MARK: - Private

    private func setupOverlayWindow() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else { return }

        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.backgroundColor = .clear
        window.isUserInteractionEnabled = true

        let root = UIViewController()
        root.view.backgroundColor = .clear
        window.rootViewController = root
        window.makeKeyAndVisible()
        overlayWindow = window

        let spotlight = TTSpotlightView(frame: window.bounds)
        spotlight.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        spotlight.isUserInteractionEnabled = false
        root.view.addSubview(spotlight)
        spotlightView = spotlight

        let beacon = TTBeaconView(frame: .zero)
        beacon.isUserInteractionEnabled = false
        root.view.addSubview(beacon)
        beaconView = beacon
    }

    private func showStep(_ index: Int) {
        guard index < config.steps.count else {
            complete()
            return
        }
        currentStep = index
        let step = config.steps[index]

        tracker.track(event: .stepCompleted, walkthroughId: config.id, siteKey: siteKey, stepIndex: index)

        // Find the target view in the app's window hierarchy
        let targetFrame = findTargetFrame(identifier: step.selector)
        updateSpotlight(frame: targetFrame)
        updateCard(step: step, index: index)
    }

    private func complete() {
        tracker.track(event: .guideCompleted, walkthroughId: config.id, siteKey: siteKey)
        tearDown()
    }

    private func tearDown() {
        UIView.animate(withDuration: 0.2, animations: {
            self.overlayWindow?.alpha = 0
        }, completion: { _ in
            self.overlayWindow?.isHidden = true
            self.overlayWindow = nil
            self.spotlightView = nil
            self.beaconView = nil
            self.cardHostingController = nil
        })
    }

    private func findTargetFrame(identifier: String) -> CGRect {
        guard let appWindow = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { !($0 is TTOverlayWindowMarker) }),
              let target = appWindow.findSubview(withIdentifier: identifier),
              let overlayWindow
        else { return .zero }

        let frame = target.convert(target.bounds, to: overlayWindow)
        return frame
    }

    private func updateSpotlight(frame: CGRect) {
        guard let overlayWindow else { return }
        let animated = currentStep > 0

        let update = { [weak self] in
            self?.spotlightView?.highlightRect = frame
            if frame != .zero, let beacon = self?.beaconView {
                let inset: CGFloat = -14
                beacon.frame = frame.insetBy(dx: inset, dy: inset)
                beacon.layer.cornerRadius = beacon.bounds.width / 2
            } else {
                self?.beaconView?.frame = .zero
            }
        }

        if animated {
            UIView.animate(withDuration: 0.3, animations: update)
        } else {
            update()
        }
    }

    private func updateCard(step: TTStep, index: Int) {
        guard let root = overlayWindow?.rootViewController else { return }
        let primaryColor = Color(config.styles?.resolvedPrimaryColor ?? UIColor(red: 0.098, green: 0.145, blue: 0.667, alpha: 1))

        let card = TTStepCardView(
            step: step,
            stepIndex: index,
            totalSteps: config.steps.count,
            primaryColor: primaryColor,
            onNext: { [weak self] in
                guard let self else { return }
                self.showStep(self.currentStep + 1)
            },
            onBack: { [weak self] in
                guard let self else { return }
                self.showStep(self.currentStep - 1)
            },
            onDismiss: { [weak self] in self?.dismiss() }
        )

        // Remove old card if present
        cardHostingController?.view.removeFromSuperview()
        cardHostingController?.removeFromParent()

        let hc = UIHostingController(rootView: AnyView(card))
        hc.view.backgroundColor = .clear
        root.addChild(hc)
        root.view.addSubview(hc.view)
        hc.didMove(toParent: root)
        cardHostingController = hc

        // Position card at bottom of screen
        hc.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hc.view.leadingAnchor.constraint(equalTo: root.view.leadingAnchor),
            hc.view.trailingAnchor.constraint(equalTo: root.view.trailingAnchor),
            hc.view.bottomAnchor.constraint(equalTo: root.view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
        ])
    }
}

// Marker protocol to distinguish the overlay window from app windows
protocol TTOverlayWindowMarker {}
extension UIWindow: TTOverlayWindowMarker {}

// UIView helper to find subviews by accessibilityIdentifier
extension UIView {
    func findSubview(withIdentifier id: String) -> UIView? {
        if accessibilityIdentifier == id { return self }
        for sub in subviews {
            if let found = sub.findSubview(withIdentifier: id) { return found }
        }
        return nil
    }
}
