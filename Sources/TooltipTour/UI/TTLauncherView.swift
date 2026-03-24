import SwiftUI

/// Drop-in SwiftUI launcher button. Place in your root view's ZStack and it handles the rest.
///
/// Usage:
/// ```swift
/// ZStack {
///     ContentView()
///     TTLauncherView()
/// }
/// ```
public struct TTLauncherView: View {
    @StateObject private var state = TTLauncherState()

    public init() {}

    public var body: some View {
        GeometryReader { _ in
            if state.isReady, let config = state.config {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { TooltipTour.shared.startSession(config: config) }) {
                            Text(config.fabLabel ?? "Take a tour")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(state.fabTextColor)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 12)
                                .background(state.fabBgColor)
                                .clipShape(Capsule())
                                .shadow(color: state.fabBgColor.opacity(0.4), radius: 10, x: 0, y: 4)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 32)
                    }
                }
                .ignoresSafeArea()
            }
        }
        .onAppear { state.load() }
    }
}

@MainActor
private final class TTLauncherState: ObservableObject {
    @Published var config: TTConfig?
    @Published var isReady = false

    var fabBgColor: Color {
        Color(config?.styles?.resolvedFabBgColor ?? .systemIndigo)
    }

    // FAB always uses white text — bg_color is always dark/saturated in practice
    var fabTextColor: Color { .white }

    func load() {
        Task {
            config = await TooltipTour.shared.loadConfig()
            isReady = config != nil
            if config?.autoOpen == true {
                TooltipTour.shared.startSession(config: config!)
            }
        }
    }
}
