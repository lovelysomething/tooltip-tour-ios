import SwiftUI

/// The initial launch card shown at the bottom of the screen.
/// The X button sits *below* the card so it never competes with the card content.
struct TTWelcomeCardView: View {
    let config: TTConfig
    let onStart: () -> Void
    let onDismiss: () -> Void        // taps X → minimise to circle
    let onDontShowAgain: () -> Void

    private var styles: TTStyles? { config.styles }

    private var cardBg: Color     { Color(styles?.resolvedCardBgColor  ?? .systemBackground) }
    private var titleColor: Color { Color(styles?.resolvedTitleColor   ?? .label) }
    private var bodyColor: Color  { Color(styles?.resolvedBodyColor    ?? UIColor(hex: "6b7280") ?? .secondaryLabel) }
    private var btnBg: Color      { Color(styles?.resolvedBtnBgColor   ?? .systemIndigo) }
    private var btnText: Color    { Color(styles?.resolvedBtnTextColor ?? .white) }
    private var cardRadius: CGFloat { styles?.cardCornerRadius ?? 16 }
    private var btnRadius: CGFloat  { styles?.btnCornerRadius  ?? 8 }

    var body: some View {
        VStack(spacing: 0) {
            // ── White card ────────────────────────────────────────────────────
            VStack(spacing: 0) {
                // Title
                if let title = config.welcomeTitle, !title.isEmpty {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(titleColor)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 8)
                }

                // Body
                if let msg = config.welcomeMessage, !msg.isEmpty {
                    Text(msg)
                        .font(.system(size: 14))
                        .foregroundColor(bodyColor)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 20)
                }

                // CTA button
                Button(action: onStart) {
                    Text("Yes, show me around!")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(btnText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(btnBg)
                        .clipShape(RoundedRectangle(cornerRadius: btnRadius))
                }
                .padding(.bottom, 14)

                // Don't show again
                Button(action: onDontShowAgain) {
                    Text("Don't show again")
                        .font(.system(size: 14))
                        .foregroundColor(Color(UIColor(hex: "9ca3b0") ?? .tertiaryLabel))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(cardBg)
            .clipShape(RoundedRectangle(cornerRadius: cardRadius))
            .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 0)

            // ── Gap between card and X ────────────────────────────────────────
            Spacer().frame(height: 16)

            // ── X dismiss circle (below the card, centered) ───────────────────
            Button(action: onDismiss) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.35))
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(width: 22, height: 22)
            }

            Spacer().frame(height: 20)
        }
        .padding(.horizontal, 20)
    }
}
