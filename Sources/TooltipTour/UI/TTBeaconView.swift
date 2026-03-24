import UIKit

/// Animated pulsing ring drawn around the highlighted view.
final class TTBeaconView: UIView {

    private let ringLayer = CALayer()
    var color: UIColor = .white {
        didSet { ringLayer.borderColor = color.cgColor }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false

        ringLayer.borderWidth = 2.5
        ringLayer.borderColor = UIColor.white.cgColor
        ringLayer.opacity = 0.9
        layer.addSublayer(ringLayer)
        startPulse()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        ringLayer.frame = bounds
        ringLayer.cornerRadius = bounds.width / 2
    }

    private func startPulse() {
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 1.0
        scale.toValue   = 1.35
        scale.duration  = 1.1
        scale.repeatCount = .infinity
        scale.autoreverses = true
        scale.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0.9
        fade.toValue   = 0.2
        fade.duration  = 1.1
        fade.repeatCount = .infinity
        fade.autoreverses = true
        fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        ringLayer.add(scale, forKey: "pulse-scale")
        ringLayer.add(fade,  forKey: "pulse-fade")
    }
}
