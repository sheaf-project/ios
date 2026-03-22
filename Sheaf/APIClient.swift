import Foundation
import SwiftUI
import Combine
#if os(iOS)
import WatchConnectivity
#endif

// MARK: - AuthManager
final class AuthManager: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var needsTOTP: Bool = false        // true while awaiting TOTP verification
    @Published var accessToken: String = ""
    @Published var refreshToken: String = ""
    @Published var baseURL: String = ""

    // Held during TOTP step so we can finalize after verification
    private(set) var pendingTokens: TokenResponse?
    private(set) var pendingBaseURL: String = ""

    private let accessKey  = "sheaf_access_token"
    private let refreshKey = "sheaf_refresh_token"
    private let urlKey     = "sheaf_base_url"

    init() {
        // Load from iCloud Keychain (syncs to watch automatically)
        accessToken  = KeychainHelper.get(key: accessKey) ?? ""
        refreshToken = KeychainHelper.get(key: refreshKey) ?? ""
        baseURL      = KeychainHelper.get(key: urlKey) ?? ""
        isAuthenticated = !accessToken.isEmpty && !baseURL.isEmpty
        
        NSLog("📱 AuthManager: Loaded from Keychain - isAuthenticated: \(isAuthenticated)")
        
        // Configure connectivity manager immediately
        #if os(iOS)
        PhoneConnectivityManager.shared.configure(auth: self)
        #endif
    }

    /// Call after a successful login when the account has TOTP enabled.
    /// Stores credentials temporarily until the OTP is verified.
    func awaitTOTP(baseURL: String, tokens: TokenResponse) {
        let cleanURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        pendingBaseURL = cleanURL
        pendingTokens  = tokens
        // Apply the access token now so the /totp/verify request can be authenticated
        self.baseURL      = cleanURL
        self.accessToken  = tokens.accessToken
        self.refreshToken = tokens.refreshToken
        needsTOTP = true
    }

    /// Call once TOTP is verified to finalize the session.
    func completeTOTP() {
        guard let tokens = pendingTokens else { return }
        save(baseURL: pendingBaseURL, tokens: tokens)
        pendingTokens = nil
        needsTOTP = false
    }

    /// Call if TOTP verification is cancelled or fails fatally.
    func cancelTOTP() {
        pendingTokens  = nil
        pendingBaseURL = ""
        accessToken    = ""
        refreshToken   = ""
        baseURL        = ""
        needsTOTP      = false
    }

    func save(baseURL: String, tokens: TokenResponse) {
        let cleanURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        self.baseURL      = cleanURL
        self.accessToken  = tokens.accessToken
        self.refreshToken = tokens.refreshToken
        self.isAuthenticated = true
        needsTOTP = false
        
        // Save to iCloud Keychain (will sync to watch automatically)
        do {
            try KeychainHelper.save(key: urlKey, value: cleanURL)
            try KeychainHelper.save(key: accessKey, value: tokens.accessToken)
            try KeychainHelper.save(key: refreshKey, value: tokens.refreshToken)
            NSLog("📱 AuthManager: Credentials saved to iCloud Keychain")
        } catch {
            NSLog("❌ AuthManager: Keychain save failed: \(error)")
        }
        
        // Also keep in UserDefaults for backwards compatibility
        UserDefaults.standard.set(cleanURL,            forKey: urlKey)
        UserDefaults.standard.set(tokens.accessToken,  forKey: accessKey)
        UserDefaults.standard.set(tokens.refreshToken, forKey: refreshKey)
        
        NSLog("📱 AuthManager: Credentials saved locally")
        NSLog("📱 AuthManager: baseURL: \(cleanURL)")
        NSLog("📱 AuthManager: accessToken length: \(tokens.accessToken.count)")
        
        // Still try WatchConnectivity as a backup for instant sync
        #if os(iOS)
        NSLog("📱 AuthManager: Attempting to sync to watch via WatchConnectivity...")
        PhoneConnectivityManager.shared.syncCredentials()
        #endif
    }

    func logout() {
        accessToken  = ""
        refreshToken = ""
        baseURL      = ""
        isAuthenticated = false
        needsTOTP      = false
        pendingTokens  = nil
        
        // Delete from Keychain
        KeychainHelper.deleteAll()
        
        // Delete from UserDefaults
        UserDefaults.standard.removeObject(forKey: accessKey)
        UserDefaults.standard.removeObject(forKey: refreshKey)
        UserDefaults.standard.removeObject(forKey: urlKey)
        
        #if os(iOS)
        try? WCSession.default.updateApplicationContext(
            ["baseURL": "", "accessToken": "", "refreshToken": ""]
        )
        #endif
    }
}

// MARK: - APIClient
class APIClient {
    let auth: AuthManager

    /// Serialises concurrent refresh attempts so only one goes out at a time.
    private var refreshTask: Task<TokenResponse, Error>?

    init(auth: AuthManager) {
        self.auth = auth
    }

    // MARK: Request + auto-refresh

    private func request(_ path: String, method: String = "GET", body: Data? = nil) async throws -> Data {
        // First attempt
        let (data, status) = try await perform(path, method: method, body: body)
        if status != 401 { return data }

        // 401 — try to refresh once, then retry
        let fresh = try await refreshOnce()
        await MainActor.run { auth.save(baseURL: auth.baseURL, tokens: fresh) }

        let (retryData, retryStatus) = try await perform(path, method: method, body: body)
        guard retryStatus != 401 else {
            // Refresh token is also dead — force logout
            await MainActor.run { auth.logout() }
            throw NSError(domain: "APIError", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Session expired. Please log in again."])
        }
        return retryData
    }

    /// Sends a single URLRequest and returns (data, httpStatusCode).
    private func perform(_ path: String, method: String, body: Data?) async throws -> (Data, Int) {
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
        // Throw for all errors except 401 (which we handle via retry) and 204 (no content)
        if http.statusCode != 401 && !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "(no body)"
            throw NSError(domain: "APIError", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(body)"])
        }
        return (data, http.statusCode)
    }

    /// Coalesces concurrent refresh calls into one network request.
    private func refreshOnce() async throws -> TokenResponse {
        if let existing = refreshTask { return try await existing.value }
        let task = Task<TokenResponse, Error> {
            defer { refreshTask = nil }
            guard !auth.refreshToken.isEmpty else {
                throw NSError(domain: "APIError", code: 401,
                              userInfo: [NSLocalizedDescriptionKey: "No refresh token available."])
            }
            let body = try JSONEncoder.iso.encode(TokenRefresh(refreshToken: auth.refreshToken))
            guard let url = URL(string: auth.baseURL + "/v1/auth/refresh") else { throw URLError(.badURL) }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            req.httpBody = body
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw NSError(domain: "APIError", code: 401,
                              userInfo: [NSLocalizedDescriptionKey: "Token refresh failed."])
            }
            return try JSONDecoder.iso.decode(TokenResponse.self, from: data)
        }
        refreshTask = task
        return try await task.value
    }

    // MARK: - Auth

    func login(email: String, password: String, totpCode: String? = nil) async throws -> TokenResponse {
        let body = try JSONEncoder.iso.encode(UserLogin(email: email, password: password, totpCode: totpCode))
        // Don't use request() because login endpoints shouldn't trigger token refresh
        let (data, status) = try await perform("/v1/auth/login", method: "POST", body: body)
        guard status == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "Login failed"
            throw NSError(domain: "APIError", code: status,
                         userInfo: [NSLocalizedDescriptionKey: message])
        }
        return try JSONDecoder.iso.decode(TokenResponse.self, from: data)
    }

    func register(email: String, password: String) async throws -> TokenResponse {
        let body = try JSONEncoder.iso.encode(UserRegister(email: email, password: password))
        // Don't use request() because register endpoints shouldn't trigger token refresh
        let (data, status) = try await perform("/v1/auth/register", method: "POST", body: body)
        guard (200...201).contains(status) else {
            let message = String(data: data, encoding: .utf8) ?? "Registration failed"
            throw NSError(domain: "APIError", code: status,
                         userInfo: [NSLocalizedDescriptionKey: message])
        }
        return try JSONDecoder.iso.decode(TokenResponse.self, from: data)
    }

    func refreshTokens() async throws -> TokenResponse {
        let body = try JSONEncoder.iso.encode(TokenRefresh(refreshToken: auth.refreshToken))
        let data = try await request("/v1/auth/refresh", method: "POST", body: body)
        return try JSONDecoder.iso.decode(TokenResponse.self, from: data)
    }

    /// Verify a 6-digit TOTP code. Requires a valid access token already set on auth.
    func verifyTOTP(code: String) async throws {
        let body = try JSONEncoder.iso.encode(TOTPVerify(code: code))
        _ = try await request("/v1/auth/totp/verify", method: "POST", body: body)
    }

    /// Initiate TOTP setup — returns secret, provisioning URI, and recovery codes.
    func setupTOTP() async throws -> TOTPSetupResponse {
        let data = try await request("/v1/auth/totp/setup", method: "POST")
        return try JSONDecoder.iso.decode(TOTPSetupResponse.self, from: data)
    }

    // MARK: - System

    func getMe() async throws -> UserRead {
        let data = try await request("/v1/auth/me")
        return try JSONDecoder.iso.decode(UserRead.self, from: data)
    }
    
    /// Version of getMe that doesn't auto-retry on 401 (for login flow TOTP detection)
    func getMeWithoutRetry() async throws -> UserRead {
        let (data, status) = try await perform("/v1/auth/me", method: "GET", body: nil)
        guard status == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "Request failed"
            throw NSError(domain: "APIError", code: status,
                         userInfo: [NSLocalizedDescriptionKey: message])
        }
        return try JSONDecoder.iso.decode(UserRead.self, from: data)
    }

    func getMySystem() async throws -> SystemProfile {
        let data = try await request("/v1/systems/me")
        return try JSONDecoder.iso.decode(SystemProfile.self, from: data)
    }

    func updateMySystem(_ update: SystemUpdate) async throws -> SystemProfile {
        let body = try JSONEncoder.iso.encode(update)
        let data = try await request("/v1/systems/me", method: "PATCH", body: body)
        return try JSONDecoder.iso.decode(SystemProfile.self, from: data)
    }

    // MARK: - Members

    func getMembers() async throws -> [Member] {
        let data = try await request("/v1/members")
        return try JSONDecoder.iso.decode([Member].self, from: data)
    }

    func createMember(_ create: MemberCreate) async throws -> Member {
        let body = try JSONEncoder.iso.encode(create)
        let data = try await request("/v1/members", method: "POST", body: body)
        return try JSONDecoder.iso.decode(Member.self, from: data)
    }

    func getMember(id: String) async throws -> Member {
        let data = try await request("/v1/members/\(id)")
        return try JSONDecoder.iso.decode(Member.self, from: data)
    }

    func updateMember(id: String, update: MemberUpdate) async throws -> Member {
        let body = try JSONEncoder.iso.encode(update)
        let data = try await request("/v1/members/\(id)", method: "PATCH", body: body)
        return try JSONDecoder.iso.decode(Member.self, from: data)
    }

    func deleteMember(id: String) async throws {
        _ = try await request("/v1/members/\(id)", method: "DELETE")
    }

    // MARK: - Fronts

    /// Returns array — current fronts can be co-front (multiple entries)
    func getCurrentFronts() async throws -> [FrontEntry] {
        let data = try await request("/v1/fronts/current")
        return try JSONDecoder.iso.decode([FrontEntry].self, from: data)
    }

    func listFronts(limit: Int = 50, offset: Int = 0) async throws -> [FrontEntry] {
        let data = try await request("/v1/fronts?limit=\(limit)&offset=\(offset)")
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

    func deleteFront(id: String) async throws {
        _ = try await request("/v1/fronts/\(id)", method: "DELETE")
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

    func updateGroup(id: String, update: GroupUpdate) async throws -> SystemGroup {
        let body = try JSONEncoder.iso.encode(update)
        let data = try await request("/v1/groups/\(id)", method: "PATCH", body: body)
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

    // MARK: - Tags

    func getTags() async throws -> [Tag] {
        let data = try await request("/v1/tags")
        return try JSONDecoder.iso.decode([Tag].self, from: data)
    }

    func createTag(_ create: TagCreate) async throws -> Tag {
        let body = try JSONEncoder.iso.encode(create)
        let data = try await request("/v1/tags", method: "POST", body: body)
        return try JSONDecoder.iso.decode(Tag.self, from: data)
    }

    func deleteTag(id: String) async throws {
        _ = try await request("/v1/tags/\(id)", method: "DELETE")
    }

    func deleteField(id: String) async throws {
        _ = try await request("/v1/fields/\(id)", method: "DELETE")
    }

    func updateField(id: String, name: String, privacy: PrivacyLevel) async throws -> CustomField {
        let body = try JSONEncoder.iso.encode(["name": name, "privacy": privacy.rawValue])
        let data = try await request("/v1/fields/\(id)", method: "PATCH", body: body)
        return try JSONDecoder.iso.decode(CustomField.self, from: data)
    }

    // MARK: - Custom Fields

    func getFields() async throws -> [CustomField] {
        let data = try await request("/v1/fields")
        return try JSONDecoder.iso.decode([CustomField].self, from: data)
    }

    func createField(_ create: CustomFieldCreate) async throws -> CustomField {
        let body = try JSONEncoder.iso.encode(create)
        let data = try await request("/v1/fields", method: "POST", body: body)
        return try JSONDecoder.iso.decode(CustomField.self, from: data)
    }

    func getMemberFieldValues(memberID: String) async throws -> [CustomFieldValue] {
        let data = try await request("/v1/members/\(memberID)/fields")
        return try JSONDecoder.iso.decode([CustomFieldValue].self, from: data)
    }

    func setMemberFieldValues(memberID: String, values: [CustomFieldValueSet]) async throws -> [CustomFieldValue] {
        let body = try JSONEncoder.iso.encode(values)
        let data = try await request("/v1/members/\(memberID)/fields", method: "PUT", body: body)
        return try JSONDecoder.iso.decode([CustomFieldValue].self, from: data)
    }

    // MARK: - Export

    func exportData() async throws -> Data {
        return try await request("/v1/export")
    }

    // MARK: - File Upload


    // MARK: - Simply Plural Import

    func previewSimplyPluralImport(fileData: Data, filename: String) async throws -> SPPreviewSummary {
        let data = try await multipartRequest(
            path: "/v1/import/simplyplural/preview",
            fileData: fileData,
            filename: filename
        )
        return try JSONDecoder.iso.decode(SPPreviewSummary.self, from: data)
    }

    func doSimplyPluralImport(
        fileData: Data,
        filename: String,
        systemProfile: Bool = true,
        memberIDs: [String]? = nil,
        customFronts: Bool = true,
        customFields: Bool = true,
        groups: Bool = true,
        frontHistory: Bool = false,
        notes: Bool = false
    ) async throws -> SPImportResult {
        var path = "/v1/import/simplyplural?system_profile=\(systemProfile)&custom_fronts=\(customFronts)&custom_fields=\(customFields)&groups=\(groups)&front_history=\(frontHistory)&notes=\(notes)"
        if let ids = memberIDs, !ids.isEmpty {
            path += "&member_ids=\(ids.joined(separator: ","))"
        }
        let data = try await multipartRequest(path: path, fileData: fileData, filename: filename)
        return try JSONDecoder.iso.decode(SPImportResult.self, from: data)
    }

    /// Shared multipart/form-data helper for file uploads
    private func multipartRequest(path: String, fileData: Data, filename: String) async throws -> Data {
        guard let url = URL(string: auth.baseURL + path) else { throw URLError(.badURL) }
        let boundary = "Boundary-\(UUID().uuidString)"
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(auth.accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "(no body)"
            throw NSError(domain: "APIError", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(msg)"])
        }
        return data
    }

    func uploadFile(imageData: Data, mimeType: String = "image/jpeg") async throws -> String {
        guard let url = URL(string: auth.baseURL + "/v1/files/upload") else {
            throw URLError(.badURL)
        }
        let boundary = "Boundary-\(UUID().uuidString)"
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(auth.accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"upload.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "(no body)"
            throw NSError(domain: "APIError", code: (response as? HTTPURLResponse)?.statusCode ?? 0,
                          userInfo: [NSLocalizedDescriptionKey: msg])
        }
        // API returns freeform JSON — just extract a url string if present
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let urlStr = json["url"] as? String {
            return urlStr
        }
        return ""
    }
}

// MARK: - SystemUpdate (separate from SystemRead for PATCH)
struct SystemUpdate: Codable {
    var name: String?
    var description: String?
    var tag: String?
    var avatarURL: String?
    var color: String?
    var privacy: PrivacyLevel?

    enum CodingKeys: String, CodingKey {
        case name, description, tag, color, privacy
        case avatarURL = "avatar_url"
    }
}

// MARK: - JSON Decoder/Encoder with ISO8601 dates
extension JSONDecoder {
    static let iso: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let str = try decoder.singleValueContainer().decode(String.self)
            // Try fractional seconds first, then plain ISO8601
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
