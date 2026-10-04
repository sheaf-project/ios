import SwiftUI

struct MoreView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var store: SystemStore
    @EnvironmentObject var authManager: AuthManager
    @State private var showSharing = false
    @State private var showAnalytics = false
    @State private var showMessages = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        Text("More")
                            .font(.title2).fontWeight(.bold).fontDesign(.rounded)
                            .foregroundColor(theme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                            .padding(.top, 16)

                        section("Tracking") {
                            Button { showAnalytics = true } label: {
                                row(icon: "chart.xyaxis.line", title: "Analytics")
                            }
                            .buttonStyle(.plain)
                        }

                        section("Writing") {
                            Button { showMessages = true } label: {
                                row(icon: "bubble.left.and.bubble.right.fill", title: "Board Messages")
                            }
                            .buttonStyle(.plain)
                        }

                        section("Engage") {
                            NavigationLink {
                                PollsView()
                                    .environmentObject(store)
                            } label: {
                                row(icon: "chart.bar.xaxis", title: "Polls")
                            }
                            .buttonStyle(.plain)

                            Divider().background(theme.divider)

                            NavigationLink {
                                RemindersView()
                                    .environmentObject(store)
                            } label: {
                                row(icon: "bell.and.waves.left.and.right", title: "Reminders")
                            }
                            .buttonStyle(.plain)
                        }

                        section("System") {
                            NavigationLink {
                                RelationshipTypesView()
                                    .environmentObject(store)
                            } label: {
                                row(icon: "person.line.dotted.person", title: "Relationships")
                            }
                            .buttonStyle(.plain)

                            Divider().background(theme.divider)

                            NavigationLink {
                                FilesView()
                                    .environmentObject(store)
                            } label: {
                                row(icon: "photo.on.rectangle", title: "Files")
                            }
                            .buttonStyle(.plain)

                            if showSharing {
                                Divider().background(theme.divider)

                                NavigationLink {
                                    SharingView()
                                        .environmentObject(store)
                                } label: {
                                    row(icon: "globe", title: "Sharing")
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        section(nil) {
                            NavigationLink {
                                NotificationChannelsView()
                                    .environmentObject(authManager)
                                    .environmentObject(store)
                            } label: {
                                row(icon: "bell.badge.fill", title: "Notifications")
                            }
                            .buttonStyle(.plain)

                            Divider().background(theme.divider)

                            NavigationLink {
                                SupportView()
                                    .environmentObject(authManager)
                                    .environmentObject(store)
                            } label: {
                                row(icon: "questionmark.circle.fill", title: "Support")
                            }
                            .buttonStyle(.plain)

                            Divider().background(theme.divider)

                            Button { showSettings = true } label: {
                                row(icon: "gearshape.fill", title: "Settings")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            .task { await loadSharingGate() }
            .sheet(isPresented: $showAnalytics) {
                AnalyticsView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showMessages) {
                MessageBoardView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(authManager)
                    .environmentObject(store)
            }
        }
    }

    private func section<Content: View>(_ title: LocalizedStringKey?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.caption).fontWeight(.semibold)
                    .foregroundColor(theme.textSecondary)
                    .textCase(.uppercase)
                    .kerning(0.8)
                    .padding(.horizontal, 24)
            }
            VStack(spacing: 0) { content() }
                .background(theme.backgroundCard)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.backgroundCard, lineWidth: 1))
                .padding(.horizontal, 24)
        }
    }

    private func row(icon: String, title: LocalizedStringKey) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(theme.accentLight)
                .frame(width: 20)
            Text(title)
                .font(.subheadline).fontWeight(.medium)
                .foregroundColor(theme.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(theme.textTertiary)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }

    // Sharing must stay reachable while dormant grants exist, even after an
    // operator turns the instance flag off, so revoke is never out of reach.
    private func loadSharingGate() async {
        guard let api = store.api else { return }
        let me = try? await api.getMe()
        if me?.publicProfilesEnabled == true {
            showSharing = true
            return
        }
        let grants = (try? await api.getShareGrants()) ?? []
        showSharing = grants.contains { $0.status != "revoked" }
    }
}
