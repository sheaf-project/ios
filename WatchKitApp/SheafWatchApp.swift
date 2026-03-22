import SwiftUI
import AppIntents

@main
struct SheafWatchApp: App {
    @StateObject private var authManager = WatchAuthManager()
    @StateObject private var store       = WatchStore()

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
                        .onAppear {
                            store.configure(auth: authManager)
                            store.loadAll()
                            SheafShortcuts.updateAppShortcutParameters()
                        }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "iphone.and.arrow.forward")
                            .font(.system(size: 36))
                            .foregroundColor(.purple)

                        Text("Set up on iPhone")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)

                        Text("Open Sheaf on your iPhone and sign in to get started.")
                            .font(.system(size: 12))
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
        }
    }
}
