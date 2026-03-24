import SwiftUI

struct TTWelcomeCardView: View {
    let config: TTConfig
    let onStart: () -> Void
    let onClose: () -> Void
    let onDontShowAgain: () -> Void

    private var styles: TTStyles? { config.styles }
    private var cardBg: Color     { Color(styles?.resolvedCardBgColor  ?? .systemBackground) }
    private var titleColor: Color { Color(styles?.resolvedTitleColor   ?? .label) }
    private var bodyColor: Color  { Color(styles?.resolvedBodyColor    ?? .secondaryLabel) }
    private var btnBg: Color      { Color(styles?.resolvedBtnBgColor   ?? .systemIndigo) }
    private var btnText: Color    { Color(styles?.resolvedBtnTextColor ?? .white) }
    private var cardRadius: CGFloat { min((styles?.cardCornerRadius ?? 14) + 2, 24) }
    private var btnRadius: CGFloat  { styles?.btnCornerRadius ?? 8 }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                // Emoji — append U+FE0F to force colour emoji presentation
                if let emoji = config.welcomeEmoji, !emoji.isEmpty {
                    Text(emoji + "\u{FE0F}")
                        .font(.system(size: 32))
                        .padding(.bottom, 12)
                }

                // Title
                if let title = config.welcomeTitle, !title.isEmpty {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(titleColor)
                        .padding(.bottom, 8)
                }

                // Message
                if let msg = config.welcomeMessage, !msg.isEmpty {
                    Text(msg)
                        .font(.system(size: 14))
                        .foregroundColor(bodyColor)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 20)
                }

                // CTA button
                Button(action: onStart) {
                    Text("Yes, show me around")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(btnText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(btnBg)
                        .clipShape(RoundedRectangle(cornerRadius: btnRadius))
                }
                .padding(.bottom, 10)

                // Don't show again
                Button(action: onDontShowAgain) {
                    Text("Don't show again")
                        .font(.system(size: 13))
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                        .underline()
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(24)
            .background(cardBg)
            .clipShape(RoundedRectangle(cornerRadius: cardRadius))
            .shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: 8)
            .frame(width: 300)

            // Close X
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(UIColor.tertiaryLabel))
                    .frame(width: 28, height: 28)
            }
            .padding(.top, 8)
            .padding(.trailing, 8)
        }
    }
}
