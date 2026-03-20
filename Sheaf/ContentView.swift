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
                    Label(LocalizedStrings.home, systemImage: "house.fill")
                }
            MembersView()
                .tag(1)
                .tabItem {
                    Label(LocalizedStrings.members, systemImage: "person.2.fill")
                }
            GroupsView()
                .tag(2)
                .tabItem {
                    Label(LocalizedStrings.groups, systemImage: "square.grid.2x2.fill")
                }
            HistoryView()
                .tag(3)
                .tabItem {
                    Label(LocalizedStrings.history, systemImage: "clock.fill")
                }
            SettingsView()
                .tag(4)
                .tabItem {
                    Label(LocalizedStrings.settings, systemImage: "gearshape.fill")
                }
        }
        .tint(Color(hex: "#A78BFA")!)
        .alert(LocalizedStrings.errorTitle, isPresented: Binding(
            get: { systemStore.errorMessage != nil },
            set: { if !$0 { systemStore.errorMessage = nil } }
        )) {
            Button(LocalizedStrings.ok) { systemStore.errorMessage = nil }
        } message: {
            Text(systemStore.errorMessage ?? "")
        }
    }
}
