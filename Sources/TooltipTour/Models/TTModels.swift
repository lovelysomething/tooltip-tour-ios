import UIKit

// MARK: - API Response Models

// MARK: - Display conditions

public struct TTElementCondition: Codable {
    public let selector: String
    public let rule: String   // "exists" | "not_exists"
}

public struct TTTourCondition: Codable {
    public let tourId: String
    public let rule: String   // "seen" | "completed"
}

public struct TTDisplayConditions: Codable {
    public let elementCondition:   TTElementCondition?
    public let priorTourCondition: TTTourCondition?
}

// MARK: - Tour config

public struct TTConfig: Codable {
    public let id: String
    /// Only present in prefetch responses — the page identifier this tour is bound to.
    public let pagePattern: String?
    public let fabLabel: String?
    public let welcomeEmoji: String?
    public let welcomeTitle: String?
    public let welcomeMessage: String?
    public let autoOpen: Bool
    public let startMinimized: Bool
    /// "full" (default) shows the welcome card popup; "button" starts the tour directly when the FAB is tapped.
    public let welcomeMode: String?
    /// Maximum number of times to auto-show the welcome card per device. nil = infinite.
    public let maxShows: Int?
    public let steps: [TTStep]
    public let styles: TTStyles?
    /// Optional full-screen carousel shown before the welcome card.
    public let splashCarousel: TTSplashCarousel?
    /// Optional conditions controlling when this tour is displayed.
    public let displayConditions: TTDisplayConditions?
}

public struct TTSplashCarousel: Codable {
    public let slides: [TTCarouselSlide]
    /// "horizontal" or "vertical". Defaults to "horizontal".
    public let direction: String
    public let bgColor: String?
    public let textColor: String?
    /// Independent show-count limit for the carousel. nil = infinite.
    public let maxShows: Int?

    public init(slides: [TTCarouselSlide], direction: String = "horizontal",
                bgColor: String? = nil, textColor: String? = nil, maxShows: Int? = nil) {
        self.slides = slides; self.direction = direction
        self.bgColor = bgColor; self.textColor = textColor; self.maxShows = maxShows
    }
}

public struct TTCarouselSlide: Codable {
    public let logoUrl: String?
    public let imageUrl: String?
    public let title: String?
    public let description: String?
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
    /// Width/height of the minimised launcher button in points. Default 44.
    public let size: Double?
    enum CodingKeys: String, CodingKey {
        case bgColor = "bg_color"
        case borderRadius = "border_radius"
        case icon
        case position
        case bottomOffset = "bottom_offset"
        case size
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

// MARK: - UIColor hex / rgba helper

extension UIColor {
    convenience init?(hex: String) {
        let str = hex.trimmingCharacters(in: .whitespacesAndNewlines)

        // rgba(r,g,b,a) or rgb(r,g,b)
        if str.lowercased().hasPrefix("rgb") {
            let nums = str
                .drop(while: { $0 != "(" }).dropFirst()
                .prefix(while: { $0 != ")" })
                .split(separator: ",")
                .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            guard nums.count >= 3 else { return nil }
            self.init(
                red:   CGFloat(nums[0]) / 255,
                green: CGFloat(nums[1]) / 255,
                blue:  CGFloat(nums[2]) / 255,
                alpha: nums.count >= 4 ? CGFloat(nums[3]) : 1
            )
            return
        }

        // #RRGGBB hex
        var h = str
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let rgb = UInt64(h, radix: 16) else { return nil }
        self.init(
            red:   CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8)  & 0xFF) / 255,
            blue:  CGFloat( rgb        & 0xFF) / 255,
            alpha: 1
        )
    }
}
