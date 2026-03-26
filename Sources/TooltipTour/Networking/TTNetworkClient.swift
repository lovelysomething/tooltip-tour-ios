import Foundation

final class TTNetworkClient {
    let baseURL: String

    init(baseURL: String) {
        self.baseURL = baseURL
    }

    /// Fetch all active tour configs for a site in one request.
    /// Returns a dictionary keyed by page pattern for instant lookup.
    func fetchAllConfigs(siteKey: String) async throws -> [String: TTConfig] {
        guard let url = URL(string: "\(baseURL)/api/walkthrough/\(siteKey)?prefetch=true") else { return [:] }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [:] }
        let configs = try JSONDecoder().decode([TTConfig].self, from: data)
        return Dictionary(uniqueKeysWithValues: configs.compactMap { c in
            guard let pattern = c.pagePattern else { return nil }
            return (pattern, c)
        })
    }

    func fetchConfig(siteKey: String, page: String? = nil) async throws -> TTConfig? {
        var urlString = "\(baseURL)/api/walkthrough/\(siteKey)"
        if let page = page, !page.isEmpty {
            let encoded = page.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? page
            urlString += "?page=\(encoded)"
        }
        guard let url = URL(string: urlString) else { return nil }
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
