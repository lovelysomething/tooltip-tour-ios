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
    private var cardRadius: CGFloat { styles?.cardCornerRadius ?? 14 }
    private var btnRadius: CGFloat  { styles?.btnCornerRadius  ?? 8 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: step counter + dismiss
            HStack {
                Text("Step \(stepIndex + 1) of \(totalSteps)")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundColor(bodyColor.opacity(0.6))
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(bodyColor)
                }
            }
            .padding(.bottom, 10)

            // Content
            Text(step.title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(titleColor)
                .padding(.bottom, 4)

            Text(step.content)
                .font(.system(size: 14))
                .foregroundColor(bodyColor)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 16)

            // Progress dots
            HStack(spacing: 5) {
                ForEach(0..<totalSteps, id: \.self) { i in
                    Circle()
                        .fill(i == stepIndex ? btnBg : bodyColor.opacity(0.25))
                        .frame(width: 6, height: 6)
                }
                Spacer()
            }
            .padding(.bottom, 14)

            // Navigation buttons
            HStack(spacing: 8) {
                if stepIndex > 0 {
                    Button(action: onBack) {
                        Text("← Back")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(btnBg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .overlay(
                                RoundedRectangle(cornerRadius: btnRadius)
                                    .stroke(btnBg.opacity(0.35), lineWidth: 1)
                            )
                    }
                }
                Button(action: onNext) {
                    Text(stepIndex == totalSteps - 1 ? "Done" : "Next →")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(btnText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(btnBg)
                        .clipShape(RoundedRectangle(cornerRadius: btnRadius))
                }
            }
        }
        .padding(18)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: cardRadius))
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
        .padding(.horizontal, 16)
    }
}
