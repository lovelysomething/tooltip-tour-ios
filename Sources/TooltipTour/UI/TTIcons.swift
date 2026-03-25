import SwiftUI

// MARK: - Custom Icon Enum

/// Custom icons for the minimised launcher button.
/// Maps to the `fab.icon` field in the API styles JSON.
/// Each case draws its icon as a stroked SwiftUI Path — no asset bundles needed.
public enum TTIcon: String, Codable, CaseIterable {
    case question   // ? question mark

    // Add more as SVGs arrive:
    // case compass
    // case lightbulb
    // case map
    // case rocket
    // case chat

    static func from(_ string: String?) -> TTIcon {
        guard let string else { return .question }
        return TTIcon(rawValue: string) ?? .question
    }

    /// Returns the stroked Path for this icon, scaled to fit `rect`.
    func iconPath(in rect: CGRect) -> Path {
        switch self {
        case .question: return TTIconPaths.question(in: rect)
        }
    }
}

// MARK: - Icon Paths
// Each function defines the icon in its native SVG coordinate space,
// then applies an affine transform to scale/translate into `rect`.

private enum TTIconPaths {

    /// Question mark icon (circle ring + hook arc + dot).
    /// Native SVG bounds: (38.4863, 38.6937) → (53.4863, 53.6937) — 15 × 15 pt
    static func question(in rect: CGRect) -> Path {
        let nativeOriginX: CGFloat = 38.4863
        let nativeOriginY: CGFloat = 38.6937
        let nativeSize: CGFloat    = 15.0

        let transform = CGAffineTransform(translationX: -nativeOriginX, y: -nativeOriginY)
            .concatenating(CGAffineTransform(scaleX: rect.width  / nativeSize,
                                             y:      rect.height / nativeSize))
            .concatenating(CGAffineTransform(translationX: rect.minX, y: rect.minY))

        var path = Path()

        // ── Outer circle ring ────────────────────────────────────────────────
        path.addEllipse(in: CGRect(x: nativeOriginX, y: nativeOriginY,
                                   width: nativeSize, height: nativeSize))

        // ── Hook (5 cubic Bézier segments) ──────────────────────────────────
        path.move(to: CGPoint(x: 43.8037, y: 43.9437))

        path.addCurve(to:     CGPoint(x: 44.7862, y: 42.7506),
                      control1: CGPoint(x: 43.9800, y: 43.4425),
                      control2: CGPoint(x: 44.3281, y: 43.0198))

        path.addCurve(to:     CGPoint(x: 46.3066, y: 42.4728),
                      control1: CGPoint(x: 45.2443, y: 42.4813),
                      control2: CGPoint(x: 45.7829, y: 42.3829))

        path.addCurve(to:     CGPoint(x: 47.6475, y: 43.2414),
                      control1: CGPoint(x: 46.8303, y: 42.5626),
                      control2: CGPoint(x: 47.3053, y: 42.8349))

        path.addCurve(to:     CGPoint(x: 48.1762, y: 44.6937),
                      control1: CGPoint(x: 47.9897, y: 43.6479),
                      control2: CGPoint(x: 48.1770, y: 44.1624))

        // Stem drop — control points equal end point = straight segment
        path.addCurve(to:     CGPoint(x: 45.9262, y: 46.9437),
                      control1: CGPoint(x: 48.1762, y: 46.1937),
                      control2: CGPoint(x: 45.9262, y: 46.9437))

        // ── Dot (tiny horizontal segment → round cap makes it a circle) ─────
        path.move(to:    CGPoint(x: 45.9863, y: 49.9437))
        path.addLine(to: CGPoint(x: 45.9938, y: 49.9437))

        return path.applying(transform)
    }
}

// MARK: - Icon View

/// Draws a custom icon scaled to fit `size`, stroked in `color`.
/// Use this inside the minimised launcher circle (background circle drawn separately).
struct TTIconView: View {
    let icon: TTIcon
    let color: Color
    let size: CGFloat

    var body: some View {
        Canvas { context, canvasSize in
            let path = icon.iconPath(in: CGRect(origin: .zero, size: canvasSize))
            // Scale stroke width proportionally from the SVG's 1.5pt @ 15pt icon
            let strokeWidth = 1.5 * (size / 15.0)
            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(width: size, height: size)
    }
}
