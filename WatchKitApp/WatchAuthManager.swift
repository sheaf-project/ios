import Foundation
import Combine

/// Lightweight auth manager for watchOS.
/// Credentials are received from the iPhone via WatchConnectivity and stored in UserDefaults.
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

    /// Load credentials from UserDefaults (populated by WatchConnectivity).
    func loadCredentials() {
        NSLog("⌚️ WatchAuthManager: loadCredentials() called")

        accessToken  = UserDefaults.standard.string(forKey: accessKey)  ?? ""
        refreshToken = UserDefaults.standard.string(forKey: refreshKey) ?? ""
        baseURL      = UserDefaults.standard.string(forKey: urlKey)     ?? ""

        isAuthenticated = !accessToken.isEmpty && !baseURL.isEmpty

        NSLog("⌚️ WatchAuthManager: Loaded - baseURL: '\(baseURL.isEmpty ? "(empty)" : baseURL)', isAuthenticated: \(isAuthenticated)")
    }

    func save(baseURL: String, accessToken: String, refreshToken: String) {
        let clean = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        self.baseURL      = clean
        self.accessToken  = accessToken
        self.refreshToken = refreshToken
        self.isAuthenticated = true
        UserDefaults.standard.set(clean,        forKey: urlKey)
        UserDefaults.standard.set(accessToken,  forKey: accessKey)
        UserDefaults.standard.set(refreshToken, forKey: refreshKey)
        NSLog("⌚️ WatchAuthManager: Credentials saved to UserDefaults")
    }

    func logout() {
        accessToken = ""; refreshToken = ""; baseURL = ""
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: accessKey)
        UserDefaults.standard.removeObject(forKey: refreshKey)
        UserDefaults.standard.removeObject(forKey: urlKey)
    }
}
