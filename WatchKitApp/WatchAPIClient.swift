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

    func createMember(_ create: MemberCreate) async throws -> Member {
        let body = try JSONEncoder.iso.encode(create)
        let data = try await request("/v1/members", method: "POST", body: body)
        return try JSONDecoder.iso.decode(Member.self, from: data)
    }

    // MARK: - Groups

    func getGroups() async throws -> [SystemGroup] {
        let data = try await request("/v1/groups")
        return try JSONDecoder.iso.decode([SystemGroup].self, from: data)
    }

    func createGroup(_ create: GroupCreate) async throws -> SystemGroup {
        let body = try JSONEncoder.iso.encode(create)
        let data = try await request("/v1/groups", method: "POST", body: body)
        return try JSONDecoder.iso.decode(SystemGroup.self, from: data)
    }

    func deleteGroup(id: String) async throws {
        _ = try await request("/v1/groups/\(id)", method: "DELETE")
    }

    func getGroupMembers(groupID: String) async throws -> [Member] {
        let data = try await request("/v1/groups/\(groupID)/members")
        return try JSONDecoder.iso.decode([Member].self, from: data)
    }

    func setGroupMembers(groupID: String, memberIDs: [String]) async throws -> [Member] {
        let body = try JSONEncoder.iso.encode(GroupMemberUpdate(memberIDs: memberIDs))
        let data = try await request("/v1/groups/\(groupID)/members", method: "PUT", body: body)
        return try JSONDecoder.iso.decode([Member].self, from: data)
    }

    func updateFront(id: String, update: FrontUpdate) async throws -> FrontEntry {
        let body = try JSONEncoder.iso.encode(update)
        let data = try await request("/v1/fronts/\(id)", method: "PATCH", body: body)
        return try JSONDecoder.iso.decode(FrontEntry.self, from: data)
    }
}

// JSON helpers are provided by APIClient.swift when both files are in the same target.
// This file only defines them when compiled standalone (e.g. in a test target).
