import Foundation

final class TTNetworkClient {
    let baseURL: String

    init(baseURL: String) {
        self.baseURL = baseURL
    }

    func fetchConfig(siteKey: String) async throws -> TTConfig? {
        guard let url = URL(string: "\(baseURL)/api/walkthrough/\(siteKey)") else { return nil }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse else { return nil }
        // 204 = no active walkthrough, 402 = view limit reached
        guard http.statusCode == 200 else { return nil }
        return try JSONDecoder().decode(TTConfig.self, from: data)
    }

    /// PATCH /api/inspector/sessions/{id} — writes captured element back to the dashboard.
    /// Uses the custom baseURL so it works for any host.
    func updateInspectorSession(id: String, identifier: String, displayName: String) async throws {
        guard let url = URL(string: "\(baseURL)/api/inspector/sessions/\(id)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = ["identifier": identifier, "display_name": displayName]
        request.httpBody = try JSONEncoder().encode(body)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }
}
