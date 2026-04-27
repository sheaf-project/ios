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
    @Published var isAuthenticated: Bool = false
    @Published var accessToken: String  = ""
    @Published var refreshToken: String = ""
    @Published var baseURL: String      = ""

    private let accessKey  = "sheaf_watch_access_token"
    private let refreshKey = "sheaf_watch_refresh_token"
    private let urlKey     = "sheaf_base_url"

    // Old (pre-companion-session) keychain keys. We migrate off these on
    // first launch of the new build so a freshly-upgraded watch doesn't
    // keep using the phone's primary refresh token.
    private let legacyAccessKey  = "sheaf_access_token"
    private let legacyRefreshKey = "sheaf_refresh_token"

    init() {
        loadCredentials()
    }

    /// Load credentials from the keychain. Skips legacy entries — the
    /// watch must wait for fresh per-device creds from the phone instead
    /// of reusing the shared tokens that previously caused refresh-token
    /// collisions.
    func loadCredentials() {
        debugLog("WatchAuthManager: loadCredentials() called")

        // Wipe any legacy shared-token entries so they can't keep being
        // read by older code paths or accidentally synced back in.
        KeychainHelper.delete(key: legacyAccessKey)
        KeychainHelper.delete(key: legacyRefreshKey)

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
