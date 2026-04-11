import Foundation
import Combine

/// Lightweight auth manager for watchOS.
/// Credentials are synced from the iPhone via iCloud Keychain and WatchConnectivity.
final class WatchAuthManager: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var accessToken: String  = ""
    @Published var refreshToken: String = ""
    @Published var baseURL: String      = ""

    private let accessKey  = "sheaf_access_token"
    private let refreshKey = "sheaf_refresh_token"
    private let urlKey     = "sheaf_base_url"

    init() {
        loadCredentials()
    }

    /// Load credentials from iCloud Keychain.
    func loadCredentials() {
        debugLog("WatchAuthManager: loadCredentials() called")

        accessToken  = KeychainHelper.get(key: accessKey)  ?? ""
        refreshToken = KeychainHelper.get(key: refreshKey) ?? ""
        baseURL      = KeychainHelper.get(key: urlKey)     ?? ""

        isAuthenticated = !accessToken.isEmpty && !baseURL.isEmpty

        debugLog("WatchAuthManager: Loaded - isAuthenticated: \(isAuthenticated)")
    }

    func save(baseURL: String, accessToken: String, refreshToken: String) {
        let clean = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        self.baseURL      = clean
        self.accessToken  = accessToken
        self.refreshToken = refreshToken
        self.isAuthenticated = true
        try? KeychainHelper.save(key: urlKey, value: clean)
        try? KeychainHelper.save(key: accessKey, value: accessToken)
        try? KeychainHelper.save(key: refreshKey, value: refreshToken)
        debugLog("WatchAuthManager: Credentials saved to Keychain")
    }

    func logout() {
        accessToken = ""; refreshToken = ""; baseURL = ""
        isAuthenticated = false
        KeychainHelper.deleteAll()
    }
}
