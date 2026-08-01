import SwiftUI
import AppIntents
import WatchKit

@main
struct watchOSApp: App {
    @WKApplicationDelegateAdaptor(ExtensionDelegate.self) private var extensionDelegate
    @StateObject private var authManager = WatchAuthManager.shared
    @StateObject private var store       = WatchStore()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Don't configure here - do it in onAppear so we have the actual authManager instance
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    WatchTabView()
                        .environmentObject(authManager)
                        .environmentObject(store)
                        .environment(\.apiBaseURL, authManager.baseURL)
                        .environment(\.apiAccessToken, authManager.accessToken)
                        .onAppear {
                            store.configure(auth: authManager)
                            store.loadAll()
                            SheafShortcuts.updateAppShortcutParameters()
                        }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "iphone.and.arrow.forward")
                            .font(.largeTitle)
                            .foregroundStyle(.tint)

                        Text("Set up on iPhone")
                            .font(.subheadline).fontWeight(.bold).fontDesign(.rounded)
                            .multilineTextAlignment(.center)

                        Text("Open Sheaf on your iPhone and sign in to get started.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Button("Refresh") {
                            authManager.loadCredentials()
                            WatchConnectivityManager.shared.requestCredentials()
                        }
                        .buttonStyle(.bordered)
                        .tint(.purple)
                    }
                    .padding()
                }
            }
            .onAppear {
                // Configure connectivity manager with the actual authManager instance
                WatchConnectivityManager.shared.configure(auth: authManager)
                // Also try loading from App Group on appear
                authManager.loadCredentials()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active && authManager.isAuthenticated {
                    store.loadAll()
                } else if newPhase == .background {
                    WatchBackgroundRefresh.schedule()
                }
            }
        }
    }
}

// MARK: - Background Refresh
// Periodically refreshes the shared fronting snapshot so complications stay
// current while the app is suspended. watchOS schedules these opportunistically.
final class ExtensionDelegate: NSObject, WKApplicationDelegate {
    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            guard let refreshTask = task as? WKApplicationRefreshBackgroundTask else {
                task.setTaskCompletedWithSnapshot(false)
                continue
            }
            WatchBackgroundRefresh.schedule()
            Task {
                await WatchBackgroundRefresh.refresh()
                refreshTask.setTaskCompletedWithSnapshot(false)
            }
        }
    }
}

enum WatchBackgroundRefresh {
    static func schedule() {
        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: Date(timeIntervalSinceNow: 15 * 60),
            userInfo: nil
        ) { _ in }
    }

    @MainActor
    static func refresh() async {
        let auth = WatchAuthManager.shared
        guard auth.isAuthenticated else { return }

        let api = WatchAPIClient(auth: auth)
        guard let fronts = try? await api.getCurrentFronts(),
              let members = try? await api.getMembers() else { return }

        let ids = Set(fronts.flatMap { $0.memberIDs })
        let fronting = members.filter { ids.contains($0.id) }
        WatchFrontingWidgetSync.write(frontingMembers: fronting, currentFronts: fronts)
    }
}
