import SwiftUI

// MARK: - Sessions View
struct SessionsView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var store: SystemStore

    @State private var sessions: [SessionRead] = []
    @State private var isLoading = true
    @State private var showRevokeAllConfirm = false
    @State private var renameSessionId: String?
    @State private var renameText = ""
    @State private var showRenameAlert = false

    var body: some View {
        ZStack {
            theme.backgroundPrimary.ignoresSafeArea()

            if isLoading {
                ProgressView().tint(theme.accentLight)
            } else if sessions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "desktopcomputer")
                        .font(.largeTitle)
                        .foregroundColor(theme.textTertiary)
                    Text("No Sessions")
                        .font(.body).fontWeight(.semibold).fontDesign(.rounded)
                        .foregroundColor(theme.textSecondary)
                }
            } else {
                List {
                    ForEach(sessions) { session in
                        sessionRow(session)
                            .listRowBackground(theme.backgroundPrimary)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 5, leading: 24, bottom: 5, trailing: 24))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if !session.isCurrent {
                                    Button(role: .destructive) {
                                        Task { await revoke(session) }
                                    } label: {
                                        Label("Revoke", systemImage: "xmark.circle")
                                    }
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable { await load() }
            }
        }
        .navigationTitle("Sessions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(role: .destructive) {
                        showRevokeAllConfirm = true
                    } label: {
                        Label("Revoke All Others", systemImage: "xmark.shield")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundColor(theme.accentLight)
                }
            }
        }
        .confirmationDialog("Revoke All Other Sessions?", isPresented: $showRevokeAllConfirm, titleVisibility: .visible) {
            Button("Revoke All Others", role: .destructive) {
                Task { await revokeAllOthers() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will immediately sign out all other devices. Your current session will not be affected.")
        }
        .alert("Rename Session", isPresented: $showRenameAlert) {
            TextField("Nickname", text: $renameText)
            Button("Save") {
                if let id = renameSessionId {
                    Task { await rename(id: id, nickname: renameText) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Give this session a name to identify it.")
        }
        .task { await load() }
    }

    private func sessionRow(_ session: SessionRead) -> some View {
        Button {
            renameSessionId = session.id
            renameText = session.nickname ?? ""
            showRenameAlert = true
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: iconForSession(session))
                        .font(.callout)
                        .foregroundColor(session.isCurrent ? theme.success : theme.accentLight)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(session.nickname ?? session.clientName ?? "Unknown Client")
                                .font(.subheadline).fontWeight(.medium)
                                .foregroundColor(theme.textPrimary)
                                .lineLimit(1)
                            if session.isCurrent {
                                Text("Current")
                                    .font(.caption2).fontWeight(.bold)
                                    .foregroundColor(theme.success)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(theme.success.opacity(0.15))
                                    .cornerRadius(4)
                            }
                        }
                        if let ip = session.lastActiveIp ?? session.createdIp {
                            Text(ip)
                                .font(.caption)
                                .foregroundColor(theme.textTertiary)
                        }
                    }

                    Spacer()
                }

                HStack(spacing: 16) {
                    if let lastActive = session.lastActiveAt {
                        Text("Active \(lastActive, style: .relative) ago")
                            .font(.caption2)
                            .foregroundColor(theme.textTertiary)
                    } else {
                        Text("Never active")
                            .font(.caption2)
                            .foregroundColor(theme.textTertiary)
                    }
                    Spacer()
                    Text("Created \(session.createdAt, style: .date)")
                        .font(.caption2)
                        .foregroundColor(theme.textTertiary)
                }
                .padding(.leading, 32)
            }
            .padding(14)
            .background(theme.backgroundCard)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(session.isCurrent ? theme.success.opacity(0.4) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func iconForSession(_ session: SessionRead) -> String {
        let client = (session.clientName ?? session.userAgent ?? "").lowercased()
        if client.contains("ios") || client.contains("iphone") { return "iphone" }
        if client.contains("watch") { return "applewatch" }
        if client.contains("android") { return "phone" }
        if client.contains("safari") || client.contains("firefox") || client.contains("chrome") || client.contains("edge") { return "globe" }
        return "desktopcomputer"
    }

    private func load() async {
        guard let api = store.api else { return }
        do {
            let loaded = try await api.listSessions()
            await MainActor.run {
                // Sort: current session first, then by last active descending
                sessions = loaded.sorted {
                    if $0.isCurrent != $1.isCurrent { return $0.isCurrent }
                    return ($0.lastActiveAt ?? $0.createdAt) > ($1.lastActiveAt ?? $1.createdAt)
                }
                isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }

    private func revoke(_ session: SessionRead) async {
        guard let api = store.api else { return }
        do {
            try await api.revokeSession(id: session.id)
            await MainActor.run {
                withAnimation { sessions.removeAll { $0.id == session.id } }
            }
        } catch { /* silently fail — user can pull to refresh */ }
    }

    private func revokeAllOthers() async {
        guard let api = store.api else { return }
        do {
            try await api.revokeOtherSessions()
            await MainActor.run {
                withAnimation { sessions.removeAll { !$0.isCurrent } }
            }
        } catch { /* silently fail */ }
    }

    private func rename(id: String, nickname: String) async {
        guard let api = store.api else { return }
        do {
            let updated = try await api.renameSession(id: id, nickname: nickname)
            await MainActor.run {
                if let i = sessions.firstIndex(where: { $0.id == id }) {
                    sessions[i] = updated
                }
            }
        } catch { /* silently fail */ }
    }
}
