import UIKit
import SwiftUI

/// Manages a single active walkthrough — overlay window, step progression, events.
@MainActor
final class TTWalkthroughSession {

    private let config: TTConfig
    private let siteKey: String
    private let tracker: TTEventTracker

    var onEnd: (() -> Void)?

    private var currentStep = 0
    private var overlayWindow: UIWindow?
    private var spotlightView: TTSpotlightView?
    private var beacon: TTBeaconView?           // single beacon, repositioned per step
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
        onEnd?()
    }

    // MARK: - Setup

    private func setupOverlayWindow() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else { return }

        let window = TTOverlayWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.backgroundColor = .clear
        window.isUserInteractionEnabled = true

        let root = UIViewController()
        root.view.backgroundColor = .clear
        window.rootViewController = root
        window.makeKeyAndVisible()
        overlayWindow = window

        // Spotlight
        let spotlight = TTSpotlightView(frame: window.bounds)
        spotlight.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        spotlight.isUserInteractionEnabled = false
        root.view.addSubview(spotlight)
        spotlightView = spotlight

        // Single beacon — hidden until first step is ready
        let style: TTBeaconView.Style = {
            switch config.styles?.beacon?.style {
            case "dot":  return .dot
            case "ring": return .ring
            default:     return .numbered
            }
        }()
        let size = TTBeaconView.size(for: style)
        let b = TTBeaconView(frame: CGRect(x: 0, y: 0, width: size, height: size))
        b.beaconStyle = style
        b.color       = config.styles?.resolvedBeaconBgColor   ?? .systemIndigo
        b.labelColor  = config.styles?.resolvedBeaconTextColor ?? .white
        b.isActive    = true
        b.alpha       = 0      // hidden until positioned
        root.view.addSubview(b)
        beacon = b
    }

    // MARK: - Step progression

    private func showStep(_ index: Int) {
        guard index < config.steps.count else {
            complete()
            return
        }
        currentStep = index
        let step = config.steps[index]

        tracker.track(event: .stepViewed, walkthroughId: config.id, siteKey: siteKey, stepIndex: index)

        // 1. Scroll target into view (SwiftUI bus), then
        // 2. Re-measure frame and place beacon + card at the correct position
        scrollIntoViewIfNeeded(identifier: step.selector) { [weak self] in
            guard let self else { return }
            let frame = self.findTargetFrame(identifier: step.selector)
            self.placeBeacon(stepNumber: index + 1, targetFrame: frame)
            self.updateSpotlight(frame: frame)
            self.updateCard(step: step, index: index, beaconFrame: self.beacon?.frame ?? .zero)
        }
    }

    // MARK: - Scroll

    private func scrollIntoViewIfNeeded(identifier: String, completion: @escaping () -> Void) {
        let alreadyVisible: Bool = {
            guard
                let appWindow = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .flatMap({ $0.windows })
                    .first(where: { !($0 is TTOverlayWindow) }),
                let target = appWindow.findSubview(withIdentifier: identifier)
            else { return false }
            let frameInWindow = target.convert(target.bounds, to: appWindow)
            return appWindow.safeAreaLayoutGuide.layoutFrame.intersects(frameInWindow)
        }()

        if alreadyVisible {
            completion()
            return
        }

        TTScrollBus.shared.scrollTo(identifier)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { completion() }
    }

    // MARK: - Beacon

    /// Move the single beacon to sit on the target frame, updating its step number.
    private func placeBeacon(stepNumber: Int, targetFrame: CGRect) {
        guard let beacon, targetFrame != .zero else { return }

        let ww = overlayWindow?.bounds.width  ?? UIScreen.main.bounds.width
        let wh = overlayWindow?.bounds.height ?? UIScreen.main.bounds.height
        let sz = TTBeaconView.size(for: beacon.beaconStyle)

        let cx = targetFrame.maxX - 15
        let cy = targetFrame.midY
        let x  = min(max(cx - sz / 2, 4), ww - sz - 4)
        let y  = min(max(cy - sz / 2, 4), wh - sz - 4)

        beacon.stepNumber = stepNumber

        UIView.animate(withDuration: 0.25) {
            beacon.frame = CGRect(x: x, y: y, width: sz, height: sz)
            beacon.alpha = 1
        }
    }

    // MARK: - Spotlight

    private func updateSpotlight(frame: CGRect) {
        let animated = currentStep > 0
        if animated {
            UIView.animate(withDuration: 0.3) { self.spotlightView?.highlightRect = frame }
        } else {
            spotlightView?.highlightRect = frame
        }
    }

    // MARK: - Step card

    private func updateCard(step: TTStep, index: Int, beaconFrame: CGRect) {
        guard let root = overlayWindow?.rootViewController else { return }

        let card = TTStepCardView(
            step: step,
            stepIndex: index,
            totalSteps: config.steps.count,
            styles: config.styles,
            onNext:    { [weak self] in self?.showStep((self?.currentStep ?? 0) + 1) },
            onBack:    { [weak self] in self?.showStep((self?.currentStep ?? 0) - 1) },
            onDismiss: { [weak self] in self?.dismiss() }
        )

        if let old = cardHostingController {
            old.willMove(toParent: nil)
            old.view.removeFromSuperview()
            old.removeFromParent()
            cardHostingController = nil
        }

        let hc = UIHostingController(rootView: AnyView(card))
        hc.view.backgroundColor = .clear
        root.addChild(hc)
        root.view.addSubview(hc.view)
        hc.didMove(toParent: root)
        cardHostingController = hc

        hc.view.translatesAutoresizingMaskIntoConstraints = false

        let windowHeight = overlayWindow?.bounds.height ?? UIScreen.main.bounds.height
        let cardGap: CGFloat  = 30
        let cardTop           = beaconFrame.maxY + cardGap
        let flipAbove         = cardTop + 200 > windowHeight - 40

        var constraints: [NSLayoutConstraint] = [
            hc.view.leadingAnchor.constraint(equalTo: root.view.leadingAnchor,   constant: 20),
            hc.view.trailingAnchor.constraint(equalTo: root.view.trailingAnchor, constant: -20),
        ]
        if flipAbove {
            constraints.append(
                hc.view.bottomAnchor.constraint(equalTo: root.view.topAnchor,
                                                constant: beaconFrame.minY - cardGap)
            )
        } else {
            constraints.append(
                hc.view.topAnchor.constraint(equalTo: root.view.topAnchor, constant: cardTop)
            )
        }
        NSLayoutConstraint.activate(constraints)
    }

    // MARK: - Finish / teardown

    private func complete() {
        tracker.track(event: .guideCompleted, walkthroughId: config.id, siteKey: siteKey)
        UserDefaults.standard.set(true, forKey: "tt-completed-\(config.id)")
        tearDown()
        onEnd?()
    }

    private func tearDown() {
        UIView.animate(withDuration: 0.2, animations: {
            self.overlayWindow?.alpha = 0
        }, completion: { _ in
            self.overlayWindow?.isHidden = true
            self.overlayWindow = nil
            self.spotlightView = nil
            self.beacon = nil
            self.cardHostingController = nil
        })
    }

    // MARK: - View finding

    private func findTargetFrame(identifier: String) -> CGRect {
        if let appWindow = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { !($0 is TTOverlayWindow) }),
           let target = appWindow.findSubview(withIdentifier: identifier),
           let overlayWindow {
            return target.convert(target.bounds, to: overlayWindow)
        }
        return TTViewRegistry.shared.frame(for: identifier) ?? .zero
    }
}

// MARK: - TTOverlayWindow

final class TTOverlayWindow: UIWindow {}

// MARK: - UIView traversal

extension UIView {
    func findSubview(withIdentifier id: String) -> UIView? {
        if accessibilityIdentifier == id { return self }
        if let elements = accessibilityElements {
            for element in elements {
                if let view = element as? UIView,
                   let found = view.findSubview(withIdentifier: id) {
                    return found
                }
            }
        }
        for sub in subviews {
            if let found = sub.findSubview(withIdentifier: id) { return found }
        }
        return nil
    }
}
