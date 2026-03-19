import SwiftUI
import AppIntents

@main
struct SheafWatchApp: App {
    @StateObject private var authManager = WatchAuthManager()
    @StateObject private var store       = WatchStore()

    init() {
        WatchConnectivityManager.shared.configure(auth: WatchAuthManager())
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
                            WatchConnectivityManager.shared.configure(auth: authManager)
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
                    }
                    .padding()
                    .onAppear {
                        WatchConnectivityManager.shared.configure(auth: authManager)
                    }
                }
            }
        }
    }
}
