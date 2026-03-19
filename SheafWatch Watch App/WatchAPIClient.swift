import Foundation

/// Stripped-down API client for watchOS — no UIKit, no Combine,
/// same endpoints as iOS APIClient but using WatchAuthManager.
class WatchAPIClient {
    let auth: WatchAuthManager

    init(auth: WatchAuthManager) { self.auth = auth }

    private func request(_ path: String, method: String = "GET", body: Data? = nil) async throws -> Data {
        guard let url = URL(string: auth.baseURL + path) else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(auth.accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = body
        }
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if http.statusCode == 401 {
            // Attempt token refresh then retry once
            if let fresh = try? await refreshTokens() {
                await MainActor.run {
                    auth.save(baseURL: auth.baseURL,
                              accessToken: fresh.accessToken,
                              refreshToken: fresh.refreshToken)
                }
                return try await request(path, method: method, body: body)
            }
            await MainActor.run { auth.logout() }
            throw URLError(.userAuthenticationRequired)
        }
        guard (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "(no body)"
            throw NSError(domain: "APIError", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(msg)"])
        }
        return data
    }

    private func refreshTokens() async throws -> TokenResponse {
        guard let url = URL(string: auth.baseURL + "/v1/auth/refresh") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder.iso.encode(TokenRefresh(refreshToken: auth.refreshToken))
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder.iso.decode(TokenResponse.self, from: data)
    }

    func login(email: String, password: String) async throws -> TokenResponse {
        let body = try JSONEncoder.iso.encode(UserLogin(email: email, password: password))
        let data = try await request("/v1/auth/login", method: "POST", body: body)
        return try JSONDecoder.iso.decode(TokenResponse.self, from: data)
    }

    func getMembers() async throws -> [Member] {
        let data = try await request("/v1/members")
        return try JSONDecoder.iso.decode([Member].self, from: data)
    }

    func getCurrentFronts() async throws -> [FrontEntry] {
        let data = try await request("/v1/fronts/current")
        return try JSONDecoder.iso.decode([FrontEntry].self, from: data)
    }

    func createFront(_ create: FrontCreate) async throws -> FrontEntry {
        let body = try JSONEncoder.iso.encode(create)
        let data = try await request("/v1/fronts", method: "POST", body: body)
        return try JSONDecoder.iso.decode(FrontEntry.self, from: data)
    }

    func updateFront(id: String, update: FrontUpdate) async throws -> FrontEntry {
        let body = try JSONEncoder.iso.encode(update)
        let data = try await request("/v1/fronts/\(id)", method: "PATCH", body: body)
        return try JSONDecoder.iso.decode(FrontEntry.self, from: data)
    }
}

// MARK: - JSON helpers (duplicated from APIClient.swift for watch target)
extension JSONDecoder {
    static let iso: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let str = try decoder.singleValueContainer().decode(String.self)
            let frac = ISO8601DateFormatter()
            frac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = frac.date(from: str) { return date }
            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            if let date = plain.date(from: str) { return date }
            throw DecodingError.dataCorruptedError(
                in: try decoder.singleValueContainer(),
                debugDescription: "Cannot decode date: \(str)"
            )
        }
        return d
    }()
}

extension JSONEncoder {
    static let iso: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}
