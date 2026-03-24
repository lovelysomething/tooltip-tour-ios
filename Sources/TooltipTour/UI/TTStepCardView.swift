import SwiftUI

struct TTStepCardView: View {
    let step: TTStep
    let stepIndex: Int
    let totalSteps: Int
    let primaryColor: Color
    let onNext: () -> Void
    let onBack: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: step counter + dismiss
            HStack {
                Text("Step \(stepIndex + 1) of \(totalSteps)")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 10)

            // Step content
            Text(step.title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.primary)
                .padding(.bottom, 4)

            Text(step.text)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 16)

            // Progress dots
            HStack(spacing: 5) {
                ForEach(0..<totalSteps, id: \.self) { i in
                    Circle()
                        .fill(i == stepIndex ? primaryColor : Color.secondary.opacity(0.3))
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
                            .foregroundColor(primaryColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(primaryColor.opacity(0.35), lineWidth: 1)
                            )
                    }
                }
                Button(action: onNext) {
                    Text(stepIndex == totalSteps - 1 ? "Done" : "Next →")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(primaryColor)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(18)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
        .padding(.horizontal, 16)
    }
}
