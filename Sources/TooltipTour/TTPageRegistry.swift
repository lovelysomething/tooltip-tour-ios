import SwiftUI

/// Tracks which screen the user is currently viewing.
/// Populated automatically by the `.ttPage()` view modifier.
@MainActor
public final class TTPageRegistry: ObservableObject {
    public static let shared = TTPageRegistry()

    /// The identifier of the most recently appeared screen.
    @Published private(set) public var currentPage: String?

    // Stack so nested/overlaid views resolve correctly on disappear.
    private var pageStack: [String] = []

    private init() {}

    func setPage(_ id: String) {
        pageStack.removeAll { $0 == id }
        pageStack.append(id)
        currentPage = id
    }

    func clearPage(_ id: String) {
        pageStack.removeAll { $0 == id }
        currentPage = pageStack.last
    }
}

// MARK: - Environment key so TTLauncherView can read its page without timing races

private struct TTPageEnvironmentKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    var ttPageIdentifier: String? {
        get { self[TTPageEnvironmentKey.self] }
        set { self[TTPageEnvironmentKey.self] = newValue }
    }
}

/// View modifier that registers the current screen identifier with TTPageRegistry.
public struct TTPage: ViewModifier {
    let identifier: String

    public func body(content: Content) -> some View {
        content
            .environment(\.ttPageIdentifier, identifier)  // available before onAppear
            .onAppear  { TTPageRegistry.shared.setPage(identifier)   }
            .onDisappear { TTPageRegistry.shared.clearPage(identifier) }
    }
}

public extension View {
    /// Register this view as the current screen for Tooltip Tour page targeting.
    /// Add to the root view of each screen/tab:
    /// ```swift
    /// struct HomeView: View {
    ///     var body: some View {
    ///         VStack { … }
    ///             .ttPage("home")
    ///     }
    /// }
    /// ```
    func ttPage(_ identifier: String) -> some View {
        modifier(TTPage(identifier: identifier))
    }
}
