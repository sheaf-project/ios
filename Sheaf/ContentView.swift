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
                MembersTabView()
                    .tag(1)
                    .tabItem {
                        Label("Members", systemImage: "person.2.fill")
                    }
                HistoryView()
                    .tag(2)
                    .tabItem {
                        Label("History", systemImage: "clock.fill")
                    }
                JournalsView()
                    .tag(3)
                    .tabItem {
                        Label("Journal", systemImage: "book.fill")
                    }
                SettingsView()
                    .tag(4)
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
            }
            .tint(theme.accentLight)
        }
    }

    // MARK: - Private

    @Binding var selectedTab: Int
}

// MARK: - Members + Groups

struct MembersTabView: View {
    @Environment(\.theme) var theme
    @State private var section = 0
    @State private var showAddMember = false
    @State private var showAddGroup = false

    var body: some View {
        NavigationStack {
            ZStack {
                MembersView(showAddMember: $showAddMember)
                    .opacity(section == 0 ? 1 : 0)
                    .allowsHitTesting(section == 0)
                GroupsView(showAddGroup: $showAddGroup)
                    .opacity(section == 1 ? 1 : 0)
                    .allowsHitTesting(section == 1)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("", selection: $section) {
                        Text("Members").tag(0)
                        Text("Groups").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if section == 0 {
                            showAddMember = true
                        } else {
                            showAddGroup = true
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(theme.accentLight)
                    }
                    .accessibilityLabel(section == 0 ? "Add member" : "Add group")
                }
            }
        }
    }
}
