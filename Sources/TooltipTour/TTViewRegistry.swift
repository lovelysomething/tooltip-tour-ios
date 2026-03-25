import SwiftUI

/// Stores screen-space frames for views tagged with `.ttTarget()`.
/// SwiftUI's internal UIView hierarchy isn't accessible externally on iOS 17+,
/// so we capture frames via GeometryReader instead.
@MainActor
public final class TTViewRegistry {
    public static let shared = TTViewRegistry()
    private var frames: [String: CGRect] = [:]

    private init() {}

    func register(identifier: String, frame: CGRect) {
        frames[identifier] = frame
    }

    func frame(for identifier: String) -> CGRect? {
        frames[identifier]
    }
}

/// View modifier that registers a view's screen frame with TTViewRegistry.
public struct TTTarget: ViewModifier {
    let identifier: String

    public func body(content: Content) -> some View {
        content
            .id(identifier)          // required for ScrollViewProxy.scrollTo(_:anchor:)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            TTViewRegistry.shared.register(
                                identifier: identifier,
                                frame: geo.frame(in: .global)
                            )
                        }
                        .onChange(of: geo.frame(in: .global)) { newFrame in
                            TTViewRegistry.shared.register(
                                identifier: identifier,
                                frame: newFrame
                            )
                        }
                }
            )
    }
}

public extension View {
    /// Register this view as a tooltip tour target with the given identifier.
    /// The identifier must match the Accessibility Identifier set in the dashboard.
    func ttTarget(_ identifier: String) -> some View {
        modifier(TTTarget(identifier: identifier))
    }
}
