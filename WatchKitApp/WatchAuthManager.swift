import Foundation
import Combine

/// Lightweight auth manager for watchOS.
///
/// Credentials are pushed from the iPhone via WatchConnectivity, and
/// (because the keychain is iCloud-synced) also propagate from the
/// iPhone's `sheaf_watch_*` entries as a slow-but-reliable fallback when
/// WCSession isn't reachable. The watch's tokens belong to a *child*
/// session minted server-side specifically for this device — keeping them
/// under `sheaf_watch_*` keys (rather than the phone's `sheaf_access_token`)
/// is what stops iCloud Keychain from accidentally handing the phone's
/// one-shot refresh JWT to the watch.
final class WatchAuthManager: ObservableObject {
    /// Single app-wide instance. Background refresh must use this rather
    /// than constructing its own manager: token refresh rotates the one-shot
    /// refresh JWT, and a second instance holding the stale token would
    /// replay it and get the session revoked.
    static let shared = WatchAuthManager()

    @Published var isAuthenticated: Bool = false
    @Published var accessToken: String  = ""
    @Published var refreshToken: String = ""
    @Published var baseURL: String      = ""

    private let accessKey  = "sheaf_watch_access_token"
    private let refreshKey = "sheaf_watch_refresh_token"
    private let urlKey     = "sheaf_base_url"

    init() {
        loadCredentials()
    }

    /// Load credentials from the keychain. Reads only the watch's own
    /// per-device entries, never the phone's primary tokens. Do NOT delete
    /// the old shared keys here: the keychain items are iCloud-synced, so
    /// deleting them from the watch deletes the phone's live credentials
    /// and logs the phone out on its next cold launch.
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

    /// Clears only the watch's own per-device credentials. deleteAll()
    /// would remove the phone's primary tokens from the synced keychain
    /// and log the phone out too.
    func logout() {
        accessToken = ""; refreshToken = ""; baseURL = ""
        isAuthenticated = false
        KeychainHelper.delete(key: accessKey)
        KeychainHelper.delete(key: refreshKey)
    }
}
