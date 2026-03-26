import UIKit

// MARK: - API Response Models

public struct TTConfig: Codable {
    public let id: String
    public let fabLabel: String?
    public let welcomeEmoji: String?
    public let welcomeTitle: String?
    public let welcomeMessage: String?
    public let autoOpen: Bool
    public let startMinimized: Bool
    /// Maximum number of times to auto-show the welcome card per device. nil = infinite.
    public let maxShows: Int?
    public let steps: [TTStep]
    public let styles: TTStyles?
}

public struct TTStep: Codable {
    public let title: String
    public let content: String
    /// The UIView.accessibilityIdentifier (UIKit) or .ttTarget() identifier (SwiftUI) to highlight
    public let selector: String
}

// MARK: - Styles (mirrors the web app styles object exactly)

public struct TTStyles: Codable {
    public let fab: TTFabStyle?
    public let card: TTCardStyle?
    public let type: TTTypeStyle?
    public let btn: TTBtnStyle?
    public let beacon: TTBeaconStyle?
}

public struct TTFabStyle: Codable {
    public let bgColor: String?
    public let borderRadius: Double?
    public let icon: String?
    /// "left" or "right" — which side of the screen the minimised circle sits on. Default "right".
    public let position: String?
    /// Distance in points above the safe-area bottom edge for the minimised circle. Default 40.
    public let bottomOffset: Double?
    enum CodingKeys: String, CodingKey {
        case bgColor = "bg_color"
        case borderRadius = "border_radius"
        case icon
        case position
        case bottomOffset = "bottom_offset"
    }
}

public struct TTCardStyle: Codable {
    public let bgColor: String?
    public let borderRadius: Double?
    enum CodingKeys: String, CodingKey {
        case bgColor = "bg_color"
        case borderRadius = "border_radius"
    }
}

public struct TTTypeStyle: Codable {
    public let titleColor: String?
    public let bodyColor: String?
    enum CodingKeys: String, CodingKey {
        case titleColor = "title_color"
        case bodyColor = "body_color"
    }
}

public struct TTBtnStyle: Codable {
    public let bgColor: String?
    public let textColor: String?
    public let borderRadius: Double?
    enum CodingKeys: String, CodingKey {
        case bgColor = "bg_color"
        case textColor = "text_color"
        case borderRadius = "border_radius"
    }
}

public struct TTBeaconStyle: Codable {
    public let style: String?
    public let bgColor: String?
    public let textColor: String?
    enum CodingKeys: String, CodingKey {
        case style
        case bgColor = "bg_color"
        case textColor = "text_color"
    }
}

// MARK: - Resolved color / radius helpers

extension TTStyles {
    // FAB
    var resolvedFabBgColor: UIColor   { UIColor(hex: fab?.bgColor ?? "")       ?? .systemIndigo }
    var fabCornerRadius: CGFloat      { CGFloat(fab?.borderRadius ?? 24) }

    // Card
    var resolvedCardBgColor: UIColor  { UIColor(hex: card?.bgColor ?? "")      ?? .systemBackground }
    var cardCornerRadius: CGFloat     { CGFloat(card?.borderRadius ?? 14) }

    // Text
    var resolvedTitleColor: UIColor   { UIColor(hex: type?.titleColor ?? "")   ?? .label }
    var resolvedBodyColor: UIColor    { UIColor(hex: type?.bodyColor ?? "")    ?? .secondaryLabel }

    // Button
    var resolvedBtnBgColor: UIColor   { UIColor(hex: btn?.bgColor ?? "")       ?? .systemIndigo }
    var resolvedBtnTextColor: UIColor { UIColor(hex: btn?.textColor ?? "")     ?? .white }
    var btnCornerRadius: CGFloat      { CGFloat(btn?.borderRadius ?? 8) }

    // Beacon
    var resolvedBeaconBgColor: UIColor   { UIColor(hex: beacon?.bgColor ?? "")    ?? .systemIndigo }
    var resolvedBeaconTextColor: UIColor { UIColor(hex: beacon?.textColor ?? "")  ?? .white }
}

// MARK: - UIColor hex helper

extension UIColor {
    convenience init?(hex: String) {
        var str = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.hasPrefix("#") { str.removeFirst() }
        guard str.count == 6, let rgb = UInt64(str, radix: 16) else { return nil }
        self.init(
            red:   CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8)  & 0xFF) / 255,
            blue:  CGFloat( rgb        & 0xFF) / 255,
            alpha: 1
        )
    }
}
