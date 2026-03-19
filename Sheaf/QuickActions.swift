import Combine
import UIKit

// MARK: - Quick Action Handler
final class QuickActionHandler: ObservableObject {
    static let shared = QuickActionHandler()

    @Published var pendingAction: QuickAction?

    enum QuickAction: String {
        case addToFront = "com.sheaf.addToFront"
        case addMember  = "com.sheaf.addMember"
    }

    func handle(_ shortcutItem: UIApplicationShortcutItem) {
        DispatchQueue.main.async {
            self.pendingAction = QuickAction(rawValue: shortcutItem.type)
        }
    }
}

// MARK: - Shortcut Items
extension UIApplicationShortcutItem {
    static let addToFront = UIApplicationShortcutItem(
        type: "com.sheaf.addToFront",
        localizedTitle: "Add to Front",
        localizedSubtitle: "Switch who is fronting",
        icon: UIApplicationShortcutIcon(systemImageName: "person.fill.checkmark"),
        userInfo: nil
    )
    static let addMember = UIApplicationShortcutItem(
        type: "com.sheaf.addMember",
        localizedTitle: "Add Member",
        localizedSubtitle: "Create a new system member",
        icon: UIApplicationShortcutIcon(systemImageName: "person.badge.plus"),
        userInfo: nil
    )
}

// MARK: - App Delegate
// Must return a scene configuration that uses our SceneDelegate
// so warm-start quick actions are received.
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        // Cold start — app wasn't running
        if let item = options.shortcutItem {
            QuickActionHandler.shared.handle(item)
        }
        // Point the scene at our SceneDelegate so it receives warm-start callbacks
        let config = UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
        config.delegateClass = SceneDelegate.self
        return config
    }
}

// MARK: - Scene Delegate
// This is the ONLY place warm-start quick actions reliably arrive in SwiftUI apps.
class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        QuickActionHandler.shared.handle(shortcutItem)
        completionHandler(true)
    }
}
