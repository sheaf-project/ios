import SwiftUI

struct WatchTabView: View {
    @EnvironmentObject var authManager: WatchAuthManager
    @EnvironmentObject var store: WatchStore

    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    WatchHomeView()
                        .environmentObject(store)
                } label: {
                    Label("Fronting", systemImage: "person.2.fill")
                }

                NavigationLink {
                    WatchMembersView()
                        .environmentObject(store)
                } label: {
                    Label("Members", systemImage: "list.bullet")
                }

                NavigationLink {
                    WatchSwitchView()
                        .environmentObject(store)
                } label: {
                    Label("Switch Front", systemImage: "arrow.left.arrow.right")
                }

                NavigationLink {
                    WatchSettingsView()
                        .environmentObject(authManager)
                        .environmentObject(store)
                } label: {
                    Label("Settings", systemImage: "gearshape.fill")
                }
            }
            .navigationTitle("Sheaf")
        }
    }
}
