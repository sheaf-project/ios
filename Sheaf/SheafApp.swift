import SwiftUI
import AppIntents

@main
struct SheafApp: App {
    @StateObject private var authManager  = AuthManager()
    @StateObject private var systemStore  = SystemStore()
    @StateObject private var themeManager = ThemeManager()
    @State       private var selectedTab  = 0

    var body: some Scene {
        WindowGroup {
            RootView(selectedTab: $selectedTab)
                .environmentObject(authManager)
                .environmentObject(systemStore)
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.colorScheme)
        }
    }
}

// MARK: - RootView
// Sits inside the window so @Environment(\.colorScheme) correctly
// reflects the system appearance, including Dynamic Type changes.
struct RootView: View {
    @EnvironmentObject var authManager:  AuthManager
    @EnvironmentObject var systemStore:  SystemStore
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) private var systemScheme
    @Binding var selectedTab: Int

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                ContentView(selectedTab: $selectedTab)
                    .onAppear {
                        systemStore.configure(auth: authManager)
                        systemStore.loadAll()
                        PhoneConnectivityManager.shared.configure(auth: authManager)
                        PhoneConnectivityManager.shared.syncCredentials()
                        SheafShortcuts.updateAppShortcutParameters()
                    }
            } else if authManager.needsTOTP {
                TOTPView()
            } else {
                LoginView()
                    .onAppear { selectedTab = 0 }
            }
        }
        .environment(\.theme, resolvedTheme)
    }

    private var resolvedTheme: Theme {
        switch themeManager.mode {
        case .system: return Theme(isDark: systemScheme == .dark)
        case .dark:   return Theme(isDark: true)
        case .light:  return Theme(isDark: false)
        }
    }
}
