import Foundation

enum TTEventType: String {
    case guideShown       = "guide_shown"
    case stepCompleted    = "step_completed"
    case guideCompleted   = "guide_completed"
    case guideDismissed   = "guide_dismissed"
}

final class TTEventTracker {
    private let baseURL: String
    private let sessionId = UUID().uuidString

    init(baseURL: String) {
        self.baseURL = baseURL
    }

    func track(
        event: TTEventType,
        walkthroughId: String,
        siteKey: String,
        stepIndex: Int? = nil
    ) {
        guard let url = URL(string: "\(baseURL)/api/events") else { return }
        var body: [String: Any] = [
            "walkthroughId": walkthroughId,
            "siteKey":       siteKey,
            "eventType":     event.rawValue,
            "sessionId":     sessionId,
        ]
        if let stepIndex { body["stepIndex"] = stepIndex }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request).resume()
    }
}
