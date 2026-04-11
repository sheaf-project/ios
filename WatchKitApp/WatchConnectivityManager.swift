import Foundation
import Combine
import WatchConnectivity

extension Notification.Name {
    static let avatarsUpdated = Notification.Name("sheaf.avatarsUpdated")
}

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
        debugLog("WatchConnectivityManager: Configuring with auth manager")
        self.authManager = auth
        
        // Apply any credentials that arrived before configure() was called
        if let pending = pendingContext {
            debugLog("WatchConnectivityManager: Applying pending context")
            pendingContext = nil
            applyContext(pending)
        }
        
        // Apply any context already waiting from the last iPhone push
        let existingContext = WCSession.default.receivedApplicationContext
        if !existingContext.isEmpty {
            debugLog("WatchConnectivityManager: Found existing application context, applying")
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
            debugLog("WatchConnectivityManager: Cannot request credentials - session not activated")
            return
        }

        // Prefer sendMessage — it gets live credentials from the iPhone,
        // rather than potentially stale receivedApplicationContext.
        if WCSession.default.isReachable {
            debugLog("WatchConnectivityManager: Requesting credentials from iPhone via sendMessage...")
            WCSession.default.sendMessage(["request": "credentials"], replyHandler: { [weak self] reply in
                debugLog("WatchConnectivityManager: Received credential reply from iPhone")
                self?.applyContext(reply)
            }, errorHandler: { [weak self] error in
                debugLog("WatchConnectivityManager: sendMessage failed: \(error.localizedDescription), falling back to application context")
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
            debugLog("WatchConnectivityManager: iPhone not reachable, applying receivedApplicationContext")
            applyContext(existing)
        } else {
            debugLog("WatchConnectivityManager: iPhone not reachable, no cached context, will retry when reachable")
        }
    }

    // MARK: - Receive from iPhone

    func session(_ session: WCSession,
                 didReceiveApplicationContext applicationContext: [String: Any]) {
        debugLog("WatchConnectivityManager: Received application context")
        applyContext(applicationContext)
    }

    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any]) {
        debugLog("WatchConnectivityManager: Received message (no reply)")
        applyContext(message)
    }

    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        debugLog("WatchConnectivityManager: Received message (with reply)")
        applyContext(message)
        replyHandler(["status": "received"])
    }
    
    /// Called by watchOS when `didReceiveUserInfo` fires (queued transfer from iPhone).
    func session(_ session: WCSession,
                 didReceiveUserInfo userInfo: [String: Any] = [:]) {
        debugLog("WatchConnectivityManager: Received userInfo transfer")
        applyContext(userInfo)
    }

    /// Called when the iPhone sends a file via `transferFile`.
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        guard let memberID = file.metadata?["avatarID"] as? String else {
            debugLog("WatchConnectivityManager: Received file without avatarID metadata")
            return
        }
        let cacheDir = Self.avatarCacheDirectory
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        let destURL = cacheDir.appendingPathComponent(memberID + ".jpg")
        // Remove existing file if any, then move the received file
        try? FileManager.default.removeItem(at: destURL)
        do {
            try FileManager.default.moveItem(at: file.fileURL, to: destURL)
            debugLog("WatchConnectivityManager: Saved avatar file for member \(memberID)")
        } catch {
            // moveItem can fail if cross-volume; fall back to copy
            if let data = try? Data(contentsOf: file.fileURL) {
                try? data.write(to: destURL)
                debugLog("WatchConnectivityManager: Copied avatar file for member \(memberID)")
            } else {
                debugLog("WatchConnectivityManager: Failed to save avatar for \(memberID): \(error)")
            }
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .avatarsUpdated, object: nil)
        }
    }

    /// Directory for avatar images synced from the iPhone.
    static var avatarCacheDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("avatars")
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
            debugLog("WatchConnectivityManager: Auth manager not configured yet, stashing credentials")
            pendingContext = context
            return
        }

        // Sync Cloudflare Access tokens if present
        if let cfId = context["cfClientId"] as? String,
           let cfSecret = context["cfClientSecret"] as? String,
           !cfId.isEmpty, !cfSecret.isEmpty {
            try? KeychainHelper.save(key: "sheaf_cf_client_id", value: cfId)
            try? KeychainHelper.save(key: "sheaf_cf_client_secret", value: cfSecret)
        }

        debugLog("WatchConnectivityManager: Saving credentials...")
        DispatchQueue.main.async {
            authManager.save(
                baseURL: baseURL,
                accessToken: accessToken,
                refreshToken: refreshToken
            )
            debugLog("WatchConnectivityManager: Credentials saved, isAuthenticated: \(authManager.isAuthenticated)")
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        debugLog("WatchConnectivityManager: Session activated with state: \(activationState.rawValue)")
        if let error = error {
            debugLog("WatchConnectivityManager: Activation error: \(error)")
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
        debugLog("WatchConnectivityManager: Reachability changed - isReachable: \(session.isReachable)")
        if session.isReachable, authManager?.isAuthenticated != true {
            requestCredentials()
        }
    }
}
