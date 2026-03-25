import SwiftUI

struct TTStepCardView: View {
    let step: TTStep
    let stepIndex: Int
    let totalSteps: Int
    let styles: TTStyles?
    let onNext: () -> Void
    let onBack: () -> Void
    let onDismiss: () -> Void

    // MARK: Resolved colours & radii
    private var cardBg: Color      { Color(styles?.resolvedCardBgColor  ?? .systemBackground) }
    private var titleColor: Color  { Color(styles?.resolvedTitleColor   ?? .label) }
    private var bodyColor: Color   { Color(styles?.resolvedBodyColor    ?? .secondaryLabel) }
    private var btnBg: Color       { Color(styles?.resolvedBtnBgColor   ?? .systemIndigo) }
    private var btnText: Color     { Color(styles?.resolvedBtnTextColor ?? .white) }
    private var cardRadius: CGFloat { styles?.cardCornerRadius ?? 16 }
    private var btnRadius: CGFloat  { styles?.btnCornerRadius  ?? 8 }

    private var isLastStep: Bool { stepIndex == totalSteps - 1 }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {

                // ── Step counter ──────────────────────────────────────────────
                Text("STEP \(stepIndex + 1) OF \(totalSteps)")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(btnBg)
                    .padding(.bottom, 6)
                    .padding(.trailing, 20) // leave room for X button

                // ── Title ─────────────────────────────────────────────────────
                Text(step.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(titleColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 6)

                // ── Body ──────────────────────────────────────────────────────
                Text(step.content)
                    .font(.system(size: 14))
                    .foregroundColor(bodyColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 16)

                // ── Progress dots ─────────────────────────────────────────────
                HStack(spacing: 6) {
                    ForEach(0..<totalSteps, id: \.self) { i in
                        Circle()
                            .fill(i == stepIndex ? btnBg : Color(UIColor.systemGray4))
                            .frame(width: 6, height: 6)
                    }
                    Spacer()
                }
                .padding(.bottom, 16)

                // ── Navigation ────────────────────────────────────────────────
                HStack(spacing: 10) {
                    // ← Prev (ghost — only when not on first step)
                    if stepIndex > 0 {
                        Button(action: onBack) {
                            Text("← Prev")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(btnBg)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                    }

                    // Next → / Finish ✓ (filled)
                    Button(action: onNext) {
                        Text(isLastStep ? "Finish ✓" : "Next →")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(btnText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(btnBg)
                            .clipShape(RoundedRectangle(cornerRadius: btnRadius))
                    }
                }
            }
            .padding(20)
            .background(cardBg)
            .clipShape(RoundedRectangle(cornerRadius: cardRadius))
            .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 0)

            // ── X close button (top-right, overlaid) ──────────────────────────
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(UIColor(hex: "9ca3b0") ?? .tertiaryLabel))
                    .frame(width: 24, height: 24)
            }
            .padding(.top, 18)
            .padding(.trailing, 16)
        }
    }
}
