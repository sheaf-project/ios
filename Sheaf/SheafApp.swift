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
    @ObservedObject var lockManager = AppLockManager.shared
    @EnvironmentObject var quickActions: QuickActionHandler
    @Environment(\.colorScheme) private var systemScheme
    @Binding var selectedTab: Int

    @State private var pendingRedemption: PendingRedemption?
    @State private var presentedRedemption: PendingRedemption?

    struct PendingRedemption: Identifiable {
        let id = UUID()
        let code: String
        // For mobile_push activation links the URL carries an `instance`
        // query param naming the Sheaf instance that owns the channel.
        // Other (legacy) redemption paths don't include it.
        let instanceURL: String?
    }

    var body: some View {
        ZStack {
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
                } else if authManager.needsOnboarding {
                    OnboardingView()
                } else {
                    MainView(selectedTab: $selectedTab)
                }
            }

            if lockManager.isLocked && authManager.isAuthenticated {
                AppLockView()
                    .transition(.opacity)
            }
        }
        .environment(\.theme, resolvedTheme)
        .environment(\.apiBaseURL, authManager.baseURL)
        .environment(\.apiAccessToken, authManager.accessToken)
        .alert("Error", isPresented: Binding(
            get: { systemStore.errorMessage != nil },
            set: { if !$0 { systemStore.errorMessage = nil } }
        )) {
            Button("OK") { systemStore.errorMessage = nil }
        } message: {
            Text(systemStore.errorMessage ?? "")
        }
        .sheet(item: $presentedRedemption) { redemption in
            NotificationRedemptionSheet(
                activationCode: redemption.code,
                instanceURL: redemption.instanceURL
            )
                .environmentObject(authManager)
                .environment(\.theme, resolvedTheme)
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .onAppear {
            // Configure PhoneConnectivityManager as soon as we have access to authManager
            PhoneConnectivityManager.shared.configure(auth: authManager)

            // Sync credentials to watch if already authenticated
            if authManager.isAuthenticated {
                debugLog("RootView: User already authenticated, syncing to watch")
                PhoneConnectivityManager.shared.syncCredentials()
            }
        }
        .onChange(of: authManager.isAuthenticated) {
            if authManager.isAuthenticated, let pending = pendingRedemption {
                presentedRedemption = pending
                pendingRedemption = nil
            } else if !authManager.isAuthenticated {
                systemStore.clearState()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            lockManager.lockIfEnabled()
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }

        let isRedemptionLink: Bool
        if url.scheme == "sheaf" {
            isRedemptionLink = url.host == "notifications" && url.path.hasPrefix("/redeem")
        } else if url.host?.lowercased() == "sheaf.sh" && url.path == "/redeem" {
            // mobile_push activation links funnel through the shared
            // Universal Link host (see backend mobile_activation_url).
            isRedemptionLink = true
        } else {
            isRedemptionLink = url.path.contains("/notifications/redeem")
        }

        guard isRedemptionLink else { return }

        guard let code = components.queryItems?.first(where: { $0.name == "code" })?.value else { return }
        let instance = components.queryItems?.first(where: { $0.name == "instance" })?.value
        let redemption = PendingRedemption(code: code, instanceURL: instance)
        if authManager.isAuthenticated {
            presentedRedemption = redemption
        } else {
            pendingRedemption = redemption
        }
    }

    private var resolvedTheme: Theme {
        let palette = themeManager.palette
        switch themeManager.mode {
        case .system: return Theme(isDark: systemScheme == .dark, palette: palette)
        case .dark:   return Theme(isDark: true,  palette: palette)
        case .light:  return Theme(isDark: false, palette: palette)
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
                ShortcutsDataStore.shared.configure(auth: authManager)
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
                    if me.accountStatus == .pendingDeletion {
                        authManager.deletionRequestedAt = me.deletionRequestedAt
                        if let config = try? await api.getAuthConfig(),
                           let days = config["account_deletion_grace_days"] as? Int {
                            authManager.deletionGraceDays = days
                        }
                    }
                    guard me.emailVerified,
                          me.accountStatus == .active || me.accountStatus == .pendingDeletion else { return }
                }
                systemStore.loadAll()

                PushNotificationManager.shared.configure(auth: authManager)
                await PushNotificationManager.shared.requestPermissionAndRegister()
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
