import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var systemStore: SystemStore
    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tag(0)
                MembersView()
                    .tag(1)
                GroupsView()
                    .tag(2)
                HistoryView()
                    .tag(3)
                SettingsView()
                    .tag(4)
            }

            CustomTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            systemStore.configure(auth: authManager)
            systemStore.loadAll()
            UITabBar.appearance().isHidden = true
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
}

// MARK: - Custom Tab Bar
struct CustomTabBar: View {
    @Binding var selectedTab: Int

    let items: [(icon: String, label: String)] = [
        ("house.fill",          "Home"),
        ("person.2.fill",       "Members"),
        ("square.grid.2x2.fill","Groups"),
        ("clock.fill",          "History"),
        ("gearshape.fill",      "Settings"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<items.count, id: \.self) { i in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = i
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: items[i].icon)
                            .font(.system(size: selectedTab == i ? 22 : 20))
                            .scaleEffect(selectedTab == i ? 1.1 : 1.0)
                            .foregroundColor(selectedTab == i
                                ? Color(hex: "#A78BFA")!
                                : Color.white.opacity(0.4))
                        Text(items[i].label)
                            .font(.system(size: 10, weight: selectedTab == i ? .semibold : .regular))
                            .foregroundColor(selectedTab == i
                                ? Color(hex: "#A78BFA")!
                                : Color.white.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, bottomSafeArea())
        .background(
            ZStack {
                Color(hex: "#0F0C29")!.opacity(0.95)
                Color.white.opacity(0.04)
            }
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 0.5)
        }
    }

    private func bottomSafeArea() -> CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?
            .safeAreaInsets.bottom ?? 0
    }
}
