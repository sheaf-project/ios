import SwiftUI

/// Page 1 — who is fronting right now
struct WatchHomeView: View {
    @EnvironmentObject var store: WatchStore

    var body: some View {
        List {
            Section {
                if store.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
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
                    .padding(.vertical, 8)
                } else {
                    ForEach(store.frontingMembers) { member in
                        WatchMemberTile(member: member, showFrontingDot: true)
                            .contextMenu {
                                Button {
                                    Task { await removeFromFront(member: member) }
                                } label: {
                                    Label("Remove from Front", systemImage: "person.fill.xmark")
                                }
                                Button {
                                    Task { await store.switchFronting(to: [member.id]) }
                                } label: {
                                    Label("Switch to only \(member.displayName ?? member.name)", systemImage: "arrow.left.arrow.right")
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await removeFromFront(member: member) }
                                } label: {
                                    Label("Remove", systemImage: "person.fill.xmark")
                                }
                            }
                    }
                }
            } header: {
                HStack {
                    Text("Fronting")
                    Spacer()
                    Button { store.loadAll() } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.purple)
                }
            } footer: {
                if let since = store.oldestCurrentFront?.startedAt {
                    Text("Since \(since.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear { store.loadAll() }
    }

    private func removeFromFront(member: Member) async {
        let remaining = store.frontingMembers
            .filter { $0.id != member.id }
            .map { $0.id }
        await store.switchFronting(to: remaining)
    }
}
