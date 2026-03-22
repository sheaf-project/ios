import Foundation
import Combine
import WatchConnectivity

/// Handles WatchConnectivity on the iOS side.
/// Pushes credentials to the watch whenever they change, and on activation.
final class PhoneConnectivityManager: NSObject, WCSessionDelegate, ObservableObject {
    static let shared = PhoneConnectivityManager()

    // Strong reference — the AuthManager is also held by SheafApp's @StateObject,
    // but we need to guarantee it's available when background WCSession callbacks fire.
    var authManager: AuthManager?

    private override init() {
        super.init()
        if WCSession.isSupported() {
            NSLog("📱 PhoneConnectivityManager: Setting up WCSession")
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func configure(auth: AuthManager) {
        NSLog("📱 PhoneConnectivityManager: configure(auth:) called, isAuthenticated: \(auth.isAuthenticated)")
        self.authManager = auth
    }

    // MARK: - Push to watch

    /// Call this after login, token refresh, or any credential change.
    func syncCredentials() {
        guard let auth = authManager, !auth.accessToken.isEmpty else {
            NSLog("📱 PhoneConnectivityManager: No credentials to sync (authManager: \(authManager != nil))")
            return
        }

        let context: [String: Any] = [
            "baseURL":      auth.baseURL,
            "accessToken":  auth.accessToken,
            "refreshToken": auth.refreshToken,
        ]

        guard WCSession.default.activationState == .activated else {
            NSLog("📱 PhoneConnectivityManager: Session not activated, can't sync")
            return
        }

        // 1. updateApplicationContext — persists until Watch reads it (survives reboots).
        do {
            try WCSession.default.updateApplicationContext(context)
            NSLog("📱 PhoneConnectivityManager: Sent via updateApplicationContext")
        } catch {
            NSLog("📱 PhoneConnectivityManager: updateApplicationContext failed: \(error.localizedDescription)")
        }

        // 2. transferUserInfo — queued delivery, guaranteed even when Watch app isn't running.
        WCSession.default.transferUserInfo(context)
        NSLog("📱 PhoneConnectivityManager: Queued via transferUserInfo")

        // 3. sendMessage — immediate delivery if Watch is reachable right now.
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(context, replyHandler: { reply in
                NSLog("📱 PhoneConnectivityManager: Watch confirmed receipt: \(reply)")
            }, errorHandler: { error in
                NSLog("📱 PhoneConnectivityManager: sendMessage failed: \(error.localizedDescription)")
            })
        }
    }

    // MARK: - Receive from Watch

    /// Handle messages from Watch WITH a reply handler (e.g. credential requests).
    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        NSLog("📱 PhoneConnectivityManager: Received message from Watch: \(Array(message.keys))")

        if message["request"] as? String == "credentials" {
            guard let auth = authManager, !auth.accessToken.isEmpty else {
                NSLog("📱 PhoneConnectivityManager: Watch requested credentials but none available (authManager: \(authManager != nil))")
                replyHandler(["error": "not_authenticated"])
                return
            }
            let credentials: [String: Any] = [
                "baseURL":      auth.baseURL,
                "accessToken":  auth.accessToken,
                "refreshToken": auth.refreshToken,
            ]
            NSLog("📱 PhoneConnectivityManager: Sending credentials to Watch via reply")
            replyHandler(credentials)
            return
        }

        replyHandler(["status": "unknown_request"])
    }
    
    /// Handle messages from Watch WITHOUT a reply handler.
    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any]) {
        NSLog("📱 PhoneConnectivityManager: Received message (no reply) from Watch: \(Array(message.keys))")
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        NSLog("📱 PhoneConnectivityManager: Session activated with state: \(activationState.rawValue), watchAppInstalled: \(session.isWatchAppInstalled)")
        if let error = error {
            NSLog("📱 PhoneConnectivityManager: Activation error: \(error)")
        }
        if activationState == .activated {
            syncCredentials()
        }
    }
    
    /// Called when the Watch app is installed, uninstalled, or the watch is paired/unpaired.
    func sessionWatchStateDidChange(_ session: WCSession) {
        NSLog("📱 PhoneConnectivityManager: Watch state changed - installed: \(session.isWatchAppInstalled), paired: \(session.isPaired)")
        if session.isWatchAppInstalled {
            syncCredentials()
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
}
