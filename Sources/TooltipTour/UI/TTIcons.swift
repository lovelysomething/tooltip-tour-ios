import SwiftUI

// MARK: - Icon enum

public enum TTIcon: String, Codable, CaseIterable {
    // Original 12
    case question, compass, map, lightbulb, sparkle, search, book, rocket
    case chat, info, play, guide
    // New 12
    case flag, bell, gift, check, heart, lock, settings, trophy, zap, eye, cursor, chart

    static func from(_ string: String?) -> TTIcon {
        guard let string else { return .question }
        return TTIcon(rawValue: string) ?? .question
    }
}

// MARK: - Icon View
// Uses Canvas to draw the exact same paths as the web SVGs — identical look on every size.

struct TTIconView: View {
    let icon: TTIcon
    let color: Color
    let size: CGFloat

    var body: some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 24
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }

            var path = Path()

            switch icon {

            // ── Original 12 ───────────────────────────────────────────────

            case .question:
                path.addEllipse(in: CGRect(x: 2*s, y: 2*s, width: 20*s, height: 20*s))
                path.move(to: pt(9.09, 9))
                path.addCurve(to: pt(14.92, 10), control1: pt(9.09, 5.8),  control2: pt(14.92, 5.8))
                path.addCurve(to: pt(12, 13),    control1: pt(14.92, 12),   control2: pt(12, 13))
                path.move(to: pt(12, 17)); path.addLine(to: pt(12, 17.01))

            case .compass:
                path.addEllipse(in: CGRect(x: 2*s, y: 2*s, width: 20*s, height: 20*s))
                path.move(to: pt(16.24, 7.76))
                path.addLine(to: pt(14.12, 14.12))
                path.addLine(to: pt(7.76, 16.24))
                path.addLine(to: pt(9.88, 9.88))
                path.closeSubpath()

            case .map:
                let mp: [(CGFloat,CGFloat)] = [(3,6),(9,3),(15,6),(21,3),(21,18),(15,21),(9,18),(3,21)]
                path.move(to: pt(mp[0].0, mp[0].1))
                mp.dropFirst().forEach { path.addLine(to: pt($0.0, $0.1)) }
                path.closeSubpath()
                path.move(to: pt(9,3));  path.addLine(to: pt(9,18))
                path.move(to: pt(15,6)); path.addLine(to: pt(15,21))

            case .lightbulb:
                path.move(to: pt(9,18));  path.addLine(to: pt(15,18))
                path.move(to: pt(10,22)); path.addLine(to: pt(14,22))
                path.move(to: pt(15.09, 14))
                path.addCurve(to: pt(18,8),    control1: pt(16.7,12.5), control2: pt(18,10.5))
                path.addArc(center: pt(12,8), radius: 6*s,
                            startAngle: .degrees(0), endAngle: .degrees(180), clockwise: true)
                path.addCurve(to: pt(8.91,14), control1: pt(6,10.5),   control2: pt(7.3,12.5))

            case .sparkle:
                let sp: [(CGFloat,CGFloat)] = [
                    (12,2),(15.09,8.26),(22,9.27),(17,14.14),(18.18,21.02),
                    (12,17.77),(5.82,21.02),(7,14.14),(2,9.27),(8.91,8.26)
                ]
                path.move(to: pt(sp[0].0, sp[0].1))
                sp.dropFirst().forEach { path.addLine(to: pt($0.0, $0.1)) }
                path.closeSubpath()

            case .search:
                path.addEllipse(in: CGRect(x: 3*s, y: 3*s, width: 16*s, height: 16*s))
                path.move(to: pt(21,21)); path.addLine(to: pt(16.65,16.65))

            case .book:
                path.move(to: pt(4,19.5))
                path.addQuadCurve(to: pt(6.5,17), control: pt(4,17))
                path.addLine(to: pt(20,17))
                path.move(to: pt(6.5,2))
                path.addLine(to: pt(20,2)); path.addLine(to: pt(20,22)); path.addLine(to: pt(6.5,22))
                path.addQuadCurve(to: pt(4,19.5), control: pt(4,22))
                path.addLine(to: pt(4,4.5))
                path.addQuadCurve(to: pt(6.5,2), control: pt(4,2))
                path.closeSubpath()

            case .rocket:
                path.move(to: pt(22,2)); path.addLine(to: pt(11,13))
                path.move(to: pt(22,2))
                path.addLine(to: pt(15,22)); path.addLine(to: pt(11,13))
                path.addLine(to: pt(2,9))
                path.closeSubpath()

            case .chat:
                path.move(to: pt(21,15))
                path.addQuadCurve(to: pt(19,17), control: pt(21,17))
                path.addLine(to: pt(7,17)); path.addLine(to: pt(3,21)); path.addLine(to: pt(3,5))
                path.addQuadCurve(to: pt(5,3), control: pt(3,3))
                path.addLine(to: pt(19,3))
                path.addQuadCurve(to: pt(21,5), control: pt(21,3))
                path.closeSubpath()

            case .info:
                path.addEllipse(in: CGRect(x: 2*s, y: 2*s, width: 20*s, height: 20*s))
                path.move(to: pt(12,16)); path.addLine(to: pt(12,12))
                path.move(to: pt(12,8));  path.addLine(to: pt(12,8.01))

            case .play:
                path.addEllipse(in: CGRect(x: 2*s, y: 2*s, width: 20*s, height: 20*s))
                path.move(to: pt(10,8)); path.addLine(to: pt(16,12)); path.addLine(to: pt(10,16))
                path.closeSubpath()

            case .guide:
                path.addEllipse(in: CGRect(x: 2*s, y: 2*s, width: 20*s, height: 20*s))
                path.move(to: pt(12,8)); path.addLine(to: pt(16,12)); path.addLine(to: pt(12,16))
                path.move(to: pt(8,12)); path.addLine(to: pt(16,12))

            // ── New 12 ────────────────────────────────────────────────────

            case .flag:
                path.move(to: pt(4,22)); path.addLine(to: pt(4,3))
                path.addLine(to: pt(19,3)); path.addLine(to: pt(19,13)); path.addLine(to: pt(4,13))

            case .bell:
                path.move(to: pt(18,8))
                path.addArc(center: pt(12,8), radius: 6*s,
                            startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
                path.addCurve(to: pt(3,17),  control1: pt(6,15),   control2: pt(3,17))
                path.addLine(to: pt(21,17))
                path.addCurve(to: pt(18,8),  control1: pt(21,15),  control2: pt(18,15))
                path.move(to: pt(10.73,21))
                path.addQuadCurve(to: pt(13.27,21), control: pt(12,23))

            case .gift:
                path.addRect(CGRect(x: 2*s, y: 7*s, width: 20*s, height: 2*s))
                path.addRect(CGRect(x: 3*s, y: 9*s, width: 18*s, height: 13*s))
                path.move(to: pt(12,7)); path.addLine(to: pt(12,22))
                path.move(to: pt(12,7))
                path.addCurve(to: pt(8,3),   control1: pt(10,7),   control2: pt(8,5.5))
                path.addCurve(to: pt(12,7),  control1: pt(8,1.5),  control2: pt(11,4))
                path.move(to: pt(12,7))
                path.addCurve(to: pt(16,3),  control1: pt(14,7),   control2: pt(16,5.5))
                path.addCurve(to: pt(12,7),  control1: pt(16,1.5), control2: pt(13,4))

            case .check:
                path.addEllipse(in: CGRect(x: 2*s, y: 2*s, width: 20*s, height: 20*s))
                path.move(to: pt(8,12)); path.addLine(to: pt(11,15)); path.addLine(to: pt(16,9.5))

            case .heart:
                path.move(to: pt(12,21))
                path.addCurve(to: pt(3,12),     control1: pt(7,21),     control2: pt(2,17))
                path.addCurve(to: pt(7.5,5.5),  control1: pt(2,7),      control2: pt(4.5,5.5))
                path.addCurve(to: pt(12,9.5),   control1: pt(10,5.5),   control2: pt(11,6.5))
                path.addCurve(to: pt(16.5,5.5), control1: pt(13,6.5),   control2: pt(14,5.5))
                path.addCurve(to: pt(21,12),    control1: pt(19.5,5.5), control2: pt(22,7))
                path.addCurve(to: pt(12,21),    control1: pt(22,17),    control2: pt(17,21))
                path.closeSubpath()

            case .lock:
                path.addRoundedRect(in: CGRect(x: 3*s, y: 11*s, width: 18*s, height: 11*s),
                                    cornerSize: CGSize(width: 2*s, height: 2*s))
                path.move(to: pt(7,11)); path.addLine(to: pt(7,7))
                path.addArc(center: pt(12,7), radius: 5*s,
                            startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
                path.addLine(to: pt(17,11))

            case .settings:
                path.move(to: pt(4,21));  path.addLine(to: pt(4,14))
                path.move(to: pt(4,10));  path.addLine(to: pt(4,3))
                path.move(to: pt(12,21)); path.addLine(to: pt(12,12))
                path.move(to: pt(12,8));  path.addLine(to: pt(12,3))
                path.move(to: pt(20,21)); path.addLine(to: pt(20,16))
                path.move(to: pt(20,12)); path.addLine(to: pt(20,3))
                path.addEllipse(in: CGRect(x: 2*s,  y: 10*s, width: 4*s, height: 4*s))
                path.addEllipse(in: CGRect(x: 10*s, y: 6*s,  width: 4*s, height: 4*s))
                path.addEllipse(in: CGRect(x: 18*s, y: 12*s, width: 4*s, height: 4*s))

            case .trophy:
                path.move(to: pt(6,3)); path.addLine(to: pt(18,3))
                path.addLine(to: pt(18,10))
                path.addCurve(to: pt(12,17), control1: pt(18,14), control2: pt(15,17))
                path.addCurve(to: pt(6,10),  control1: pt(9,17),  control2: pt(6,14))
                path.closeSubpath()
                path.move(to: pt(6,5))
                path.addCurve(to: pt(3,9), control1: pt(2,5), control2: pt(2,9))
                path.addLine(to: pt(6,9))
                path.move(to: pt(18,5))
                path.addCurve(to: pt(21,9), control1: pt(22,5), control2: pt(22,9))
                path.addLine(to: pt(18,9))
                path.move(to: pt(12,17)); path.addLine(to: pt(12,21))
                path.move(to: pt(8,21));  path.addLine(to: pt(16,21))

            case .zap:
                let zp: [(CGFloat,CGFloat)] = [(13,2),(3,14),(12,14),(11,22),(21,10),(12,10)]
                path.move(to: pt(zp[0].0, zp[0].1))
                zp.dropFirst().forEach { path.addLine(to: pt($0.0, $0.1)) }
                path.closeSubpath()

            case .eye:
                path.move(to: pt(1,12))
                path.addCurve(to: pt(12,5),  control1: pt(1,7.5),    control2: pt(6,5))
                path.addCurve(to: pt(23,12), control1: pt(18,5),     control2: pt(23,7.5))
                path.addCurve(to: pt(12,19), control1: pt(23,16.5),  control2: pt(18,19))
                path.addCurve(to: pt(1,12),  control1: pt(6,19),     control2: pt(1,16.5))
                path.addEllipse(in: CGRect(x: 9*s, y: 9*s, width: 6*s, height: 6*s))

            case .cursor:
                path.move(to: pt(5,3))
                path.addLine(to: pt(19,12)); path.addLine(to: pt(11,14))
                path.addLine(to: pt(9,22))
                path.closeSubpath()

            case .chart:
                path.move(to: pt(18,20)); path.addLine(to: pt(18,10))
                path.move(to: pt(12,20)); path.addLine(to: pt(12,4))
                path.move(to: pt(6,20));  path.addLine(to: pt(6,14))
                path.move(to: pt(2,20));  path.addLine(to: pt(22,20))
            }

            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: 2 * (canvasSize.width / 24), lineCap: .round, lineJoin: .round)
            )
        }
        .frame(width: size, height: size)
    }
}
