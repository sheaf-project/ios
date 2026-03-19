import Foundation
import Combine

/// Lightweight auth manager for watchOS — shares the same UserDefaults keys
/// as the iOS app so credentials set on iPhone are available on watch via
/// WatchConnectivity (or manual entry as fallback).
final class WatchAuthManager: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var accessToken: String  = ""
    @Published var refreshToken: String = ""
    @Published var baseURL: String      = ""

    private let accessKey  = "sheaf_access_token"
    private let refreshKey = "sheaf_refresh_token"
    private let urlKey     = "sheaf_base_url"

    init() {
        accessToken  = UserDefaults.standard.string(forKey: accessKey)  ?? ""
        refreshToken = UserDefaults.standard.string(forKey: refreshKey) ?? ""
        baseURL      = UserDefaults.standard.string(forKey: urlKey)     ?? ""
        isAuthenticated = !accessToken.isEmpty && !baseURL.isEmpty
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
    }

    func logout() {
        accessToken = ""; refreshToken = ""; baseURL = ""
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: accessKey)
        UserDefaults.standard.removeObject(forKey: refreshKey)
        UserDefaults.standard.removeObject(forKey: urlKey)
    }
}
