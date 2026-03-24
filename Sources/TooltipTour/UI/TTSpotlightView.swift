import UIKit

/// Full-screen dimmed overlay with a rounded-rect cutout around the highlighted view.
final class TTSpotlightView: UIView {

    private let maskLayer = CAShapeLayer()

    var highlightRect: CGRect = .zero {
        didSet { updateMask() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        layer.mask = maskLayer
        // Dim layer sits behind the mask
        let dimView = UIView(frame: frame)
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        dimView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(dimView)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        maskLayer.frame = bounds
        updateMask()
    }

    private func updateMask() {
        let full = UIBezierPath(rect: bounds)
        let inset = highlightRect.insetBy(dx: -10, dy: -10)
        let cutout = UIBezierPath(roundedRect: inset, cornerRadius: 14)
        full.append(cutout)
        full.usesEvenOddFillRule = true

        let path = CAShapeLayer()
        path.path = full.cgPath
        path.fillRule = .evenOdd
        path.fillColor = UIColor.black.cgColor

        maskLayer.path = full.cgPath
        maskLayer.fillRule = .evenOdd
        maskLayer.fillColor = UIColor.black.cgColor
    }
}
