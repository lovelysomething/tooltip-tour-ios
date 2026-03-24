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
}
