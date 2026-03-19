import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var systemStore: SystemStore
    @Binding var selectedTab: Int

    var body: some View {
        TabView(selection: $selectedTab) {
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
        .tint(Color(hex: "#A78BFA")!)
        .alert("Error", isPresented: Binding(
            get: { systemStore.errorMessage != nil },
            set: { if !$0 { systemStore.errorMessage = nil } }
        )) {
            Button("OK") { systemStore.errorMessage = nil }
        } message: {
            Text(systemStore.errorMessage ?? "")
        }
    }
}
