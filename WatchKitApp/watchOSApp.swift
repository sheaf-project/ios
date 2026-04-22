import SwiftUI
import AppIntents

@main
struct watchOSApp: App {
    @StateObject private var authManager = WatchAuthManager()
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
                }
            }
        }
    }
}
