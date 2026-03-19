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
        self.authManager = auth
        // Apply any context already waiting from the last iPhone push
        applyContext(WCSession.default.receivedApplicationContext)
    }

    // MARK: - Receive from iPhone

    /// Called when the iPhone pushes updated application context.
    func session(_ session: WCSession,
                 didReceiveApplicationContext applicationContext: [String: Any]) {
        applyContext(applicationContext)
    }

    /// Also handle real-time messages (sent while both devices are reachable).
    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any]) {
        applyContext(message)
    }

    private func applyContext(_ context: [String: Any]) {
        guard
            let baseURL      = context["baseURL"]      as? String,
            let accessToken  = context["accessToken"]  as? String,
            let refreshToken = context["refreshToken"] as? String,
            !baseURL.isEmpty, !accessToken.isEmpty
        else { return }

        DispatchQueue.main.async { [weak self] in
            self?.authManager?.save(
                baseURL: baseURL,
                accessToken: accessToken,
                refreshToken: refreshToken
            )
        }
    }

    // MARK: - WCSessionDelegate boilerplate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {}
}
