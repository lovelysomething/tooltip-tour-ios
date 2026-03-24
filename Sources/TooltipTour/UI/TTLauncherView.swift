import SwiftUI

/// Drop-in SwiftUI launcher button. Place in your root view and it handles the rest.
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
                            HStack(spacing: 8) {
                                Text(config.fabLabel ?? "Take a tour")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(state.primaryColor)
                            .clipShape(Capsule())
                            .shadow(color: state.primaryColor.opacity(0.4), radius: 10, x: 0, y: 4)
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

    var primaryColor: Color {
        guard let hex = config?.styles?.primaryColor,
              let uiColor = UIColor(hex: hex) else {
            return Color(red: 0.098, green: 0.145, blue: 0.667)
        }
        return Color(uiColor)
    }

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
