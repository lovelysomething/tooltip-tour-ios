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
    public let steps: [TTStep]
    public let styles: TTStyles?
}

public struct TTStep: Codable {
    public let title: String
    public let content: String
    /// The UIView.accessibilityIdentifier to highlight for this step
    public let selector: String
}

public struct TTStyles: Codable {
    public let primaryColor: String?
    public let buttonRadius: Double?
    public let cardRadius: Double?

    public var resolvedPrimaryColor: UIColor {
        guard let hex = primaryColor else { return UIColor(red: 0.098, green: 0.145, blue: 0.667, alpha: 1) }
        return UIColor(hex: hex) ?? UIColor(red: 0.098, green: 0.145, blue: 0.667, alpha: 1)
    }
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
