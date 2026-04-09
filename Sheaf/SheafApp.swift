import SwiftUI
import AppIntents
import UIKit

@main
struct SheafApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authManager      = AuthManager()
    @StateObject private var systemStore      = SystemStore()
    @StateObject private var themeManager     = ThemeManager()
    @StateObject private var networkMonitor   = NetworkMonitor.shared
    @ObservedObject private var quickActions = QuickActionHandler.shared
    @State private var selectedTab = 0

    init() {
        // Configure PhoneConnectivityManager as early as possible
        // Note: Can't use authManager directly here since @StateObject isn't initialized yet
        // We'll configure it in RootView.onAppear instead
    }

    var body: some Scene {
        WindowGroup {
            RootView(selectedTab: $selectedTab)
                .environmentObject(authManager)
                .environmentObject(systemStore)
                .environmentObject(themeManager)
                .environmentObject(quickActions)
                .environmentObject(networkMonitor)
                .preferredColorScheme(themeManager.colorScheme)
        }
    }
}

// MARK: - RootView
struct RootView: View {
    @EnvironmentObject var authManager:  AuthManager
    @EnvironmentObject var systemStore:  SystemStore
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var quickActions: QuickActionHandler
    @Environment(\.colorScheme) private var systemScheme
    @Binding var selectedTab: Int

    var body: some View {
        Group {
            if !authManager.isAuthenticated && !authManager.needsTOTP {
                LoginView()
                    .onAppear { selectedTab = 0 }
            } else if authManager.needsTOTP {
                TOTPView()
            } else if !authManager.emailVerified {
                EmailVerificationGateView()
            } else if authManager.accountStatus == .pendingApproval {
                AccountPendingGateView()
            } else if authManager.accountStatus == .banned || authManager.accountStatus == .suspended {
                AccountRejectedGateView()
            } else {
                MainView(selectedTab: $selectedTab)
            }
        }
        .environment(\.theme, resolvedTheme)
        .environment(\.apiBaseURL, authManager.baseURL)
        .environment(\.apiAccessToken, authManager.accessToken)
        .onAppear {
            // Configure PhoneConnectivityManager as soon as we have access to authManager
            PhoneConnectivityManager.shared.configure(auth: authManager)
            
            // Sync credentials to watch if already authenticated
            if authManager.isAuthenticated {
                NSLog("📱 RootView: User already authenticated, syncing to watch")
                PhoneConnectivityManager.shared.syncCredentials()
            }
        }
    }

    private var resolvedTheme: Theme {
        switch themeManager.mode {
        case .system: return Theme(isDark: systemScheme == .dark)
        case .dark:   return Theme(isDark: true)
        case .light:  return Theme(isDark: false)
        }
    }
}

// MARK: - MainView
// Separated so sheets and tab state are all in the same view scope
struct MainView: View {
    @EnvironmentObject var authManager:  AuthManager
    @EnvironmentObject var systemStore:  SystemStore
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var quickActions: QuickActionHandler
    @Binding var selectedTab: Int

    @State private var showSwitchSheet = false
    @State private var showAddMember   = false

    var body: some View {
        ContentView(selectedTab: $selectedTab)
            .sheet(isPresented: $showSwitchSheet) {
                QuickSwitchFrontSheet()
                    .environmentObject(systemStore)
            }
            .sheet(isPresented: $showAddMember) {
                MemberEditSheet(member: nil)
                    .environmentObject(systemStore)
            }
            .task {
                systemStore.configure(auth: authManager, themeManager: themeManager)
                // Configure and sync credentials with watch
                PhoneConnectivityManager.shared.configure(auth: authManager)
                PhoneConnectivityManager.shared.syncCredentials()
                SheafShortcuts.updateAppShortcutParameters()
                donateQuickActions()
                // Check account status before loading data — if the
                // server requires email verification or the account is
                // pending/rejected, updating authManager here will
                // switch the view before any resource calls fire.
                let api = APIClient(auth: authManager)
                if let me = try? await api.getMe() {
                    authManager.accountStatus = me.accountStatus
                    authManager.emailVerified = me.emailVerified
                    guard me.emailVerified,
                          me.accountStatus == .active else { return }
                }
                systemStore.loadAll()
            }
            .onReceive(quickActions.$pendingAction) { action in
                guard let action else { return }
                quickActions.pendingAction = nil
                switch action {
                case .addToFront:
                    selectedTab = 0
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showSwitchSheet = true
                    }
                case .addMember:
                    selectedTab = 1
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showAddMember = true
                    }
                }
            }
    }

    private func donateQuickActions() {
        UIApplication.shared.shortcutItems = [.addToFront, .addMember]
    }
}
