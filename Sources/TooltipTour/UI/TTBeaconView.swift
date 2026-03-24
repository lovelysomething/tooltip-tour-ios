import UIKit

/// Step beacon — matches web embed.js exactly (numbered/dot/ring + sonar-ping animation).
final class TTBeaconView: UIView {

    enum Style { case numbered, dot, ring }

    // MARK: Configuration

    var beaconStyle: Style = .numbered {
        didSet { applyStyle(); setNeedsLayout() }
    }
    var color: UIColor = .systemIndigo {
        didSet { applyStyle() }
    }
    var labelColor: UIColor = .white {
        didSet { label.textColor = labelColor }
    }
    var stepNumber: Int = 1 {
        didSet { label.text = "\(stepNumber)" }
    }
    var isActive: Bool = false {
        didSet { updateActiveState() }
    }
    var onTap: (() -> Void)?

    // MARK: Sizes — match web embed.js exactly

    static func size(for style: Style) -> CGFloat {
        switch style {
        case .dot:      return 12
        case .ring:     return 20
        case .numbered: return 32
        }
    }

    // MARK: Private

    private let circleLayer = CALayer()
    private let pulseLayer  = CALayer()   // border-only ring that sonar-pings
    private let label = UILabel()

    // Pulse starts slightly outside the beacon: -4px for numbered, -6px for dot/ring
    private var pulseInset: CGFloat { beaconStyle == .numbered ? -4 : -6 }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        clipsToBounds = false               // allow pulse ring to extend beyond bounds
        isUserInteractionEnabled = true

        // Pulse ring (behind circle)
        pulseLayer.backgroundColor = UIColor.clear.cgColor
        pulseLayer.borderWidth = 2
        layer.addSublayer(pulseLayer)

        // Main circle
        circleLayer.shadowColor  = UIColor.black.cgColor
        circleLayer.shadowOpacity = 0.2
        circleLayer.shadowRadius  = 4
        circleLayer.shadowOffset  = CGSize(width: 0, height: 2)
        layer.addSublayer(circleLayer)

        label.textColor     = .white
        label.font          = .systemFont(ofSize: 13, weight: .bold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)

        applyStyle()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        circleLayer.frame        = bounds
        circleLayer.cornerRadius = bounds.width / 2

        let pi = pulseInset
        pulseLayer.frame        = bounds.insetBy(dx: pi, dy: pi)
        pulseLayer.cornerRadius = pulseLayer.bounds.width / 2
    }

    @objc private func handleTap() { onTap?() }

    // MARK: Style

    private func applyStyle() {
        pulseLayer.removeAllAnimations()
        circleLayer.removeAllAnimations()

        pulseLayer.borderColor = color.cgColor

        switch beaconStyle {
        case .numbered:
            circleLayer.backgroundColor = color.cgColor
            circleLayer.borderColor     = UIColor.clear.cgColor
            circleLayer.borderWidth     = 0
            label.isHidden = false
            label.textColor = labelColor

        case .dot:
            circleLayer.backgroundColor = color.cgColor
            circleLayer.borderColor     = UIColor.clear.cgColor
            circleLayer.borderWidth     = 0
            label.isHidden = true

        case .ring:
            circleLayer.backgroundColor = UIColor.clear.cgColor
            circleLayer.borderColor     = color.cgColor
            circleLayer.borderWidth     = 2
            circleLayer.shadowOpacity   = 0
            label.isHidden = true
        }

        if isActive { startPulse() }
    }

    // MARK: Active state

    private func updateActiveState() {
        pulseLayer.removeAllAnimations()
        UIView.animate(withDuration: 0.2) { self.alpha = self.isActive ? 1.0 : 0.5 }
        if isActive { startPulse() }
    }

    // MARK: Animation — matches @keyframes ls-pulse exactly

    private func startPulse() {
        // scale(1) → scale(1.7), opacity 0.6 → 0, 1.8s ease-out infinite
        let scale        = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue  = 1.0
        scale.toValue    = 1.7

        let opacity      = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = 0.6
        opacity.toValue   = 0.0

        let group             = CAAnimationGroup()
        group.animations      = [scale, opacity]
        group.duration        = 1.8
        group.repeatCount     = .infinity
        group.timingFunction  = CAMediaTimingFunction(name: .easeOut)
        group.fillMode        = .forwards

        pulseLayer.add(group, forKey: "pulse")
    }
}
