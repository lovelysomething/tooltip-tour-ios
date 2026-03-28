import SwiftUI

// MARK: - Icon enum

public enum TTIcon: String, Codable, CaseIterable {
    case question
    case compass
    case map
    case lightbulb
    case sparkle
    case search
    case book
    case rocket
    case chat
    case info
    case play
    case guide

    static func from(_ string: String?) -> TTIcon {
        guard let string else { return .question }
        return TTIcon(rawValue: string) ?? .question
    }

    func path(in rect: CGRect) -> Path {
        // All icons are defined in a 24×24 SVG viewBox then scaled into rect.
        let sx = rect.width  / 24
        let sy = rect.height / 24
        let dx = rect.minX
        let dy = rect.minY
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: dx + x*sx, y: dy + y*sy) }

        var path = Path()

        switch self {

        // ── Question mark — circle + hook + dot ──────────────────────────────
        case .question:
            path.addEllipse(in: CGRect(x: dx + 2*sx, y: dy + 2*sy, width: 20*sx, height: 20*sy))
            path.move(to: p(9.09, 9))
            path.addCurve(to: p(12, 8), control1: p(9.09, 7.34), control2: p(10.44, 7))
            path.addCurve(to: p(13, 10), control1: p(13.56, 7.96), control2: p(14, 8.93))
            path.addCurve(to: p(12, 13), control1: p(13, 11), control2: p(12, 12))
            path.addLine(to: p(12, 13))
            path.move(to: p(12, 17)); path.addLine(to: p(12.01, 17))

        // ── Compass — circle + diamond polygon ───────────────────────────────
        case .compass:
            path.addEllipse(in: CGRect(x: dx + 2*sx, y: dy + 2*sy, width: 20*sx, height: 20*sy))
            path.move(to: p(16.24, 7.76))
            path.addLine(to: p(14.12, 14.12))
            path.addLine(to: p(7.76, 16.24))
            path.addLine(to: p(9.88, 9.88))
            path.closeSubpath()

        // ── Map — folded map with fold lines ─────────────────────────────────
        case .map:
            path.move(to: p(3, 6));  path.addLine(to: p(9, 3))
            path.addLine(to: p(15, 6)); path.addLine(to: p(21, 3))
            path.addLine(to: p(21, 18)); path.addLine(to: p(15, 21))
            path.addLine(to: p(9, 18)); path.addLine(to: p(3, 21))
            path.closeSubpath()
            path.move(to: p(9, 3));  path.addLine(to: p(9, 18))
            path.move(to: p(15, 6)); path.addLine(to: p(15, 21))

        // ── Lightbulb ────────────────────────────────────────────────────────
        case .lightbulb:
            path.move(to: p(9, 18)); path.addLine(to: p(15, 18))
            path.move(to: p(10, 22)); path.addLine(to: p(14, 22))
            path.move(to: p(15.09, 14))
            path.addCurve(to: p(18, 8), control1: p(15.27, 13.02), control2: p(18, 11))
            path.addCurve(to: p(12, 2), control1: p(18, 4.69), control2: p(15.31, 2))
            path.addCurve(to: p(6, 8),  control1: p(8.69, 2),  control2: p(6, 4.69))
            path.addCurve(to: p(8.91, 14), control1: p(6, 11), control2: p(6.73, 13.02))

        // ── Sparkle / star ────────────────────────────────────────────────────
        case .sparkle:
            path.move(to: p(12, 2))
            path.addLine(to: p(15.09, 8.26)); path.addLine(to: p(22, 9.27))
            path.addLine(to: p(17, 14.14)); path.addLine(to: p(18.18, 21.02))
            path.addLine(to: p(12, 17.77)); path.addLine(to: p(5.82, 21.02))
            path.addLine(to: p(7, 14.14));  path.addLine(to: p(2, 9.27))
            path.addLine(to: p(8.91, 8.26))
            path.closeSubpath()

        // ── Search — circle + handle line ────────────────────────────────────
        case .search:
            path.addEllipse(in: CGRect(x: dx + 3*sx, y: dy + 3*sy, width: 16*sx, height: 16*sy))
            path.move(to: p(21, 21)); path.addLine(to: p(16.65, 16.65))

        // ── Book ──────────────────────────────────────────────────────────────
        case .book:
            path.move(to: p(4, 19.5))
            path.addCurve(to: p(6.5, 17), control1: p(4, 18.17), control2: p(5.12, 17))
            path.addLine(to: p(20, 17))
            path.move(to: p(6.5, 2)); path.addLine(to: p(20, 2))
            path.addLine(to: p(20, 22)); path.addLine(to: p(6.5, 22))
            path.addCurve(to: p(4, 19.5), control1: p(5.12, 22), control2: p(4, 20.88))
            path.addCurve(to: p(6.5, 17), control1: p(4, 18.12), control2: p(5.12, 17))

        // ── Rocket ────────────────────────────────────────────────────────────
        case .rocket:
            path.move(to: p(4.5, 16.5))
            path.addCurve(to: p(2.5, 21.5), control1: p(3, 17.76), control2: p(2.5, 21.5))
            path.addCurve(to: p(7.5, 19.5), control1: p(2.5, 21.5), control2: p(6.24, 21))
            path.addCurve(to: p(7.41, 16.59), control1: p(8.21, 18.66), control2: p(8.2, 17.37))
            path.addCurve(to: p(4.5, 16.5), control1: p(6.63, 15.8), control2: p(5.34, 15.79))
            path.move(to: p(12, 15)); path.addLine(to: p(9, 12))
            path.addCurve(to: p(11, 8.05), control1: p(9, 12), control2: p(9.9, 9.75))
            path.addCurve(to: p(22, 2), control1: p(14.35, 4.76), control2: p(22, 2))
            path.addCurve(to: p(18, 13), control1: p(22, 2), control2: p(21.24, 6.66))
            path.addCurve(to: p(12, 15), control1: p(16.61, 14.9), control2: p(12, 15))
            path.move(to: p(9, 12)); path.addLine(to: p(4, 12))
            path.addCurve(to: p(6, 8), control1: p(4, 12), control2: p(4.55, 8.97))
            path.addLine(to: p(11, 8.05))
            path.move(to: p(12, 15)); path.addLine(to: p(12, 20))
            path.addCurve(to: p(16, 18), control1: p(12, 20), control2: p(15.03, 19.55))
            path.addLine(to: p(16, 13))

        // ── Chat bubble ───────────────────────────────────────────────────────
        case .chat:
            path.move(to: p(21, 15))
            path.addCurve(to: p(19, 17), control1: p(21, 16.1), control2: p(20.1, 17))
            path.addLine(to: p(7, 17))
            path.addLine(to: p(3, 21))
            path.addLine(to: p(3, 5))
            path.addCurve(to: p(5, 3), control1: p(3, 3.9), control2: p(3.9, 3))
            path.addLine(to: p(19, 3))
            path.addCurve(to: p(21, 5), control1: p(20.1, 3), control2: p(21, 3.9))
            path.closeSubpath()

        // ── Info — circle + vertical line + dot ───────────────────────────────
        case .info:
            path.addEllipse(in: CGRect(x: dx + 2*sx, y: dy + 2*sy, width: 20*sx, height: 20*sy))
            path.move(to: p(12, 16)); path.addLine(to: p(12, 12))
            path.move(to: p(12, 8));  path.addLine(to: p(12.01, 8))

        // ── Play — circle + triangle ──────────────────────────────────────────
        case .play:
            path.addEllipse(in: CGRect(x: dx + 2*sx, y: dy + 2*sy, width: 20*sx, height: 20*sy))
            path.move(to: p(10, 8)); path.addLine(to: p(16, 12))
            path.addLine(to: p(10, 16))
            path.closeSubpath()

        // ── Guide — circle + arrow pointing right ─────────────────────────────
        case .guide:
            path.addEllipse(in: CGRect(x: dx + 2*sx, y: dy + 2*sy, width: 20*sx, height: 20*sy))
            path.move(to: p(12, 8)); path.addLine(to: p(16, 12))
            path.addLine(to: p(12, 16))
            path.move(to: p(8, 12)); path.addLine(to: p(16, 12))
        }

        return path
    }
}

// MARK: - Icon View

struct TTIconView: View {
    let icon: TTIcon
    let color: Color
    let size: CGFloat

    var body: some View {
        Canvas { context, canvasSize in
            let strokeWidth = max(1.5, 1.5 * (size / 18.0))
            let inset = strokeWidth / 2
            let drawRect = CGRect(x: inset, y: inset,
                                  width: canvasSize.width  - strokeWidth,
                                  height: canvasSize.height - strokeWidth)
            context.stroke(
                icon.path(in: drawRect),
                with: .color(color),
                style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(width: size, height: size)
    }
}
