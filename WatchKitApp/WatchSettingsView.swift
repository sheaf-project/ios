import SwiftUI

struct WatchSettingsView: View {
    @EnvironmentObject var authManager: WatchAuthManager
    @EnvironmentObject var store: WatchStore
    @State private var showLogoutConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Settings")
                    .font(.headline)
                    .fontDesign(.rounded)

                // Info rows
                infoRow(icon: "link", label: String(localized: "URL"), value: shortURL)
                infoRow(icon: "person.2.fill", label: String(localized: "Members"), value: "\(store.members.count)")
                infoRow(icon: "arrow.left.arrow.right", label: String(localized: "Fronting"), value: "\(store.frontingMembers.count)")

                Divider()

                Button {
                    Task { await store.loadAll() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.footnote)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)

                Button {
                    showLogoutConfirm = true
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.footnote)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
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
                .font(.caption2)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption2)
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
