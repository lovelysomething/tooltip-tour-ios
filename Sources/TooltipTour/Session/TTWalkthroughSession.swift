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
    private var beaconViews: [TTBeaconView] = []
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

    // MARK: - Private

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

        // Spotlight (dark overlay with cutout) — non-interactive
        let spotlight = TTSpotlightView(frame: window.bounds)
        spotlight.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        spotlight.isUserInteractionEnabled = false
        root.view.addSubview(spotlight)
        spotlightView = spotlight

        // Resolve beacon style from config
        let resolvedStyle: TTBeaconView.Style = {
            switch config.styles?.beacon?.style {
            case "dot":  return .dot
            case "ring": return .ring
            default:     return .numbered
            }
        }()
        let beaconBg    = config.styles?.resolvedBeaconBgColor   ?? .systemIndigo
        let beaconText  = config.styles?.resolvedBeaconTextColor ?? .white
        let beaconSize  = TTBeaconView.size(for: resolvedStyle)

        // Create one beacon per step, all positioned immediately
        for (i, step) in config.steps.enumerated() {
            let frame = findTargetFrame(identifier: step.selector)
            guard frame != .zero else { continue }

            let windowWidth  = overlayWindow?.bounds.width  ?? UIScreen.main.bounds.width
            let windowHeight = overlayWindow?.bounds.height ?? UIScreen.main.bounds.height

            // Beacon: 15 pt inset from right edge of target, vertically centred on target
            let beaconCenterX = frame.maxX - 15
            let beaconCenterY = frame.midY
            let rawX = beaconCenterX - beaconSize / 2
            let rawY = beaconCenterY - beaconSize / 2
            let clampedX = min(max(rawX, 4), windowWidth  - beaconSize - 4)
            let clampedY = min(max(rawY, 4), windowHeight - beaconSize - 4)

            let beacon = TTBeaconView(frame: CGRect(
                x: clampedX,
                y: clampedY,
                width: beaconSize,
                height: beaconSize
            ))
            beacon.beaconStyle  = resolvedStyle
            beacon.color        = beaconBg
            beacon.labelColor   = beaconText
            beacon.stepNumber   = i + 1
            beacon.isActive     = (i == 0)
            beacon.alpha        = i == 0 ? 1.0 : 0.5

            let stepIndex = i
            beacon.onTap = { [weak self] in
                guard let self else { return }
                self.showStep(stepIndex)
            }

            root.view.addSubview(beacon)
            beaconViews.append(beacon)
        }
    }

    private func showStep(_ index: Int) {
        guard index < config.steps.count else {
            complete()
            return
        }
        currentStep = index
        let step = config.steps[index]

        tracker.track(event: .stepCompleted, walkthroughId: config.id, siteKey: siteKey, stepIndex: index)

        // Scroll the target into view, then update UI with the fresh post-scroll frame
        scrollIntoViewIfNeeded(identifier: step.selector) { [weak self] in
            guard let self else { return }
            let targetFrame = self.findTargetFrame(identifier: step.selector)
            self.repositionBeacon(at: index, targetFrame: targetFrame)
            self.updateSpotlight(frame: targetFrame)
            self.updateBeaconActive(index: index)
            self.updateCard(step: step, index: index)
        }
    }

    // MARK: - Scroll to target

    /// Walks up the view hierarchy from the target to find a UIScrollView.
    /// If found and the target isn't fully visible, scrolls it in with animation
    /// and calls completion after the animation (≈0.4 s). Otherwise calls immediately.
    private func scrollIntoViewIfNeeded(identifier: String, completion: @escaping () -> Void) {
        guard
            let appWindow = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: { !($0 is TTOverlayWindow) }),
            let target = appWindow.findSubview(withIdentifier: identifier)
        else { completion(); return }

        // Walk up to the nearest ancestor UIScrollView
        var scrollView: UIScrollView?
        var cursor: UIView? = target.superview
        while let v = cursor {
            if let sv = v as? UIScrollView { scrollView = sv; break }
            cursor = v.superview
        }

        guard let sv = scrollView else { completion(); return }

        let rectInScrollView = target.convert(target.bounds, to: sv)
        let visibleRect = CGRect(
            x: sv.contentOffset.x,
            y: sv.contentOffset.y,
            width:  sv.bounds.width,
            height: sv.bounds.height - sv.adjustedContentInset.bottom
        )

        guard !visibleRect.contains(rectInScrollView) else {
            // Already fully visible — no scroll needed
            completion()
            return
        }

        // Add generous padding so the element isn't flush against the edge
        let padded = rectInScrollView.insetBy(dx: -24, dy: -100)
        sv.scrollRectToVisible(padded, animated: true)

        // Wait for the default UIScrollView animation (0.3 s) + a small buffer
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) { completion() }
    }

    // MARK: - Reposition beacon after scroll

    private func repositionBeacon(at index: Int, targetFrame: CGRect) {
        guard index < beaconViews.count, targetFrame != .zero else { return }

        let windowWidth  = overlayWindow?.bounds.width  ?? UIScreen.main.bounds.width
        let windowHeight = overlayWindow?.bounds.height ?? UIScreen.main.bounds.height
        let beacon       = beaconViews[index]
        let beaconSize   = TTBeaconView.size(for: beacon.beaconStyle)

        let cx = targetFrame.maxX - 15
        let cy = targetFrame.midY
        let x  = min(max(cx - beaconSize / 2, 4), windowWidth  - beaconSize - 4)
        let y  = min(max(cy - beaconSize / 2, 4), windowHeight - beaconSize - 4)

        UIView.animate(withDuration: 0.25) {
            beacon.frame = CGRect(x: x, y: y, width: beaconSize, height: beaconSize)
        }
    }

    private func complete() {
        tracker.track(event: .guideCompleted, walkthroughId: config.id, siteKey: siteKey)
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
            self.beaconViews = []
            self.cardHostingController = nil
        })
    }

    // MARK: - Spotlight

    private func updateSpotlight(frame: CGRect) {
        let animated = currentStep > 0
        let update = { [weak self] in
            guard let self else { return }
            self.spotlightView?.highlightRect = frame
        }
        if animated {
            UIView.animate(withDuration: 0.3, animations: update)
        } else {
            update()
        }
    }

    // MARK: - Beacons

    private func updateBeaconActive(index: Int) {
        for (i, beacon) in beaconViews.enumerated() {
            beacon.isActive = (i == index)
        }
    }

    // MARK: - Step card

    private func updateCard(step: TTStep, index: Int) {
        guard let root = overlayWindow?.rootViewController else { return }

        let card = TTStepCardView(
            step: step,
            stepIndex: index,
            totalSteps: config.steps.count,
            styles: config.styles,
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

        // Properly tear down old card before creating the new one
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

        // Position card 30 pt below the active beacon.
        // If that would leave less than 180 pt to the screen bottom, flip above.
        let windowHeight  = overlayWindow?.bounds.height ?? UIScreen.main.bounds.height
        let beaconFrame   = index < beaconViews.count ? beaconViews[index].frame : .zero
        let cardGap: CGFloat = 30
        let cardTop       = beaconFrame.maxY + cardGap
        let flipAbove     = cardTop + 200 > windowHeight - 40  // 200 = rough card height estimate

        var constraints: [NSLayoutConstraint] = [
            hc.view.leadingAnchor.constraint(equalTo: root.view.leadingAnchor,  constant: 20),
            hc.view.trailingAnchor.constraint(equalTo: root.view.trailingAnchor, constant: -20),
        ]
        if flipAbove {
            // Card bottom sits 30 pt above the beacon top
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

    // MARK: - View finding

    private func findTargetFrame(identifier: String) -> CGRect {
        // Prefer live UIKit measurement — always reflects post-scroll position.
        // Fall back to SwiftUI registry if the UIKit search comes up empty.
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

/// Subclass used as the overlay window so we can exclude it when searching for app views.
final class TTOverlayWindow: UIWindow {}

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
