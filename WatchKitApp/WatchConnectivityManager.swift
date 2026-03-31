import Foundation
import Combine
import WatchConnectivity

/// Handles WatchConnectivity on the watchOS side.
/// Receives credential updates pushed from the iPhone and applies them to WatchAuthManager.
final class WatchConnectivityManager: NSObject, WCSessionDelegate, ObservableObject {
    static let shared = WatchConnectivityManager()

    weak var authManager: WatchAuthManager?
    
    /// Credentials received before authManager was configured — applied once configure() is called.
    private var pendingContext: [String: Any]?

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
        
        // Apply any credentials that arrived before configure() was called
        if let pending = pendingContext {
            NSLog("⌚️ WatchConnectivityManager: Applying pending context")
            pendingContext = nil
            applyContext(pending)
        }
        
        // Apply any context already waiting from the last iPhone push
        let existingContext = WCSession.default.receivedApplicationContext
        if !existingContext.isEmpty {
            NSLog("⌚️ WatchConnectivityManager: Found existing application context, applying")
            applyContext(existingContext)
        }
        
        // If still not authenticated, try requesting from iPhone
        if !auth.isAuthenticated {
            requestCredentials()
        }
    }

    /// Actively request credentials from the iPhone (pull-based).
    /// Prefers sendMessage (live, fresh) over receivedApplicationContext (may be stale).
    func requestCredentials() {
        guard WCSession.default.activationState == .activated else {
            NSLog("⌚️ WatchConnectivityManager: Cannot request credentials - session not activated")
            return
        }

        // Prefer sendMessage — it gets live credentials from the iPhone,
        // rather than potentially stale receivedApplicationContext.
        if WCSession.default.isReachable {
            NSLog("⌚️ WatchConnectivityManager: Requesting credentials from iPhone via sendMessage...")
            WCSession.default.sendMessage(["request": "credentials"], replyHandler: { [weak self] reply in
                NSLog("⌚️ WatchConnectivityManager: Received credential reply from iPhone")
                self?.applyContext(reply)
            }, errorHandler: { [weak self] error in
                NSLog("⌚️ WatchConnectivityManager: sendMessage failed: \(error.localizedDescription), falling back to application context")
                // Fall back to application context if sendMessage fails
                let existing = WCSession.default.receivedApplicationContext
                if !existing.isEmpty, existing["accessToken"] as? String != nil {
                    self?.applyContext(existing)
                }
            })
            return
        }

        // iPhone not reachable — try application context as a last resort
        let existing = WCSession.default.receivedApplicationContext
        if !existing.isEmpty, existing["accessToken"] as? String != nil {
            NSLog("⌚️ WatchConnectivityManager: iPhone not reachable, applying receivedApplicationContext")
            applyContext(existing)
        } else {
            NSLog("⌚️ WatchConnectivityManager: iPhone not reachable, no cached context, will retry when reachable")
        }
    }

    // MARK: - Receive from iPhone

    func session(_ session: WCSession,
                 didReceiveApplicationContext applicationContext: [String: Any]) {
        NSLog("⌚️ WatchConnectivityManager: Received application context")
        applyContext(applicationContext)
    }

    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any]) {
        NSLog("⌚️ WatchConnectivityManager: Received message (no reply)")
        applyContext(message)
    }

    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        NSLog("⌚️ WatchConnectivityManager: Received message (with reply)")
        applyContext(message)
        replyHandler(["status": "received"])
    }
    
    /// Called by watchOS when `didReceiveUserInfo` fires (queued transfer from iPhone).
    func session(_ session: WCSession,
                 didReceiveUserInfo userInfo: [String: Any] = [:]) {
        NSLog("⌚️ WatchConnectivityManager: Received userInfo transfer")
        applyContext(userInfo)
    }

    private func applyContext(_ context: [String: Any]) {
        guard !context.isEmpty else { return }

        let baseURL = context["baseURL"] as? String
        let accessToken = context["accessToken"] as? String
        let refreshToken = context["refreshToken"] as? String

        guard
            let baseURL = baseURL,
            let accessToken = accessToken,
            let refreshToken = refreshToken,
            !baseURL.isEmpty, !accessToken.isEmpty
        else {
            return
        }

        // If authManager isn't configured yet, stash for later
        guard let authManager = authManager else {
            NSLog("⌚️ WatchConnectivityManager: Auth manager not configured yet, stashing credentials")
            pendingContext = context
            return
        }

        NSLog("✅ WatchConnectivityManager: Saving credentials...")
        DispatchQueue.main.async {
            authManager.save(
                baseURL: baseURL,
                accessToken: accessToken,
                refreshToken: refreshToken
            )
            NSLog("✅ WatchConnectivityManager: Credentials saved, isAuthenticated: \(authManager.isAuthenticated)")
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        NSLog("⌚️ WatchConnectivityManager: Session activated with state: \(activationState.rawValue)")
        if let error = error {
            NSLog("⌚️ WatchConnectivityManager: Activation error: \(error)")
        }
        if activationState == .activated {
            // Check existing context on activation
            let existing = WCSession.default.receivedApplicationContext
            if !existing.isEmpty {
                applyContext(existing)
            }
        }
    }
    
    /// Called when iPhone reachability changes. This is the reliable moment to request credentials.
    func sessionReachabilityDidChange(_ session: WCSession) {
        NSLog("⌚️ WatchConnectivityManager: Reachability changed - isReachable: \(session.isReachable)")
        if session.isReachable, authManager?.isAuthenticated != true {
            requestCredentials()
        }
    }
}
