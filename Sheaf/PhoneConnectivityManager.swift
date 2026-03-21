import Foundation
import Combine
import WatchConnectivity

/// Handles WatchConnectivity on the iOS side.
/// Pushes credentials to the watch whenever they change, and on activation.
final class PhoneConnectivityManager: NSObject, WCSessionDelegate, ObservableObject {
    static let shared = PhoneConnectivityManager()

    weak var authManager: AuthManager?

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func configure(auth: AuthManager) {
        self.authManager = auth
    }

    // MARK: - Push to watch

    /// Call this after login, token refresh, or any credential change.
    func syncCredentials() {
        NSLog("📱 PhoneConnectivityManager: syncCredentials() called")
        NSLog("   Session state: \(WCSession.default.activationState.rawValue)")
        NSLog("   Watch app installed: \(WCSession.default.isWatchAppInstalled)")
        NSLog("   Auth manager configured: \(authManager != nil)")
        NSLog("   Has access token: \((authManager?.accessToken.isEmpty == false))")
        
        guard
            WCSession.default.activationState == .activated,
            WCSession.default.isWatchAppInstalled,
            let auth = authManager,
            !auth.accessToken.isEmpty
        else { 
            NSLog("❌ PhoneConnectivityManager: Guard failed, not syncing")
            return 
        }

        let context: [String: Any] = [
            "baseURL":      auth.baseURL,
            "accessToken":  auth.accessToken,
            "refreshToken": auth.refreshToken,
        ]

        NSLog("✅ PhoneConnectivityManager: Sending credentials to watch")
        NSLog("   Base URL: \(auth.baseURL)")
        NSLog("   Watch reachable: \(WCSession.default.isReachable)")

        // Try real-time message first (instant if watch is reachable)
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(context, replyHandler: { reply in
                NSLog("✅ PhoneConnectivityManager: Message sent successfully, reply: \(reply)")
            }, errorHandler: { [weak self] error in
                NSLog("⚠️ PhoneConnectivityManager: Message failed (\(error)), falling back to context")
                // Fall back to application context if message fails
                self?.updateApplicationContext(context)
            })
        } else {
            NSLog("📦 PhoneConnectivityManager: Watch not reachable, using application context")
            // Application context persists and is delivered when watch wakes
            updateApplicationContext(context)
        }
    }

    private func updateApplicationContext(_ context: [String: Any]) {
        do {
            try WCSession.default.updateApplicationContext(context)
            NSLog("✅ PhoneConnectivityManager: Application context updated successfully")
        } catch {
            NSLog("❌ PhoneConnectivityManager: Failed to update application context: \(error)")
        }
    }

    // MARK: - WCSessionDelegate boilerplate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        NSLog("📱 PhoneConnectivityManager: Session activation completed with state: \(activationState.rawValue)")
        if let error = error {
            NSLog("❌ PhoneConnectivityManager: Activation error: \(error)")
        }
        if activationState == .activated {
            // Push current credentials as soon as the session is ready
            syncCredentials()
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
}
