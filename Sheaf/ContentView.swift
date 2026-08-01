import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var systemStore: SystemStore
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            if systemStore.isSyncing {
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
                PollsView()
                    .tag(4)
                    .tabItem {
                        Label("Polls", systemImage: "chart.bar.xaxis")
                    }
            }
            .tint(theme.accentLight)
            .modifier(QuickSwitchAccessoryModifier(isHomeTab: selectedTab == 0))
        }
    }

    // MARK: - Private

    @Binding var selectedTab: Int
}

// MARK: - Quick Switch Tab Bar Accessory

struct QuickSwitchAccessoryModifier: ViewModifier {
    @AppStorage("quickSwitchPosition") private var quickSwitchPosition: QuickSwitchPosition = .belowFronters
    @EnvironmentObject var store: SystemStore
    // Lives here rather than in the accessory view because the system
    // recreates the accessory when the tab bar layout changes, which
    // would reset any state held inside it mid-presentation.
    @State private var showSwitchSheet = false
    let isHomeTab: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.1, *) {
            content
                .tabViewBottomAccessory(isEnabled: isHomeTab && quickSwitchPosition == .mergedWithTabBar) {
                    QuickSwitchAccessoryView(showSwitchSheet: $showSwitchSheet)
                }
                .sheet(isPresented: $showSwitchSheet) {
                    SwitchFrontingSheet()
                        .environmentObject(store)
                }
        } else {
            content
        }
    }
}

@available(iOS 26.1, *)
struct QuickSwitchAccessoryView: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    @Environment(\.tabViewBottomAccessoryPlacement) var placement
    @Binding var showSwitchSheet: Bool

    var body: some View {
        Group {
            if placement == .inline {
                Button {
                    showSwitchSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.footnote)
                        Text("Quick Switch")
                            .font(.subheadline).fontWeight(.medium)
                    }
                    .foregroundColor(theme.textPrimary)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(store.membersByFrontFrequency.filter { !$0.isArchived }.prefix(8)) { member in
                            Button {
                                Task { await store.switchFronting(to: [member.id]) }
                            } label: {
                                AvatarView(member: member, size: 36)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Switch to \(member.displayName ?? member.name)")
                        }
                        Button {
                            showSwitchSheet = true
                        } label: {
                            ZStack {
                                Circle()
                                    .stroke(theme.inputBorder, style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "plus")
                                    .font(.footnote)
                                    .foregroundColor(theme.textSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("More members")
                    }
                    .padding(.horizontal, 14)
                }
            }
        }
    }
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
