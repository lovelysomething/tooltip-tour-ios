import UIKit

/// Step beacon — supports 'numbered', 'dot', and 'ring' styles matching the dashboard editor.
final class TTBeaconView: UIView {

    enum Style { case numbered, dot, ring }

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

    private let circleLayer = CALayer()
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false

        circleLayer.shadowColor = UIColor.black.cgColor
        circleLayer.shadowOpacity = 0.2
        circleLayer.shadowRadius = 5
        circleLayer.shadowOffset = CGSize(width: 0, height: 2)
        layer.addSublayer(circleLayer)

        label.textColor = .white
        label.font = .systemFont(ofSize: 15, weight: .bold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        applyStyle()
        startPulse()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        circleLayer.frame = bounds
        circleLayer.cornerRadius = bounds.width / 2
    }

    private func applyStyle() {
        circleLayer.removeAllAnimations()

        switch beaconStyle {
        case .numbered:
            circleLayer.backgroundColor = color.cgColor
            circleLayer.borderColor = UIColor.clear.cgColor
            circleLayer.borderWidth = 0
            label.isHidden = false
            label.textColor = labelColor

        case .dot:
            circleLayer.backgroundColor = color.cgColor
            circleLayer.borderColor = UIColor.clear.cgColor
            circleLayer.borderWidth = 0
            label.isHidden = true

        case .ring:
            circleLayer.backgroundColor = UIColor.clear.cgColor
            circleLayer.borderColor = color.cgColor
            circleLayer.borderWidth = 3
            // No shadow on ring
            circleLayer.shadowOpacity = 0
            label.isHidden = true
        }

        startPulse()
    }

    private func startPulse() {
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 1.0
        scale.toValue   = beaconStyle == .ring ? 1.15 : 1.10
        scale.duration  = 1.0
        scale.repeatCount = .infinity
        scale.autoreverses = true
        scale.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        circleLayer.add(scale, forKey: "pulse")
    }
}
