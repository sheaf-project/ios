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
                Text("Switch")
                    .font(.system(size: 16, weight: .bold, design: .rounded))

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

                Divider()

                // Confirm button
                if didSwitch {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Switched!")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.green)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 4)
                } else {
                    Button {
                        Task { await confirmSwitch() }
                    } label: {
                        if isSwitching {
                            ProgressView()
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            Text(selectedIDs.isEmpty
                                 ? String(localized: "Clear Front")
                                 : String(localized: "Switch (\(selectedIDs.count))"))
                                .font(.system(size: 13, weight: .semibold))
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(selectedIDs.isEmpty ? .gray : .purple)
                    .disabled(isSwitching)
                }
            }
            .padding()
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
