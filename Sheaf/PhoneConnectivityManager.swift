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
        guard
            WCSession.default.activationState == .activated,
            WCSession.default.isWatchAppInstalled,
            let auth = authManager,
            !auth.accessToken.isEmpty
        else { return }

        let context: [String: Any] = [
            "baseURL":      auth.baseURL,
            "accessToken":  auth.accessToken,
            "refreshToken": auth.refreshToken,
        ]

        // Try real-time message first (instant if watch is reachable)
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(context, replyHandler: nil, errorHandler: { [weak self] _ in
                // Fall back to application context if message fails
                self?.updateApplicationContext(context)
            })
        } else {
            // Application context persists and is delivered when watch wakes
            updateApplicationContext(context)
        }
    }

    private func updateApplicationContext(_ context: [String: Any]) {
        try? WCSession.default.updateApplicationContext(context)
    }

    // MARK: - WCSessionDelegate boilerplate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
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
