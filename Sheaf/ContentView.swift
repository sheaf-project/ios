import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var systemStore: SystemStore
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            if !networkMonitor.isOnline {
                HStack(spacing: 8) {
                    Image(systemName: "wifi.slash")
                        .font(.caption)
                    Text("Offline — changes will sync when reconnected")
                        .font(.caption)
                    if systemStore.pendingOperationCount > 0 {
                        Text("(\(systemStore.pendingOperationCount) pending)")
                            .font(.caption2)
                            .foregroundColor(theme.textSecondary)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(theme.warning)
            } else if systemStore.isSyncing {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.7)
                    Text("Syncing changes...")
                        .font(.caption)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(theme.accentLight)
            }

            TabView(selection: Binding(
                get: { selectedTab },
                set: { selectedTab = $0 }
            )) {
                HomeView()
                    .tag(0)
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                MembersView()
                    .tag(1)
                    .tabItem {
                        Label("Members", systemImage: "person.2.fill")
                    }
                GroupsView()
                    .tag(2)
                    .tabItem {
                        Label("Groups", systemImage: "square.grid.2x2.fill")
                    }
                HistoryView()
                    .tag(3)
                    .tabItem {
                        Label("History", systemImage: "clock.fill")
                    }
                SettingsView()
                    .tag(4)
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
            }
            .tint(theme.accentLight)
        }
        .alert("Error", isPresented: Binding(
            get: { systemStore.errorMessage != nil },
            set: { if !$0 { systemStore.errorMessage = nil } }
        )) {
            Button("OK") { systemStore.errorMessage = nil }
        } message: {
            Text(systemStore.errorMessage ?? "")
        }
    }

    // MARK: - Private

    @Binding var selectedTab: Int
}
