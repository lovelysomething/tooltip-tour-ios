import SwiftUI
import Combine

// MARK: - Scroll Bus

/// Simple observable that the session writes to and .ttScrollable() reads from.
@MainActor
public final class TTScrollBus: ObservableObject {
    public static let shared = TTScrollBus()
    private init() {}

    /// Set to a target id to trigger a scroll; automatically cleared after firing.
    @Published var scrollTarget: String? = nil

    func scrollTo(_ id: String) {
        scrollTarget = id
        // Clear after a tick so the same id can be re-triggered on subsequent steps
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.scrollTarget = nil
        }
    }
}

// MARK: - .ttScrollable() modifier

/// Wrap a ScrollView's content with this modifier so the SDK can scroll it to any
/// registered target. Usage:
///
///     ScrollView {
///         VStack { ... }
///             .ttScrollable()
///     }
public struct TTScrollableModifier: ViewModifier {
    @ObservedObject private var bus = TTScrollBus.shared

    public func body(content: Content) -> some View {
        ScrollViewReader { proxy in
            content
                .onChange(of: bus.scrollTarget) { target in
                    guard let id = target else { return }
                    withAnimation(.easeInOut(duration: 0.4)) {
                        proxy.scrollTo(id, anchor: .top)
                    }
                }
        }
    }
}

public extension View {
    /// Enables SDK-driven scrolling for a ScrollView's content.
    /// Place this on the direct child of a ScrollView that contains .ttTarget() views.
    func ttScrollable() -> some View {
        modifier(TTScrollableModifier())
    }
}
