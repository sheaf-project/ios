import Foundation
import Combine
import WatchConnectivity

/// Handles WatchConnectivity on the watchOS side.
/// Receives credential updates pushed from the iPhone and applies them to WatchAuthManager.
final class WatchConnectivityManager: NSObject, WCSessionDelegate, ObservableObject {
    static let shared = WatchConnectivityManager()

    weak var authManager: WatchAuthManager?

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func configure(auth: WatchAuthManager) {
        NSLog("⌚️ WatchConnectivityManager: Configuring with auth manager")
        self.authManager = auth
        // Apply any context already waiting from the last iPhone push
        let existingContext = WCSession.default.receivedApplicationContext
        NSLog("   Existing context keys: \(existingContext.keys)")
        applyContext(existingContext)
    }

    // MARK: - Receive from iPhone

    /// Called when the iPhone pushes updated application context.
    func session(_ session: WCSession,
                 didReceiveApplicationContext applicationContext: [String: Any]) {
        NSLog("⌚️ WatchConnectivityManager: Received application context")
        NSLog("   Keys: \(applicationContext.keys)")
        applyContext(applicationContext)
    }

    /// Also handle real-time messages (sent while both devices are reachable).
    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any]) {
        NSLog("⌚️ WatchConnectivityManager: Received message")
        NSLog("   Keys: \(message.keys)")
        applyContext(message)
    }

    private func applyContext(_ context: [String: Any]) {
        // Skip empty contexts (happens on first launch before any credentials are sent)
        guard !context.isEmpty else {
            NSLog("⌚️ WatchConnectivityManager: Context is empty, skipping (no credentials sent yet)")
            return
        }
        
        NSLog("⌚️ WatchConnectivityManager: Applying context...")
        NSLog("   Context dictionary: \(context)")
        
        let baseURL = context["baseURL"] as? String
        let accessToken = context["accessToken"] as? String
        let refreshToken = context["refreshToken"] as? String
        
        NSLog("   baseURL: '\(baseURL ?? "nil")' (isEmpty: \(baseURL?.isEmpty ?? true))")
        NSLog("   accessToken: '\(accessToken?.prefix(10) ?? "nil")...' (isEmpty: \(accessToken?.isEmpty ?? true))")
        NSLog("   refreshToken: '\(refreshToken?.prefix(10) ?? "nil")...' (isEmpty: \(refreshToken?.isEmpty ?? true))")
        
        guard
            let baseURL = baseURL,
            let accessToken = accessToken,
            let refreshToken = refreshToken,
            !baseURL.isEmpty, !accessToken.isEmpty
        else { 
            NSLog("❌ WatchConnectivityManager: Context validation failed")
            NSLog("   baseURL valid: \(baseURL != nil && !(baseURL?.isEmpty ?? true))")
            NSLog("   accessToken valid: \(accessToken != nil && !(accessToken?.isEmpty ?? true))")
            NSLog("   refreshToken valid: \(refreshToken != nil)")
            return 
        }

        NSLog("✅ WatchConnectivityManager: Context valid, saving to auth manager")
        DispatchQueue.main.async { [weak self] in
            guard let authManager = self?.authManager else {
                NSLog("❌ WatchConnectivityManager: Auth manager is nil!")
                return
            }
            authManager.save(
                baseURL: baseURL,
                accessToken: accessToken,
                refreshToken: refreshToken
            )
            NSLog("✅ WatchConnectivityManager: Credentials saved!")
            NSLog("   Auth manager isAuthenticated: \(authManager.isAuthenticated)")
        }
    }

    // MARK: - WCSessionDelegate boilerplate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        NSLog("⌚️ WatchConnectivityManager: Session activated with state: \(activationState.rawValue)")
        if let error = error {
            NSLog("❌ WatchConnectivityManager: Activation error: \(error)")
        }
    }
}
