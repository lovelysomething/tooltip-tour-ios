import UIKit

/// Step beacon — supports 'numbered', 'dot', and 'ring' styles matching the dashboard editor.
final class TTBeaconView: UIView {

    enum Style { case numbered, dot, ring }

    // MARK: Configuration

    var beaconStyle: Style = .numbered {
        didSet { applyStyle() }
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
    /// Highlights this beacon as the active step (full opacity + animation)
    var isActive: Bool = false {
        didSet { updateActiveState() }
    }
    /// Called when the user taps this beacon
    var onTap: (() -> Void)?

    // MARK: Size helpers

    static func size(for style: Style) -> CGFloat {
        switch style {
        case .numbered: return 26
        case .dot:      return 10
        case .ring:     return 26
        }
    }

    // MARK: Private

    private let circleLayer = CALayer()
    private let rippleLayer = CALayer()   // used by dot / ring for expanding ring animation
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = true

        // Ripple sits behind circle
        layer.insertSublayer(rippleLayer, at: 0)

        circleLayer.shadowColor = UIColor.black.cgColor
        circleLayer.shadowOpacity = 0.2
        circleLayer.shadowRadius = 4
        circleLayer.shadowOffset = CGSize(width: 0, height: 2)
        layer.addSublayer(circleLayer)

        label.textColor = .white
        label.font = .systemFont(ofSize: 12, weight: .bold)
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
        circleLayer.frame = bounds
        circleLayer.cornerRadius = bounds.width / 2
        rippleLayer.frame = bounds
        rippleLayer.cornerRadius = bounds.width / 2
    }

    @objc private func handleTap() { onTap?() }

    // MARK: Style application

    private func applyStyle() {
        circleLayer.removeAllAnimations()
        rippleLayer.removeAllAnimations()

        switch beaconStyle {
        case .numbered:
            circleLayer.backgroundColor = color.cgColor
            circleLayer.borderWidth = 0
            rippleLayer.isHidden = true
            label.isHidden = false
            label.textColor = labelColor

        case .dot:
            circleLayer.backgroundColor = color.cgColor
            circleLayer.borderWidth = 0
            rippleLayer.backgroundColor = color.withAlphaComponent(0.35).cgColor
            rippleLayer.isHidden = false
            label.isHidden = true

        case .ring:
            circleLayer.backgroundColor = UIColor.clear.cgColor
            circleLayer.borderColor = color.cgColor
            circleLayer.borderWidth = 2.5
            circleLayer.shadowOpacity = 0
            rippleLayer.backgroundColor = color.withAlphaComponent(0.2).cgColor
            rippleLayer.isHidden = false
            label.isHidden = true
        }

        if isActive { startAnimation() }
    }

    // MARK: Active state

    private func updateActiveState() {
        circleLayer.removeAllAnimations()
        rippleLayer.removeAllAnimations()
        UIView.animate(withDuration: 0.2) { self.alpha = self.isActive ? 1.0 : 0.5 }
        if isActive { startAnimation() }
    }

    private func startAnimation() {
        switch beaconStyle {
        case .numbered:
            // Gentle scale pulse
            let pulse = CABasicAnimation(keyPath: "transform.scale")
            pulse.fromValue = 1.0
            pulse.toValue = 1.08
            pulse.duration = 1.1
            pulse.repeatCount = .infinity
            pulse.autoreverses = true
            pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            circleLayer.add(pulse, forKey: "pulse")

        case .dot:
            // Outward ripple ring expanding from dot
            let scale = CABasicAnimation(keyPath: "transform.scale")
            scale.fromValue = 1.0
            scale.toValue = 2.8
            let opacity = CABasicAnimation(keyPath: "opacity")
            opacity.fromValue = 0.5
            opacity.toValue = 0.0
            let group = CAAnimationGroup()
            group.animations = [scale, opacity]
            group.duration = 1.2
            group.repeatCount = .infinity
            group.timingFunction = CAMediaTimingFunction(name: .easeOut)
            rippleLayer.add(group, forKey: "ripple")

        case .ring:
            // Ring breathes in and out
            let pulse = CABasicAnimation(keyPath: "transform.scale")
            pulse.fromValue = 1.0
            pulse.toValue = 1.18
            pulse.duration = 1.0
            pulse.repeatCount = .infinity
            pulse.autoreverses = true
            pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            circleLayer.add(pulse, forKey: "pulse")

            // Fading outer ring
            let fadeScale = CABasicAnimation(keyPath: "transform.scale")
            fadeScale.fromValue = 1.0
            fadeScale.toValue = 2.2
            let fadeOpacity = CABasicAnimation(keyPath: "opacity")
            fadeOpacity.fromValue = 0.4
            fadeOpacity.toValue = 0.0
            let group = CAAnimationGroup()
            group.animations = [fadeScale, fadeOpacity]
            group.duration = 1.2
            group.repeatCount = .infinity
            group.timingFunction = CAMediaTimingFunction(name: .easeOut)
            rippleLayer.add(group, forKey: "ripple")
        }
    }
}
