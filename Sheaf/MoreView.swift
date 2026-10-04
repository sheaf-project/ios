import SwiftUI

struct MoreView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var store: SystemStore
    @State private var showSharing = false

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

                        VStack(spacing: 0) {
                            NavigationLink {
                                PollsView()
                                    .environmentObject(store)
                            } label: {
                                row(icon: "chart.bar.xaxis", title: "Polls")
                            }
                            .buttonStyle(.plain)

                            Divider().background(theme.divider)

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
                        .background(theme.backgroundCard)
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.backgroundCard, lineWidth: 1))
                        .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 24)
                }
            }
            .task { await loadSharingGate() }
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
