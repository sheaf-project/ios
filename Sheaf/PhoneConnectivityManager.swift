import Foundation
import Combine
import UIKit
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
            debugLog("PhoneConnectivityManager: Setting up WCSession")
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func configure(auth: AuthManager) {
        debugLog("PhoneConnectivityManager: configure(auth:) called, isAuthenticated: \(auth.isAuthenticated)")
        self.authManager = auth
    }

    // MARK: - Push to watch

    /// Call this after login, token refresh, or any credential change.
    /// Pushes the *watch's* companion-session credentials (not the phone's)
    /// so the watch can rotate its one-shot refresh JWT without colliding
    /// with the phone's rotation. If no watch session has been minted yet,
    /// kicks off the mint first.
    func syncCredentials() {
        guard let auth = authManager, !auth.accessToken.isEmpty else {
            debugLog("PhoneConnectivityManager: No credentials to sync (authManager: \(authManager != nil))")
            return
        }

        guard WCSession.default.activationState == .activated else {
            debugLog("PhoneConnectivityManager: Session not activated, can't sync")
            return
        }

        // Don't mint a server-side watch session for users who don't have
        // a watch paired — would just create unused sessions on the server.
        guard WCSession.default.isWatchAppInstalled else {
            debugLog("PhoneConnectivityManager: Watch app not installed, skipping sync")
            return
        }

        Task { [weak self] in
            guard let self = self else { return }
            if !auth.hasWatchCredentials {
                _ = await auth.provisionWatchSession()
            }
            await MainActor.run { self.pushWatchCredentialsToWatch() }
        }
    }

    /// Build the watch payload and push via all three WCSession channels.
    /// Must be called on the main thread (touches WCSession state).
    private func pushWatchCredentialsToWatch() {
        guard let auth = authManager, auth.hasWatchCredentials else {
            debugLog("PhoneConnectivityManager: No watch credentials to push")
            return
        }

        var context: [String: Any] = [
            "baseURL":      auth.baseURL,
            "accessToken":  auth.watchAccessToken,
            "refreshToken": auth.watchRefreshToken,
        ]
        if let cfId = KeychainHelper.get(key: "sheaf_cf_client_id"), !cfId.isEmpty,
           let cfSecret = KeychainHelper.get(key: "sheaf_cf_client_secret"), !cfSecret.isEmpty {
            context["cfClientId"] = cfId
            context["cfClientSecret"] = cfSecret
        }

        // 1. updateApplicationContext — persists until Watch reads it (survives reboots).
        do {
            try WCSession.default.updateApplicationContext(context)
            debugLog("PhoneConnectivityManager: Sent via updateApplicationContext")
        } catch {
            debugLog("PhoneConnectivityManager: updateApplicationContext failed: \(error.localizedDescription)")
        }

        // 2. transferUserInfo — queued delivery, guaranteed even when Watch app isn't running.
        WCSession.default.transferUserInfo(context)
        debugLog("PhoneConnectivityManager: Queued via transferUserInfo")

        // 3. sendMessage — immediate delivery if Watch is reachable right now.
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(context, replyHandler: { reply in
                debugLog("PhoneConnectivityManager: Watch confirmed receipt: \(reply)")
            }, errorHandler: { error in
                debugLog("PhoneConnectivityManager: sendMessage failed: \(error.localizedDescription)")
            })
        }
    }

    // MARK: - Avatar Sync

    /// Downloads member avatars on iPhone (which can decode WebP), converts to JPEG,
    /// and sends each to the watch via individual file transfers.
    func syncAvatars(members: [Member], baseURL: String, accessToken: String) {
        guard WCSession.default.activationState == .activated,
              WCSession.default.isWatchAppInstalled else {
            debugLog("PhoneConnectivityManager: Cannot sync avatars - activated: \(WCSession.default.activationState == .activated), watchInstalled: \(WCSession.default.isWatchAppInstalled)")
            return
        }

        Task {
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("avatarSync")
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            var syncedCount = 0
            for member in members {
                guard let avatarURL = member.avatarURL, !avatarURL.isEmpty,
                      let url = resolveAvatarURL(avatarURL, baseURL: baseURL) else { continue }

                var request = URLRequest(url: url)
                if avatarURL.hasPrefix("/") {
                    if !accessToken.isEmpty {
                        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                    }
                    if let cfID = KeychainHelper.get(key: "sheaf_cf_client_id"), !cfID.isEmpty,
                       let cfSecret = KeychainHelper.get(key: "sheaf_cf_client_secret"), !cfSecret.isEmpty {
                        request.setValue(cfID, forHTTPHeaderField: "CF-Access-Client-Id")
                        request.setValue(cfSecret, forHTTPHeaderField: "CF-Access-Client-Secret")
                    }
                }

                guard let (data, response) = try? await URLSession.shared.data(for: request),
                      let http = response as? HTTPURLResponse,
                      (200...299).contains(http.statusCode),
                      let image = UIImage(data: data) else { continue }

                let targetSize = CGSize(width: 128, height: 128)
                let renderer = UIGraphicsImageRenderer(size: targetSize)
                let thumbnail = renderer.image { _ in
                    image.draw(in: CGRect(origin: .zero, size: targetSize))
                }
                guard let jpeg = thumbnail.jpegData(compressionQuality: 0.7) else { continue }

                let tempFile = tempDir.appendingPathComponent("\(member.id).jpg")
                do {
                    try jpeg.write(to: tempFile)
                    WCSession.default.transferFile(tempFile, metadata: ["avatarID": member.id])
                    syncedCount += 1
                } catch {
                    debugLog("PhoneConnectivityManager: Failed to write temp avatar for \(member.id): \(error)")
                }
            }
            debugLog("PhoneConnectivityManager: Queued \(syncedCount) avatar file transfers to watch")
        }
    }

    // MARK: - Receive from Watch

    /// Handle messages from Watch WITH a reply handler (e.g. credential requests, avatar requests).
    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        debugLog("PhoneConnectivityManager: Received message from Watch: \(Array(message.keys))")

        if message["request"] as? String == "credentials" {
            guard let auth = authManager, !auth.accessToken.isEmpty else {
                debugLog("PhoneConnectivityManager: Watch requested credentials but none available (authManager: \(authManager != nil))")
                replyHandler(["error": "not_authenticated"])
                return
            }
            // Watch always gets its own companion session, never the
            // phone's tokens. If the watch is asking because its session
            // was revoked/expired, force a fresh mint so it gets a working
            // pair instead of one tied to a dead session.
            Task { [weak self] in
                guard let self = self, let auth = self.authManager else {
                    replyHandler(["error": "not_authenticated"])
                    return
                }
                let force = (message["force"] as? Bool) ?? false
                let ok = await auth.provisionWatchSession(force: force || !auth.hasWatchCredentials)
                guard ok, auth.hasWatchCredentials else {
                    replyHandler(["error": "not_authenticated"])
                    return
                }
                var credentials: [String: Any] = [
                    "baseURL":      auth.baseURL,
                    "accessToken":  auth.watchAccessToken,
                    "refreshToken": auth.watchRefreshToken,
                ]
                if let cfId = KeychainHelper.get(key: "sheaf_cf_client_id"), !cfId.isEmpty,
                   let cfSecret = KeychainHelper.get(key: "sheaf_cf_client_secret"), !cfSecret.isEmpty {
                    credentials["cfClientId"] = cfId
                    credentials["cfClientSecret"] = cfSecret
                }
                debugLog("PhoneConnectivityManager: Sending watch credentials via reply")
                replyHandler(credentials)
            }
            return
        }

        // On-demand avatar request from Watch
        if let memberID = message["requestAvatar"] as? String,
           let avatarURLString = message["avatarURL"] as? String,
           let baseURLString = message["baseURL"] as? String {
            debugLog("PhoneConnectivityManager: Watch requested avatar for member \(memberID)")
            Task {
                guard let url = resolveAvatarURL(avatarURLString, baseURL: baseURLString) else {
                    debugLog("PhoneConnectivityManager: Could not resolve avatar URL")
                    replyHandler([:])
                    return
                }
                var request = URLRequest(url: url)
                if avatarURLString.hasPrefix("/") {
                    if let auth = authManager, !auth.accessToken.isEmpty {
                        request.setValue("Bearer \(auth.accessToken)", forHTTPHeaderField: "Authorization")
                    }
                    if let cfID = KeychainHelper.get(key: "sheaf_cf_client_id"), !cfID.isEmpty,
                       let cfSecret = KeychainHelper.get(key: "sheaf_cf_client_secret"), !cfSecret.isEmpty {
                        request.setValue(cfID, forHTTPHeaderField: "CF-Access-Client-Id")
                        request.setValue(cfSecret, forHTTPHeaderField: "CF-Access-Client-Secret")
                    }
                }
                guard let (data, response) = try? await URLSession.shared.data(for: request),
                      let http = response as? HTTPURLResponse,
                      (200...299).contains(http.statusCode),
                      let image = UIImage(data: data) else {
                    debugLog("PhoneConnectivityManager: Failed to download avatar for member \(memberID)")
                    replyHandler([:])
                    return
                }
                let targetSize = CGSize(width: 128, height: 128)
                let renderer = UIGraphicsImageRenderer(size: targetSize)
                let thumbnail = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: targetSize)) }
                if let jpeg = thumbnail.jpegData(compressionQuality: 0.7) {
                    debugLog("PhoneConnectivityManager: Sending \(jpeg.count) bytes avatar for member \(memberID)")
                    replyHandler(["avatarData": jpeg])
                } else {
                    replyHandler([:])
                }
            }
            return
        }

        replyHandler(["status": "unknown_request"])
    }
    
    /// Handle messages from Watch WITHOUT a reply handler.
    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any]) {
        debugLog("PhoneConnectivityManager: Received message (no reply) from Watch: \(Array(message.keys))")
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        debugLog("PhoneConnectivityManager: Session activated with state: \(activationState.rawValue), watchAppInstalled: \(session.isWatchAppInstalled)")
        if let error = error {
            debugLog("PhoneConnectivityManager: Activation error: \(error)")
        }
        if activationState == .activated {
            syncCredentials()
        }
    }
    
    /// Called when the Watch app is installed, uninstalled, or the watch is paired/unpaired.
    func sessionWatchStateDidChange(_ session: WCSession) {
        debugLog("PhoneConnectivityManager: Watch state changed - installed: \(session.isWatchAppInstalled), paired: \(session.isPaired)")
        if session.isWatchAppInstalled {
            syncCredentials()
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
}
