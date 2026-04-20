import SwiftUI

/// Sheet shown when tapping "Add to Front" home screen quick action.
/// Shows members sorted by front frequency for fast switching.
struct QuickSwitchFrontSheet: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss

    @State private var selectedIDs: Set<String> = []
    @State private var isSwitching = false
    @State private var searchText = ""

    private var filteredFrontingMembers: [Member] {
        if searchText.isEmpty { return store.frontingMembers }
        return store.frontingMembers.filter {
            ($0.displayName ?? $0.name).localizedCaseInsensitiveContains(searchText)
        }
    }

    var sortedMembers: [Member] {
        let members = store.membersByFrontFrequency
        if searchText.isEmpty { return members }
        return members.filter {
            ($0.displayName ?? $0.name).localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Currently fronting section
                if !filteredFrontingMembers.isEmpty {
                    Section("Currently Fronting") {
                        ForEach(filteredFrontingMembers) { member in
                            memberRow(member, alreadyFronting: true)
                        }
                    }
                }

                // All members sorted by frequency
                Section(store.frontingMembers.isEmpty ? "Select Members" : "Add More") {
                    ForEach(sortedMembers.filter { m in
                        !store.frontingMembers.contains(where: { $0.id == m.id })
                    }) { member in
                        memberRow(member, alreadyFronting: false)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Switch Front")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search members")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(theme.accentLight)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await confirmSwitch() }
                    } label: {
                        if isSwitching {
                            ProgressView().tint(theme.accentLight)
                        } else {
                            Text("Switch")
                                .fontWeight(.semibold)
                                .foregroundColor(selectedIDs.isEmpty
                                    ? theme.textTertiary : theme.accentLight)
                        }
                    }
                    .disabled(selectedIDs.isEmpty || isSwitching)
                }
            }
        }
        .onAppear {
            // Pre-select current fronters
            selectedIDs = Set(store.frontingMembers.map { $0.id })
            // Make sure we have history for frequency sort
            Task {
                if store.frontHistory.isEmpty {
                    await store.loadFrontHistory()
                }
            }
        }
    }

    private func memberRow(_ member: Member, alreadyFronting: Bool) -> some View {
        Button {
            if selectedIDs.contains(member.id) {
                selectedIDs.remove(member.id)
            } else {
                selectedIDs.insert(member.id)
            }
        } label: {
            HStack(spacing: 12) {
                AvatarView(member: member, size: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(member.displayName ?? member.name)
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundColor(theme.textPrimary)
                    if let pronouns = member.pronouns, !pronouns.isEmpty {
                        Text(pronouns)
                            .font(.caption)
                            .foregroundColor(theme.textSecondary)
                    }
                }

                Spacer()

                // Frequency hint
                if !store.frontHistory.isEmpty {
                    let count = store.frontHistory.filter { $0.memberIDs.contains(member.id) }.count
                    if count > 0 {
                        Text("\(count)×")
                            .font(.caption2)
                            .foregroundColor(theme.textTertiary)
                    }
                }

                Image(systemName: selectedIDs.contains(member.id)
                      ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selectedIDs.contains(member.id)
                        ? theme.accentLight : theme.textTertiary)
                    .font(.title3)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func confirmSwitch() async {
        isSwitching = true
        await store.switchFronting(to: Array(selectedIDs))
        isSwitching = false
        dismiss()
    }
}
