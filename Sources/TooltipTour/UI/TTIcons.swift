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

    /// SF Symbol name — pixel-perfect on every iOS device and size.
    var systemName: String {
        switch self {
        case .question:  return "questionmark.circle"
        case .compass:   return "safari"
        case .map:       return "map"
        case .lightbulb: return "lightbulb"
        case .sparkle:   return "star"
        case .search:    return "magnifyingglass"
        case .book:      return "book"
        case .rocket:    return "paperplane"
        case .chat:      return "message"
        case .info:      return "info.circle"
        case .play:      return "play.circle"
        case .guide:     return "arrow.right.circle"
        }
    }
}

// MARK: - Icon View

struct TTIconView: View {
    let icon: TTIcon
    let color: Color
    let size: CGFloat

    var body: some View {
        Image(systemName: icon.systemName)
            .resizable()
            .scaledToFit()
            .foregroundColor(color)
            .frame(width: size, height: size)
    }
}
