import SwiftUI

/// Settings > System > Archived Members. Mirrors the web archived-members
/// card and lets the user restore any archived member.
struct ArchivedMembersView: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme

    @State private var unarchivingID: String?
    @State private var errorMessage: String?

    private var archived: [Member] {
        store.members.filter { $0.isArchived }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Archived members are hidden from the roster and from switch and journal pickers, but stay in front history and existing entries. Unarchive one to bring it back.")
                    .font(.footnote)
                    .foregroundColor(theme.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(theme.danger)
                        .padding(.horizontal, 16)
                }

                if archived.isEmpty {
                    Text("No archived members.")
                        .font(.subheadline)
                        .foregroundColor(theme.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                } else {
                    VStack(spacing: 8) {
                        ForEach(archived) { member in
                            HStack(spacing: 12) {
                                AvatarView(member: member, size: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(member.displayName ?? member.name)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(theme.textPrimary)
                                    if let p = member.pronouns, !p.isEmpty {
                                        Text(p)
                                            .font(.caption)
                                            .foregroundColor(theme.textSecondary)
                                    }
                                }
                                Spacer()
                                if unarchivingID == member.id {
                                    ProgressView().tint(theme.accentLight)
                                } else {
                                    Button {
                                        Task { await unarchive(member) }
                                    } label: {
                                        Text("Unarchive")
                                            .font(.caption.weight(.semibold))
                                            .foregroundColor(theme.accentLight)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(12)
                            .background(theme.backgroundCard)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 8)
        }
        .background(theme.backgroundPrimary)
        .navigationTitle("Archived Members")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            store.loadAll()
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
    }

    private func unarchive(_ member: Member) async {
        unarchivingID = member.id
        defer { unarchivingID = nil }
        do {
            _ = try await store.unarchiveMember(id: member.id)
        } catch {
            errorMessage = error.userFacingMessage
        }
    }
}
