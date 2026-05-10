import Combine
import Foundation
import UIKit
import UserNotifications

@MainActor
final class PushNotificationManager: NSObject, ObservableObject {
    static let shared = PushNotificationManager()

    @Published private(set) var permissionGranted = false
    @Published private(set) var deviceToken: Data?

    private var auth: AuthManager?
    private let installIdKey = "sheaf_push_install_id"
    private let deviceTokenKey = "sheaf_push_device_token"

    private override init() {
        super.init()
    }

    func configure(auth: AuthManager) {
        self.auth = auth
    }

    // MARK: - Install ID

    var installId: String? {
        KeychainHelper.get(key: installIdKey)
    }

    private func ensureInstallId() -> String {
        if let existing = installId { return existing }
        let id = UUID().uuidString
        try? KeychainHelper.save(key: installIdKey, value: id)
        return id
    }

    func clearInstallId() {
        KeychainHelper.delete(key: installIdKey)
        KeychainHelper.delete(key: deviceTokenKey)
        deviceToken = nil
    }

    // MARK: - Platform Detection

    static var apnsPlatform: PushDevicePlatform {
        if let profile = Self.embeddedProvisioningProfile(),
           let entitlements = profile["Entitlements"] as? [String: Any],
           let env = entitlements["aps-environment"] as? String {
            return env == "production" ? .apnsProd : .apnsDev
        }
        #if DEBUG
        return .apnsDev
        #else
        return .apnsProd
        #endif
    }

    private static func embeddedProvisioningProfile() -> [String: Any]? {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url) else { return nil }
        guard let string = String(data: data, encoding: .ascii) else { return nil }
        guard let plistStart = string.range(of: "<?xml"),
              let plistEnd = string.range(of: "</plist>") else { return nil }
        let plistString = String(string[plistStart.lowerBound...plistEnd.upperBound])
        guard let plistData = plistString.data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else { return nil }
        return plist
    }

    // MARK: - Permission & Registration

    func requestPermissionAndRegister() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            permissionGranted = granted
            if granted {
                registerNotificationCategories()
                UIApplication.shared.registerForRemoteNotifications()
            }
        } catch {
            debugLog("PushNotificationManager: Permission request failed: \(error)")
        }
    }

    func checkPermissionStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        permissionGranted = settings.authorizationStatus == .authorized
    }

    // MARK: - Token Handling

    func didRegisterForRemoteNotifications(deviceToken token: Data) {
        self.deviceToken = token
        let hex = token.map { String(format: "%02x", $0) }.joined()
        try? KeychainHelper.save(key: deviceTokenKey, value: hex)
        debugLog("PushNotificationManager: Received device token (\(hex.prefix(8))...)")
        Task { await registerWithServer() }
    }

    func didFailToRegisterForRemoteNotifications(error: Error) {
        debugLog("PushNotificationManager: Registration failed: \(error)")
    }

    func registerWithServer() async {
        guard let auth, auth.isAuthenticated else { return }
        guard let tokenHex = KeychainHelper.get(key: deviceTokenKey), !tokenHex.isEmpty else { return }

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let registration = PushDeviceRegister(
            platform: Self.apnsPlatform,
            token: tokenHex,
            installId: ensureInstallId(),
            appVersion: version
        )

        let api = APIClient(auth: auth)
        do {
            try await api.registerPushDevice(registration)
            debugLog("PushNotificationManager: Registered with server")
        } catch {
            debugLog("PushNotificationManager: Server registration failed: \(error)")
        }
    }

    func unregisterFromServer() async {
        guard let auth else { return }
        guard let tokenHex = KeychainHelper.get(key: deviceTokenKey), !tokenHex.isEmpty else { return }

        let api = APIClient(auth: auth)
        do {
            try await api.unregisterPushDevice(token: tokenHex)
            debugLog("PushNotificationManager: Unregistered from server")
        } catch {
            debugLog("PushNotificationManager: Server unregistration failed: \(error)")
        }
    }

    // MARK: - Notification Categories

    private func registerNotificationCategories() {
        let frontChange = UNNotificationCategory(
            identifier: "FRONT_CHANGE",
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        let reminder = UNNotificationCategory(
            identifier: "REMINDER",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        let system = UNNotificationCategory(
            identifier: "SYSTEM",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([frontChange, reminder, system])
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        debugLog("PushNotificationManager: Notification tapped: \(userInfo)")
    }
}
