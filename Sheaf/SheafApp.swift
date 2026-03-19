import SwiftUI

@main
struct SheafApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var systemStore = SystemStore()

    var body: some Scene {
        WindowGroup {
            if authManager.isAuthenticated {
                ContentView()
                    .environmentObject(authManager)
                    .environmentObject(systemStore)
                    .onAppear {
                        systemStore.configure(auth: authManager)
                        systemStore.loadAll()
                    }
            } else if authManager.needsTOTP {
                TOTPView()
                    .environmentObject(authManager)
            } else {
                LoginView()
                    .environmentObject(authManager)
            }
        }
    }
}
