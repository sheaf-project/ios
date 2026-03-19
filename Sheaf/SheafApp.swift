import SwiftUI
import AppIntents
import UIKit

@main
struct SheafApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authManager   = AuthManager()
    @StateObject private var systemStore   = SystemStore()
    @StateObject private var themeManager  = ThemeManager()
    @ObservedObject private var quickActions = QuickActionHandler.shared
    @State private var selectedTab = 0

    var body: some Scene {
        WindowGroup {
            RootView(selectedTab: $selectedTab)
                .environmentObject(authManager)
                .environmentObject(systemStore)
                .environmentObject(themeManager)
                .environmentObject(quickActions)
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
            if authManager.isAuthenticated {
                MainView(selectedTab: $selectedTab)
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

// MARK: - MainView
// Separated so sheets and tab state are all in the same view scope
struct MainView: View {
    @EnvironmentObject var authManager:  AuthManager
    @EnvironmentObject var systemStore:  SystemStore
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
            .onAppear {
                systemStore.configure(auth: authManager)
                systemStore.loadAll()
                PhoneConnectivityManager.shared.configure(auth: authManager)
                PhoneConnectivityManager.shared.syncCredentials()
                SheafShortcuts.updateAppShortcutParameters()
                donateQuickActions()
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
