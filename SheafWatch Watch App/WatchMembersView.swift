import SwiftUI

// MARK: - Members list page
struct WatchMembersView: View {
    @EnvironmentObject var store: WatchStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Members")
                    .font(.system(size: 16, weight: .bold, design: .rounded))

                if store.isLoading && store.members.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)
                } else if store.members.isEmpty {
                    Text("No members")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                } else {
                    ForEach(store.members) { member in
                        WatchMemberTile(
                            member: member,
                            showFrontingDot: store.frontingMembers.contains(where: { $0.id == member.id })
                        )
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Reusable member tile
struct WatchMemberTile: View {
    let member: Member
    let showFrontingDot: Bool

    var body: some View {
        HStack(spacing: 10) {
            AvatarView(member: member, size: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(member.displayName ?? member.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                if let pronouns = member.pronouns, !pronouns.isEmpty {
                    Text(pronouns)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if showFrontingDot {
                Circle()
                    .fill(Color.green)
                    .frame(width: 7, height: 7)
            }
        }
        .padding(.vertical, 4)
    }
}
