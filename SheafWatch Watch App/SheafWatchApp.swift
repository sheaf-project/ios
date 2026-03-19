import SwiftUI

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
                        }
                } else {
                    WatchLoginView()
                        .environmentObject(authManager)
                        .onAppear {
                            WatchConnectivityManager.shared.configure(auth: authManager)
                        }
                }
            }
        }
    }
}
