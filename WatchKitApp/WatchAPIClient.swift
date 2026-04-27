import Foundation

/// Stripped-down API client for watchOS — no UIKit, no Combine,
/// same endpoints as iOS APIClient but using WatchAuthManager.
class WatchAPIClient {
    let auth: WatchAuthManager
    private var refreshTask: Task<TokenResponse, Error>?

    init(auth: WatchAuthManager) { self.auth = auth }

    /// Applies Cloudflare Access service token headers if configured.
    private func applyCFHeaders(to req: inout URLRequest) {
        if let id = KeychainHelper.get(key: "sheaf_cf_client_id"), !id.isEmpty,
           let secret = KeychainHelper.get(key: "sheaf_cf_client_secret"), !secret.isEmpty {
            req.setValue(id, forHTTPHeaderField: "CF-Access-Client-Id")
            req.setValue(secret, forHTTPHeaderField: "CF-Access-Client-Secret")
        }
    }

    private func request(_ path: String, method: String = "GET", body: Data? = nil) async throws -> Data {
        let (data, status) = try await perform(path, method: method, body: body)
        if status != 401 { return data }

        do {
            _ = try await refreshOnce()
        } catch {
            let code = (error as NSError).code
            if code == 401 || code == 403 {
                let detail = (error as NSError).localizedDescription
                if detail.localizedCaseInsensitiveContains("session revoked") {
                    await MainActor.run { auth.logout() }
                    // Force the phone to mint a fresh companion session —
                    // the one we had is dead and reusing the cached one
                    // would just loop us right back here.
                    WatchConnectivityManager.shared.requestCredentials(force: true)
                    throw URLError(.userAuthenticationRequired)
                }
                // Retry refresh once more to handle rotation races
                do {
                    try await Task.sleep(nanoseconds: 500_000_000)
                    _ = try await refreshOnce()
                } catch {
                    await MainActor.run { auth.logout() }
                    // Both refreshes failed — credentials are clearly dead,
                    // ask the phone for a fresh companion session.
                    WatchConnectivityManager.shared.requestCredentials(force: true)
                    throw URLError(.userAuthenticationRequired)
                }
            } else {
                throw error
            }
        }

        let (retryData, retryStatus) = try await perform(path, method: method, body: body)
        guard retryStatus != 401 else {
            await MainActor.run { auth.logout() }
            // Refresh succeeded but the retried request still 401'd — the
            // session is gone, force a fresh mint.
            WatchConnectivityManager.shared.requestCredentials(force: true)
            throw URLError(.userAuthenticationRequired)
        }
        return retryData
    }

    private func perform(_ path: String, method: String, body: Data?) async throws -> (Data, Int) {
        guard let url = URL(string: auth.baseURL + path) else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(auth.accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        applyCFHeaders(to: &req)
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = body
        }
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if http.statusCode != 401 && !(200...299).contains(http.statusCode) {
            let msg = String(data: data, encoding: .utf8) ?? "(no body)"
            throw NSError(domain: "APIError", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(msg)"])
        }
        return (data, http.statusCode)
    }

    @MainActor
    private func refreshOnce() async throws -> TokenResponse {
        if let existing = refreshTask { return try await existing.value }

        guard !auth.refreshToken.isEmpty else {
            throw NSError(domain: "APIError", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "No refresh token available."])
        }
        guard let url = URL(string: auth.baseURL + "/v1/auth/refresh") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyCFHeaders(to: &req)
        req.httpBody = try JSONEncoder.iso.encode(TokenRefresh(refreshToken: auth.refreshToken))

        let task = Task<TokenResponse, Error> {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            guard (200...299).contains(http.statusCode) else {
                let detail: String
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let msg = json["detail"] as? String, !msg.isEmpty {
                    detail = msg
                } else {
                    detail = "HTTP \(http.statusCode)"
                }
                throw NSError(domain: "APIError", code: http.statusCode,
                              userInfo: [NSLocalizedDescriptionKey: detail])
            }
            return try JSONDecoder.iso.decode(TokenResponse.self, from: data)
        }
        refreshTask = task
        defer { refreshTask = nil }
        let fresh = try await task.value
        auth.save(baseURL: auth.baseURL,
                  accessToken: fresh.accessToken,
                  refreshToken: fresh.refreshToken)
        return fresh
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

    @discardableResult
    func deleteGroup(id: String, confirmation: MemberDeleteConfirm? = nil) async throws -> DeleteQueued? {
        let body = confirmation != nil ? try JSONEncoder.iso.encode(confirmation) : nil
        let data = try await request("/v1/groups/\(id)", method: "DELETE", body: body)
        guard !data.isEmpty else { return nil }
        return try? JSONDecoder.iso.decode(DeleteQueued.self, from: data)
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
