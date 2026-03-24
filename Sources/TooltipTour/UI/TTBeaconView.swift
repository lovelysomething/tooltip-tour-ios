import UIKit

/// Numbered step indicator — filled circle with step number, matching the web app style.
final class TTBeaconView: UIView {

    var color: UIColor = .systemIndigo {
        didSet { circleLayer.backgroundColor = color.cgColor }
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

        circleLayer.backgroundColor = UIColor.systemIndigo.cgColor
        circleLayer.shadowColor = UIColor.black.cgColor
        circleLayer.shadowOpacity = 0.25
        circleLayer.shadowRadius = 6
        circleLayer.shadowOffset = CGSize(width: 0, height: 3)
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

        startPulse()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        circleLayer.frame = bounds
        circleLayer.cornerRadius = bounds.width / 2
    }

    private func startPulse() {
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 1.0
        scale.toValue   = 1.12
        scale.duration  = 1.0
        scale.repeatCount = .infinity
        scale.autoreverses = true
        scale.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        circleLayer.add(scale, forKey: "pulse")
    }
}
