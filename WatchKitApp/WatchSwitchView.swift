import SwiftUI

// MARK: - Switch fronting page
struct WatchSwitchView: View {
    @EnvironmentObject var store: WatchStore
    @State private var selectedIDs: Set<String> = []
    @State private var isSwitching = false
    @State private var didSwitch   = false
    @State private var searchText  = ""

    private var filteredMembers: [Member] {
        if searchText.isEmpty { return store.members }
        return store.members.filter {
            ($0.displayName ?? $0.name).localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            // Member checkboxes
            ForEach(filteredMembers) { member in
                    Button {
                        if selectedIDs.contains(member.id) {
                            selectedIDs.remove(member.id)
                        } else {
                            selectedIDs.insert(member.id)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            AvatarView(member: member, size: 28)

                            HStack(spacing: 3) {
                                Text(member.displayName ?? member.name)
                                    .font(.footnote)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                if let emoji = member.emoji, !emoji.isEmpty {
                                    Text(emoji).font(.caption2)
                                }
                            }

                            Spacer()

                            Image(systemName: selectedIDs.contains(member.id)
                                  ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedIDs.contains(member.id)
                                    ? .purple : .secondary)
                                .font(.title3)
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
            }
        }
        .navigationTitle("Switch")
        .searchable(text: $searchText, prompt: "Search members")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if didSwitch {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Button {
                        Task { await confirmSwitch() }
                    } label: {
                        if isSwitching {
                            ProgressView()
                        } else {
                            Image(systemName: selectedIDs.isEmpty
                                  ? "xmark.circle" : "checkmark.circle")
                        }
                    }
                    .disabled(isSwitching)
                }
            }
        }
        .onAppear {
            store.loadAll()
            // Pre-select currently fronting members
            selectedIDs = Set(store.frontingMembers.map { $0.id })
        }
    }

    private func confirmSwitch() async {
        isSwitching = true
        await store.switchFronting(to: Array(selectedIDs))
        await MainActor.run {
            isSwitching = false
            didSwitch   = true
        }
        // Reset after 2s so the page is ready for another switch
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        await MainActor.run { didSwitch = false }
    }
}
