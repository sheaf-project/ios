import SwiftUI

// MARK: - Switch fronting page
struct WatchSwitchView: View {
    @EnvironmentObject var store: WatchStore
    @State private var selectedIDs: Set<String> = []
    @State private var isSwitching = false
    @State private var didSwitch   = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Select who is fronting")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                // Member checkboxes
                ForEach(store.members) { member in
                    Button {
                        if selectedIDs.contains(member.id) {
                            selectedIDs.remove(member.id)
                        } else {
                            selectedIDs.insert(member.id)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            AvatarView(member: member, size: 28)

                            Text(member.displayName ?? member.name)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.primary)
                                .lineLimit(1)

                            Spacer()

                            Image(systemName: selectedIDs.contains(member.id)
                                  ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedIDs.contains(member.id)
                                    ? .purple : .secondary)
                                .font(.system(size: 16))
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle("Switch")
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
