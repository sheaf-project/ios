import SwiftUI

/// Page 1 — who is fronting right now
struct WatchHomeView: View {
    @EnvironmentObject var store: WatchStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    Text("Fronting")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Spacer()
                    Button { store.loadAll() } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                            .foregroundColor(.purple)
                    }
                    .buttonStyle(.plain)
                }

                if store.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)

                } else if store.frontingMembers.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                        Text("No one fronting")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)

                } else {
                    ForEach(store.frontingMembers) { member in
                        WatchMemberTile(member: member, showFrontingDot: true)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await removeFromFront(member: member) }
                                } label: {
                                    Label("Remove", systemImage: "person.fill.xmark")
                                }
                            }
                    }

                    if let since = store.oldestCurrentFront?.startedAt {
                        Text("Since \(since.formatted(date: .omitted, time: .shortened))")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                    }
                }
            }
            .padding()
        }
    }

    private func removeFromFront(member: Member) async {
        let remaining = store.frontingMembers
            .filter { $0.id != member.id }
            .map { $0.id }
        await store.switchFronting(to: remaining)
    }
}
