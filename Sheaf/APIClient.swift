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
    @Published var accountStatus: AccountStatus = .active
    @Published var emailVerified: Bool = true
    @Published var deletionGraceDays: Int?
    @Published var deletionRequestedAt: Date?

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
        
        debugLog("AuthManager: Loaded from Keychain - isAuthenticated: \(isAuthenticated)")
        
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
        } catch {
            debugLog("AuthManager: Keychain save failed: \(error)")
        }
        
        debugLog("AuthManager: Credentials saved to iCloud Keychain")
        
        // Still try WatchConnectivity as a backup for instant sync
        #if os(iOS)
        debugLog("AuthManager: Attempting to sync to watch via WatchConnectivity...")
        PhoneConnectivityManager.shared.syncCredentials()
        #endif
    }

    func logout() {
        // Server-side logout (best-effort, fire-and-forget)
        if !accessToken.isEmpty, !baseURL.isEmpty {
            let api = APIClient(auth: self)
            Task { await api.logout() }
        }

        accessToken  = ""
        refreshToken = ""
        baseURL      = ""
        isAuthenticated = false
        needsTOTP      = false
        pendingTokens  = nil
        accountStatus  = .active
        emailVerified  = true
        
        // Delete from Keychain
        KeychainHelper.deleteAll()
        
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

    private var clientIdentifier: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        return "Sheaf iOS/\(version)"
    }

    private static let cfClientIdKey = "sheaf_cf_client_id"
    private static let cfClientSecretKey = "sheaf_cf_client_secret"

    static var cfAccessEnabled: Bool {
        let id = KeychainHelper.get(key: cfClientIdKey) ?? ""
        let secret = KeychainHelper.get(key: cfClientSecretKey) ?? ""
        return !id.isEmpty && !secret.isEmpty
    }

    static func saveCFTokens(clientId: String, clientSecret: String) {
        try? KeychainHelper.save(key: cfClientIdKey, value: clientId)
        try? KeychainHelper.save(key: cfClientSecretKey, value: clientSecret)
    }

    static func clearCFTokens() {
        KeychainHelper.delete(key: cfClientIdKey)
        KeychainHelper.delete(key: cfClientSecretKey)
    }

    /// Applies Cloudflare Access service token headers if configured.
    private func applyCFHeaders(to req: inout URLRequest) {
        if let id = KeychainHelper.get(key: Self.cfClientIdKey), !id.isEmpty,
           let secret = KeychainHelper.get(key: Self.cfClientSecretKey), !secret.isEmpty {
            req.setValue(id, forHTTPHeaderField: "CF-Access-Client-Id")
            req.setValue(secret, forHTTPHeaderField: "CF-Access-Client-Secret")
        }
    }

    /// Detects Cloudflare Access interception — a 200 OK that returns HTML instead of JSON.
    private func detectCloudflareInterception(_ data: Data) throws {
        guard let prefix = String(data: data.prefix(200), encoding: .utf8),
              prefix.contains("<!DOCTYPE") || prefix.contains("<html") else { return }
        if prefix.lowercased().contains("cloudflare") {
            throw NSError(domain: "APIError", code: 403,
                          userInfo: [NSLocalizedDescriptionKey: "This server is behind Cloudflare Access. Tap the Sheaf logo 10 times on the login screen to configure your service token."])
        }
        throw NSError(domain: "APIError", code: 0,
                      userInfo: [NSLocalizedDescriptionKey: "The server returned an HTML page instead of JSON. Check your server URL."])
    }

    /// Builds a user-friendly error message from an HTTP error response.
    private func friendlyErrorMessage(statusCode: Int, data: Data) -> String {
        // Check for HTML responses (e.g. Cloudflare error pages, proxy errors)
        if let prefix = String(data: data.prefix(200), encoding: .utf8),
           prefix.contains("<!DOCTYPE") || prefix.contains("<html") {
            if prefix.lowercased().contains("cloudflare") {
                return cloudflareStatusMessage(statusCode)
                    ?? "Cloudflare blocked the request (HTTP \(statusCode)). Check your Cloudflare Access configuration."
            }
            return "The server returned an HTML error page (HTTP \(statusCode)). Check your server URL."
        }

        // Try to extract a message from JSON error bodies
        if let serverMessage = parseJSONErrorMessage(from: data) {
            return humanizeErrorMessage(serverMessage)
        }

        // Cloudflare-specific status codes (520–530)
        if let cfMessage = cloudflareStatusMessage(statusCode) {
            return cfMessage
        }

        switch statusCode {
        case 400: return "Bad request. Please check your input."
        case 403: return "Access denied."
        case 404: return "The requested resource was not found."
        case 409: return "Conflict — the resource may have been modified."
        case 413: return "The request is too large."
        case 422: return "The server couldn't process your request. Please check your input."
        case 429: return "Too many requests. Please wait a moment and try again."
        case 500...519: return "The server is having issues (HTTP \(statusCode)). Please try again later."
        default: return "Request failed (HTTP \(statusCode))."
        }
    }

    /// Returns a descriptive message for Cloudflare-specific status codes, or nil.
    private func cloudflareStatusMessage(_ statusCode: Int) -> String? {
        switch statusCode {
        case 520: return "The server returned an unexpected response (Cloudflare 520)."
        case 521: return "The server is down (Cloudflare 521)."
        case 522: return "Connection to the server timed out (Cloudflare 522)."
        case 523: return "The server is unreachable (Cloudflare 523)."
        case 524: return "The server took too long to respond (Cloudflare 524)."
        case 525: return "SSL handshake failed (Cloudflare 525)."
        case 526: return "Invalid SSL certificate (Cloudflare 526)."
        case 530: return "The server encountered a Cloudflare error (530)."
        default: return nil
        }
    }

    /// Replaces known technical server messages with friendlier alternatives.
    /// Passes through messages that are already user-readable (e.g. "Email already in use").
    private func humanizeErrorMessage(_ message: String) -> String {
        let lowered = message.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        let replacements: [String: String] = [
            "rate limit exceeded": "Too many requests. Please wait a moment and try again.",
            "too many requests": "Too many requests. Please wait a moment and try again.",
            "internal server error": "The server encountered an error. Please try again later.",
            "bad gateway": "The server is temporarily unavailable. Please try again later.",
            "service unavailable": "The server is temporarily unavailable. Please try again later.",
            "gateway timeout": "The server took too long to respond. Please try again later.",
            "unauthorized": "Your session has expired. Please log in again.",
            "not authenticated": "Your session has expired. Please log in again.",
            "forbidden": "You don't have permission to do this.",
            "not found": "The requested resource was not found.",
            "method not allowed": "This action is not supported.",
            "conflict": "A conflict occurred. Please try again.",
            "unprocessable entity": "Please check your input and try again.",
            "validation error": "Please check your input and try again.",
            "bad request": "The server couldn't process your request. Please check your input.",
            "request entity too large": "The data you're sending is too large.",
            "payload too large": "The data you're sending is too large.",
        ]

        if let friendly = replacements[lowered] {
            return friendly
        }

        // Prefix matches for messages with variable suffixes
        if lowered.hasPrefix("rate limit") {
            return "Too many requests. Please wait a moment and try again."
        }

        return message
    }

    /// Attempts to extract an error message from a JSON response body.
    private func parseJSONErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let detail = json["detail"] as? String, !detail.isEmpty { return detail }
        if let message = json["message"] as? String, !message.isEmpty { return message }
        if let error = json["error"] as? String, !error.isEmpty { return error }
        // FastAPI-style validation errors: {"detail": [{"msg": "...", ...}, ...]}
        if let details = json["detail"] as? [[String: Any]] {
            let messages = details.compactMap { $0["msg"] as? String }
            if !messages.isEmpty { return messages.joined(separator: "; ") }
        }
        return nil
    }

    /// Cached CF-aware session. Recreated when tokens change.
    private static var _cfSession: URLSession?
    private static var _cfSessionTokenHash: String?

    private static func makeCFSession() -> URLSession {
        let id = KeychainHelper.get(key: cfClientIdKey) ?? ""
        let secret = KeychainHelper.get(key: cfClientSecretKey) ?? ""
        let hash = "\(id):\(secret)"
        if let existing = _cfSession, _cfSessionTokenHash == hash {
            return existing
        }
        let config = URLSessionConfiguration.default
        // Inject CF headers at the session level for maximum reliability
        if !id.isEmpty, !secret.isEmpty {
            config.httpAdditionalHeaders = [
                "CF-Access-Client-Id": id,
                "CF-Access-Client-Secret": secret
            ]
        }
        let delegate = CFHeaderPreservingDelegate()
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        _cfSession = session
        _cfSessionTokenHash = hash
        return session
    }

    /// Returns the appropriate URLSession — uses a CF-aware session when tokens are configured.
    private var urlSession: URLSession {
        Self.cfAccessEnabled ? Self.makeCFSession() : URLSession.shared
    }

    init(auth: AuthManager) {
        self.auth = auth
    }

    // MARK: Request + auto-refresh

    private func request(_ path: String, method: String = "GET", body: Data? = nil) async throws -> Data {
        // First attempt
        let (data, status) = try await perform(path, method: method, body: body)
        if status != 401 { return data }

        // 401 — try to refresh once, then retry
        let fresh: TokenResponse
        do {
            fresh = try await refreshOnce()
        } catch {
            let code = (error as NSError).code
            if code == 401 || code == 403 {
                // Genuine auth rejection — session is dead
                await MainActor.run { auth.logout() }
                throw NSError(domain: "APIError", code: 401,
                              userInfo: [NSLocalizedDescriptionKey: "Session expired. Please log in again."])
            }
            // Transient error (network, server 5xx, etc.) — don't log out
            throw error
        }
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
        req.setValue(clientIdentifier, forHTTPHeaderField: "X-Sheaf-Client")
        applyCFHeaders(to: &req)
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = body
        }
        let (data, response) = try await urlSession.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        // Detect Cloudflare Access interception (returns 200 with HTML instead of JSON)
        if (200...299).contains(http.statusCode) {
            try detectCloudflareInterception(data)
        }
        // Throw for all errors except 401 (which we handle via retry)
        if http.statusCode != 401 && !(200...299).contains(http.statusCode) {
            throw NSError(domain: "APIError", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: friendlyErrorMessage(statusCode: http.statusCode, data: data)])
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
            applyCFHeaders(to: &req)
            req.httpBody = body
            let (data, response) = try await urlSession.data(for: req)
            guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            guard (200...299).contains(http.statusCode) else {
                throw NSError(domain: "APIError", code: http.statusCode,
                              userInfo: [NSLocalizedDescriptionKey: friendlyErrorMessage(statusCode: http.statusCode, data: data)])
            }
            return try JSONDecoder.iso.decode(TokenResponse.self, from: data)
        }
        refreshTask = task
        return try await task.value
    }

    // MARK: - Auth

    /// Error thrown when the server requires a TOTP code to complete login.
    struct TOTPRequiredError: Error {}

    func login(email: String, password: String, totpCode: String? = nil) async throws -> TokenResponse {
        let body = try JSONEncoder.iso.encode(UserLogin(email: email, password: password, totpCode: totpCode))
        // Don't use request() because login endpoints shouldn't trigger token refresh
        guard let url = URL(string: auth.baseURL + "/v1/auth/login") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(clientIdentifier, forHTTPHeaderField: "X-Sheaf-Client")
        applyCFHeaders(to: &req)
        req.httpBody = body
        let (data, response) = try await urlSession.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        // Check for 2FA requirement via X-Sheaf-2FA header
        if http.statusCode == 401,
           http.value(forHTTPHeaderField: "X-Sheaf-2FA") == "required" {
            throw TOTPRequiredError()
        }
        // Detect Cloudflare Access interception (200 OK with HTML)
        if (200...299).contains(http.statusCode) {
            try detectCloudflareInterception(data)
        }
        guard http.statusCode == 200 else {
            throw NSError(domain: "APIError", code: http.statusCode,
                         userInfo: [NSLocalizedDescriptionKey: friendlyErrorMessage(statusCode: http.statusCode, data: data)])
        }
        return try Self.decodeJSON(TokenResponse.self, from: data)
    }

    func register(email: String, password: String, inviteCode: String? = nil) async throws -> TokenResponse {
        let body = try JSONEncoder.iso.encode(UserRegister(email: email, password: password, inviteCode: inviteCode))
        // Don't use request() because register endpoints shouldn't trigger token refresh
        let (data, status) = try await perform("/v1/auth/register", method: "POST", body: body)
        guard (200...201).contains(status) else {
            throw NSError(domain: "APIError", code: status,
                         userInfo: [NSLocalizedDescriptionKey: friendlyErrorMessage(statusCode: status, data: data)])
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

    // MARK: - Auth Config

    func getAuthConfig() async throws -> [String: Any] {
        guard let url = URL(string: auth.baseURL + "/v1/auth/config") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        applyCFHeaders(to: &req)
        let (data, response) = try await urlSession.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if (200...299).contains(http.statusCode) {
            try detectCloudflareInterception(data)
        } else {
            throw NSError(domain: "APIError", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: friendlyErrorMessage(statusCode: http.statusCode, data: data)])
        }
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    // MARK: - Logout

    func logout() async {
        // Best-effort server-side session invalidation
        _ = try? await request("/v1/auth/logout", method: "POST")
    }

    // MARK: - Password Reset

    func requestPasswordReset(email: String) async throws {
        let body = try JSONEncoder.iso.encode(PasswordResetRequest(email: email))
        let (data, status) = try await perform("/v1/auth/request-password-reset", method: "POST", body: body)
        guard (200...299).contains(status) else {
            throw NSError(domain: "APIError", code: status,
                          userInfo: [NSLocalizedDescriptionKey: friendlyErrorMessage(statusCode: status, data: data)])
        }
    }

    func resetPassword(token: String, newPassword: String) async throws {
        let body = try JSONEncoder.iso.encode(PasswordReset(token: token, newPassword: newPassword))
        let (data, status) = try await perform("/v1/auth/reset-password", method: "POST", body: body)
        guard (200...299).contains(status) else {
            throw NSError(domain: "APIError", code: status,
                          userInfo: [NSLocalizedDescriptionKey: friendlyErrorMessage(statusCode: status, data: data)])
        }
    }

    // MARK: - TOTP Management

    func disableTOTP(email: String, password: String, totpCode: String?) async throws {
        let body = try JSONEncoder.iso.encode(UserLogin(email: email, password: password, totpCode: totpCode))
        _ = try await request("/v1/auth/totp/disable", method: "POST", body: body)
    }

    func regenerateRecoveryCodes(code: String) async throws -> [String] {
        let body = try JSONEncoder.iso.encode(TOTPVerify(code: code))
        let data = try await request("/v1/auth/totp/regenerate-recovery-codes", method: "POST", body: body)
        // Response may contain recovery_codes array or be loosely typed
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let codes = json["recovery_codes"] as? [String] {
            return codes
        }
        return []
    }

    // MARK: - Delete Confirmation

    func updateDeleteConfirmation(_ update: DeleteConfirmationUpdate) async throws -> SystemProfile {
        let body = try JSONEncoder.iso.encode(update)
        let data = try await request("/v1/systems/me/delete-confirmation", method: "PUT", body: body)
        return try JSONDecoder.iso.decode(SystemProfile.self, from: data)
    }

    // MARK: - Email Verification

    func verifyEmail(token: String) async throws {
        guard let encoded = token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw URLError(.badURL)
        }
        _ = try await request("/v1/auth/verify-email?token=\(encoded)")
    }

    func resendVerification() async throws {
        _ = try await request("/v1/auth/resend-verification", method: "POST")
    }

    // MARK: - Account Deletion

    func deleteAccount(password: String, totpCode: String? = nil) async throws {
        let req = DeleteAccountRequest(password: password, totpCode: totpCode)
        let body = try JSONEncoder.iso.encode(req)
        _ = try await request("/v1/auth/delete-account", method: "POST", body: body)
    }

    func cancelDeletion() async throws {
        _ = try await request("/v1/auth/cancel-deletion", method: "POST")
    }

    // MARK: - Admin Approvals

    func getApprovals() async throws -> [PendingUserRead] {
        let data = try await request("/v1/admin/approvals")
        return try JSONDecoder.iso.decode([PendingUserRead].self, from: data)
    }

    func approveUser(userID: String) async throws {
        _ = try await request("/v1/admin/users/\(userID)/approve", method: "POST")
    }

    func rejectUser(userID: String) async throws {
        _ = try await request("/v1/admin/users/\(userID)/reject", method: "POST")
    }

    // MARK: - Admin Invites

    func getInvites() async throws -> [InviteCodeRead] {
        let data = try await request("/v1/admin/invites")
        return try JSONDecoder.iso.decode([InviteCodeRead].self, from: data)
    }

    func createInvite(_ create: InviteCodeCreate) async throws -> InviteCodeRead {
        let body = try JSONEncoder.iso.encode(create)
        let data = try await request("/v1/admin/invites", method: "POST", body: body)
        return try JSONDecoder.iso.decode(InviteCodeRead.self, from: data)
    }

    func deleteInvite(id: String) async throws {
        _ = try await request("/v1/admin/invites/\(id)", method: "DELETE")
    }

    // MARK: - Sheaf Import

    func previewSheafImport(fileData: Data, filename: String) async throws -> Data {
        return try await multipartRequest(
            path: "/v1/import/sheaf/preview",
            fileData: fileData,
            filename: filename
        )
    }

    func doSheafImport(
        fileData: Data,
        filename: String,
        systemProfile: Bool = true,
        memberIds: String? = nil,
        fronts: Bool = true,
        groups: Bool = true,
        tags: Bool = true,
        customFields: Bool = true
    ) async throws -> Data {
        var path = "/v1/import/sheaf?system_profile=\(systemProfile)&fronts=\(fronts)&groups=\(groups)&tags=\(tags)&custom_fields=\(customFields)"
        if let ids = memberIds, !ids.isEmpty {
            path += "&member_ids=\(ids.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ids)"
        }
        return try await multipartRequest(path: path, fileData: fileData, filename: filename)
    }

    // MARK: - System

    func getMe() async throws -> UserRead {
        let data = try await request("/v1/auth/me")
        return try JSONDecoder.iso.decode(UserRead.self, from: data)
    }

    func updateMe(_ update: UserUpdate) async throws -> UserRead {
        let body = try JSONEncoder.iso.encode(update)
        let data = try await request("/v1/auth/me", method: "PATCH", body: body)
        return try JSONDecoder.iso.decode(UserRead.self, from: data)
    }
    
    /// Version of getMe that doesn't auto-retry on 401 (for login flow TOTP detection)
    func getMeWithoutRetry() async throws -> UserRead {
        let (data, status) = try await perform("/v1/auth/me", method: "GET", body: nil)
        guard status == 200 else {
            throw NSError(domain: "APIError", code: status,
                         userInfo: [NSLocalizedDescriptionKey: friendlyErrorMessage(statusCode: status, data: data)])
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

    func deleteMember(id: String, confirmation: MemberDeleteConfirm? = nil) async throws {
        let body = confirmation != nil ? try JSONEncoder.iso.encode(confirmation) : nil
        _ = try await request("/v1/members/\(id)", method: "DELETE", body: body)
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

    func updateTag(id: String, update: TagUpdate) async throws -> Tag {
        let body = try JSONEncoder.iso.encode(update)
        let data = try await request("/v1/tags/\(id)", method: "PATCH", body: body)
        return try JSONDecoder.iso.decode(Tag.self, from: data)
    }

    func deleteTag(id: String) async throws {
        _ = try await request("/v1/tags/\(id)", method: "DELETE")
    }

    func deleteField(id: String) async throws {
        _ = try await request("/v1/fields/\(id)", method: "DELETE")
    }

    func updateField(id: String, update: CustomFieldUpdate) async throws -> CustomField {
        let body = try JSONEncoder.iso.encode(update)
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

    // MARK: - API Keys

    func listApiKeys() async throws -> [ApiKeyRead] {
        let data = try await request("/v1/auth/keys")
        return try JSONDecoder.iso.decode([ApiKeyRead].self, from: data)
    }

    func createApiKey(_ create: ApiKeyCreate) async throws -> ApiKeyCreated {
        let body = try JSONEncoder.iso.encode(create)
        let data = try await request("/v1/auth/keys", method: "POST", body: body)
        return try JSONDecoder.iso.decode(ApiKeyCreated.self, from: data)
    }

    func revokeApiKey(id: String) async throws {
        _ = try await request("/v1/auth/keys/\(id)", method: "DELETE")
    }

    // MARK: - Client Settings

    static let clientSettingsId = "sheaf-ios"

    func getClientSettings() async throws -> [String: Any] {
        let data = try await request("/v1/settings/client/\(Self.clientSettingsId)")
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    func saveClientSettings(_ settings: [String: Any]) async throws {
        let payload = ["settings": settings]
        let body = try JSONSerialization.data(withJSONObject: payload)
        _ = try await request("/v1/settings/client/\(Self.clientSettingsId)", method: "PUT", body: body)
    }

    func deleteClientSettings() async throws {
        _ = try await request("/v1/settings/client/\(Self.clientSettingsId)", method: "DELETE")
    }

    // MARK: - Sessions

    func listSessions() async throws -> [SessionRead] {
        let data = try await request("/v1/auth/sessions")
        return try JSONDecoder.iso.decode([SessionRead].self, from: data)
    }

    func renameSession(id: String, nickname: String) async throws -> SessionRead {
        let body = try JSONEncoder.iso.encode(SessionUpdate(nickname: nickname))
        let data = try await request("/v1/auth/sessions/\(id)", method: "PATCH", body: body)
        return try JSONDecoder.iso.decode(SessionRead.self, from: data)
    }

    func revokeSession(id: String) async throws {
        _ = try await request("/v1/auth/sessions/\(id)", method: "DELETE")
    }

    func revokeOtherSessions() async throws {
        _ = try await request("/v1/auth/sessions/revoke-others", method: "POST")
    }

    // MARK: - Admin

    /// Returns the admin step-up auth status from the server.
    func getAdminAuthStatus() async throws -> AdminAuthStatus {
        let data = try await request("/v1/admin/auth")
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return AdminAuthStatus(
                level: json["level"] as? String ?? "none",
                verified: json["verified"] as? Bool ?? true,
                totpEnabled: json["totp_enabled"] as? Bool ?? false
            )
        }
        return AdminAuthStatus(level: "none", verified: true, totpEnabled: false)
    }

    func adminStepUp(_ verify: AdminStepUpVerify) async throws {
        let body = try JSONEncoder.iso.encode(verify)
        // Use perform() directly so a wrong TOTP code (401) doesn't trigger
        // the auto-refresh → retry → logout flow in request().
        let (data, status) = try await perform("/v1/admin/auth", method: "POST", body: body)
        guard (200...299).contains(status) else {
            throw NSError(domain: "APIError", code: status,
                          userInfo: [NSLocalizedDescriptionKey: friendlyErrorMessage(statusCode: status, data: data)])
        }
    }

    func getAdminStats() async throws -> AdminStats {
        let data = try await request("/v1/admin/stats")
        let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        var usersByTier: [String: Int] = [:]
        if let tierDict = json["users_by_tier"] as? [String: Any] {
            for (key, value) in tierDict {
                if let intVal = value as? Int { usersByTier[key] = intVal }
            }
        }
        return AdminStats(
            totalUsers: json["total_users"] as? Int ?? 0,
            totalMembers: json["total_members"] as? Int ?? 0,
            totalStorageBytes: json["total_storage_bytes"] as? Int ?? 0,
            usersByTier: usersByTier
        )
    }

    func getAdminUsers(search: String? = nil, page: Int = 1, limit: Int = 50) async throws -> [AdminUserRead] {
        var path = "/v1/admin/users?page=\(page)&limit=\(limit)"
        if let search, !search.isEmpty {
            path += "&search=\(search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? search)"
        }
        let data = try await request(path)
        return try JSONDecoder.iso.decode([AdminUserRead].self, from: data)
    }

    func updateAdminUser(userID: String, update: AdminUserUpdate) async throws -> AdminUserRead {
        let body = try JSONEncoder.iso.encode(update)
        let data = try await request("/v1/admin/users/\(userID)", method: "PATCH", body: body)
        return try JSONDecoder.iso.decode(AdminUserRead.self, from: data)
    }

    func setUserMemberLimit(userID: String, limit: MemberLimitOverride) async throws {
        let body = try JSONEncoder.iso.encode(limit)
        _ = try await request("/v1/admin/users/\(userID)/member-limit", method: "PUT", body: body)
    }

    func runRetention() async throws {
        _ = try await request("/v1/admin/retention/run", method: "POST")
    }

    func runCleanup() async throws {
        _ = try await request("/v1/admin/cleanup/run", method: "POST")
    }

    func getStorageStats() async throws -> [String: Any] {
        let data = try await request("/v1/admin/storage/stats")
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return json
        }
        return [:]
    }

    func adminCancelDeletion(userID: String) async throws {
        _ = try await request("/v1/admin/users/\(userID)/cancel-deletion", method: "POST")
    }

    func adminDisableTOTP(userID: String) async throws {
        _ = try await request("/v1/admin/users/\(userID)/disable-totp", method: "POST")
    }

    func adminResetPassword(userID: String, newPassword: String?) async throws {
        let req = AdminResetPasswordRequest(newPassword: newPassword)
        let body = try JSONEncoder.iso.encode(req)
        _ = try await request("/v1/admin/users/\(userID)/reset-password", method: "POST", body: body)
    }

    func adminChangeEmail(userID: String, newEmail: String) async throws {
        let req = AdminChangeEmailRequest(newEmail: newEmail)
        let body = try JSONEncoder.iso.encode(req)
        _ = try await request("/v1/admin/users/\(userID)/change-email", method: "POST", body: body)
    }

    func adminVerifyEmail(userID: String) async throws {
        _ = try await request("/v1/admin/users/\(userID)/verify-email", method: "POST")
    }

    // MARK: - Announcements

    func getAnnouncements() async throws -> [Announcement] {
        let data = try await request("/v1/announcements")
        return try JSONDecoder.iso.decode([Announcement].self, from: data)
    }

    // MARK: - Admin Announcements

    func getAdminAnnouncements() async throws -> [AnnouncementRead] {
        let data = try await request("/v1/admin/announcements")
        return try JSONDecoder.iso.decode([AnnouncementRead].self, from: data)
    }

    func createAnnouncement(_ create: AnnouncementCreate) async throws -> AnnouncementRead {
        let body = try JSONEncoder.iso.encode(create)
        let data = try await request("/v1/admin/announcements", method: "POST", body: body)
        return try JSONDecoder.iso.decode(AnnouncementRead.self, from: data)
    }

    func updateAnnouncement(id: String, update: AnnouncementUpdate) async throws -> AnnouncementRead {
        let body = try JSONEncoder.iso.encode(update)
        let data = try await request("/v1/admin/announcements/\(id)", method: "PATCH", body: body)
        return try JSONDecoder.iso.decode(AnnouncementRead.self, from: data)
    }

    func deleteAnnouncement(id: String) async throws {
        _ = try await request("/v1/admin/announcements/\(id)", method: "DELETE")
    }

    // MARK: - Export

    func exportData() async throws -> Data {
        return try await request("/v1/export")
    }

    // MARK: - File Upload


    // MARK: - File Management

    func getFileUsage() async throws -> [String: Any] {
        let data = try await request("/v1/files/usage")
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    func listFiles() async throws -> [[String: Any]] {
        let data = try await request("/v1/files/list")
        if let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return arr
        }
        return []
    }

    func deleteFile(id: String) async throws {
        _ = try await request("/v1/files/\(id)", method: "DELETE")
    }

    func cleanupFiles() async throws -> [String: Any] {
        let data = try await request("/v1/files/cleanup", method: "POST")
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    func cleanupFilesDryRun() async throws -> [String: Any] {
        let data = try await request("/v1/files/cleanup/dry-run", method: "POST")
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

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
        req.setValue(clientIdentifier, forHTTPHeaderField: "X-Sheaf-Client")
        applyCFHeaders(to: &req)
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body
        let (data, response) = try await urlSession.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if (200...299).contains(http.statusCode) {
            try detectCloudflareInterception(data)
        } else {
            throw NSError(domain: "APIError", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: friendlyErrorMessage(statusCode: http.statusCode, data: data)])
        }
        return data
    }

    func uploadFile(imageData: Data, mimeType: String = "image/jpeg") async throws -> String {
        let ext: String
        switch mimeType {
        case "image/png": ext = "png"
        case "image/gif": ext = "gif"
        case "image/webp": ext = "webp"
        default: ext = "jpg"
        }

        // First attempt
        let (data, status) = try await performUpload(imageData: imageData, mimeType: mimeType, ext: ext)
        if status != 401 { return try parseUploadResponse(data) }

        // 401 — refresh token and retry
        let fresh = try await refreshOnce()
        await MainActor.run { auth.save(baseURL: auth.baseURL, tokens: fresh) }

        let (retryData, retryStatus) = try await performUpload(imageData: imageData, mimeType: mimeType, ext: ext)
        guard retryStatus != 401 else {
            await MainActor.run { auth.logout() }
            throw NSError(domain: "APIError", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Session expired. Please log in again."])
        }
        return try parseUploadResponse(retryData)
    }

    private func performUpload(imageData: Data, mimeType: String, ext: String) async throws -> (Data, Int) {
        guard let url = URL(string: auth.baseURL + "/v1/files/upload") else {
            throw URLError(.badURL)
        }
        let boundary = "Boundary-\(UUID().uuidString)"
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(auth.accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue(clientIdentifier, forHTTPHeaderField: "X-Sheaf-Client")
        applyCFHeaders(to: &req)

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"upload.\(ext)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        let (data, response) = try await urlSession.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if (200...299).contains(http.statusCode) {
            try detectCloudflareInterception(data)
        } else if http.statusCode != 401 {
            throw NSError(domain: "APIError", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: friendlyErrorMessage(statusCode: http.statusCode, data: data)])
        }
        return (data, http.statusCode)
    }

    private func parseUploadResponse(_ data: Data) throws -> String {
        // API returns {"url": "...", "key": "...", "size": N}
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let urlStr = json["url"] as? String, !urlStr.isEmpty {
            return urlStr
        }
        return ""
    }

    /// Decodes JSON, detecting Cloudflare Access interception and giving a clear error.
    static func decodeJSON<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        // Detect HTML responses (e.g. Cloudflare Access login page served as 200)
        if let prefix = String(data: data.prefix(200), encoding: .utf8),
           prefix.contains("<!DOCTYPE") || prefix.contains("<html") {
            if prefix.lowercased().contains("cloudflare") {
                throw NSError(domain: "APIError", code: 403,
                              userInfo: [NSLocalizedDescriptionKey: "This server is behind Cloudflare Access. Tap the Sheaf logo 10 times on the login screen to configure your service token."])
            }
            throw NSError(domain: "APIError", code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "The server returned an HTML page instead of JSON. Check your server URL."])
        }
        return try JSONDecoder.iso.decode(type, from: data)
    }
}

// MARK: - CF Header Preserving Delegate
/// URLSession strips custom headers on redirects. This delegate re-applies CF-Access
/// headers so Cloudflare Access doesn't block the redirected request.
private class CFHeaderPreservingDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        var newReq = request
        // Preserve CF-Access headers from the original request
        if let original = task.originalRequest {
            if let cfId = original.value(forHTTPHeaderField: "CF-Access-Client-Id") {
                newReq.setValue(cfId, forHTTPHeaderField: "CF-Access-Client-Id")
            }
            if let cfSecret = original.value(forHTTPHeaderField: "CF-Access-Client-Secret") {
                newReq.setValue(cfSecret, forHTTPHeaderField: "CF-Access-Client-Secret")
            }
        }
        completionHandler(newReq)
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
    var dateFormat: DateFormat?
    var replaceFrontsDefault: Bool?

    enum CodingKeys: String, CodingKey {
        case name, description, tag, color, privacy
        case avatarURL            = "avatar_url"
        case dateFormat           = "date_format"
        case replaceFrontsDefault = "replace_fronts_default"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(description, forKey: .description)
        try c.encode(tag, forKey: .tag)
        try c.encode(avatarURL, forKey: .avatarURL)
        try c.encode(color, forKey: .color)
        try c.encode(privacy, forKey: .privacy)
        try c.encode(dateFormat, forKey: .dateFormat)
        try c.encode(replaceFrontsDefault, forKey: .replaceFrontsDefault)
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
