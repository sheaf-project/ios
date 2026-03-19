import SwiftUI

struct WatchTabView: View {
    @EnvironmentObject var authManager: WatchAuthManager
    @EnvironmentObject var store: WatchStore

    var body: some View {
        TabView {
            WatchHomeView()
                .environmentObject(store)
                .tag(0)

            WatchMembersView()
                .environmentObject(store)
                .tag(1)

            WatchSwitchView()
                .environmentObject(store)
                .tag(2)

            WatchSettingsView()
                .environmentObject(authManager)
                .environmentObject(store)
                .tag(3)
        }
        .tabViewStyle(.page)
    }
}
