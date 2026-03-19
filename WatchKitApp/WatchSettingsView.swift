import SwiftUI

struct WatchSettingsView: View {
    @EnvironmentObject var authManager: WatchAuthManager
    @EnvironmentObject var store: WatchStore
    @State private var showLogoutConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Settings")
                    .font(.system(size: 16, weight: .bold, design: .rounded))

                // Info rows
                infoRow(icon: "link", label: "URL", value: shortURL)
                infoRow(icon: "person.2.fill", label: "Members", value: "\(store.members.count)")
                infoRow(icon: "arrow.left.arrow.right", label: "Fronting", value: "\(store.frontingMembers.count)")

                Divider()

                Button {
                    Task { await store.loadAll() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.system(size: 13))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .foregroundColor(.purple)

                Button {
                    showLogoutConfirm = true
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 13))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
            }
            .padding()
        }
        .confirmationDialog("Sign out?", isPresented: $showLogoutConfirm) {
            Button("Sign Out", role: .destructive) { authManager.logout() }
            Button("Cancel", role: .cancel) {}
        }
    }

    var shortURL: String {
        authManager.baseURL
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
    }

    func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 16)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
