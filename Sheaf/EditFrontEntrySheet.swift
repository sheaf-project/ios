import SwiftUI

struct EditFrontEntrySheet: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss

    let entry: FrontEntry

    @State private var selectedIDs: Set<String> = []
    @State private var endedAt: Date = Date()
    @State private var isOngoing = false
    @State private var customStatus = ""
    @State private var isSaving = false
    @State private var showAllMembers = false

    var body: some View {
        NavigationStack {
            Form {
                // Member selection
                Section("Who was fronting") {
                    let allMembers = store.membersByFrontFrequency
                    let visibleMembers = showAllMembers ? allMembers : Array(allMembers.prefix(5))

                    ForEach(visibleMembers) { member in
                        Button {
                            if selectedIDs.contains(member.id) {
                                selectedIDs.remove(member.id)
                            } else {
                                selectedIDs.insert(member.id)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                AvatarView(member: member, size: 36)
                                Text(member.displayName ?? member.name)
                                    .foregroundColor(theme.textPrimary)
                                Spacer()
                                Image(systemName: selectedIDs.contains(member.id)
                                      ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedIDs.contains(member.id)
                                        ? theme.accentLight : theme.textTertiary)
                                    .font(.title3)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    if allMembers.count > 5 {
                        Button {
                            withAnimation { showAllMembers.toggle() }
                        } label: {
                            HStack {
                                Text(showAllMembers
                                     ? "Show less"
                                     : "Show \(allMembers.count - 5) more…")
                                    .font(.subheadline)
                                    .foregroundColor(theme.accentLight)
                                Spacer()
                                Image(systemName: showAllMembers ? "chevron.up" : "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(theme.accentLight)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Custom status
                Section("Status") {
                    TextField("Custom status (optional)", text: $customStatus)
                }

                // Time range
                Section("When") {
                    HStack {
                        Text("Started")
                            .foregroundColor(theme.textPrimary)
                        Spacer()
                        Text(entry.startedAt.formatted(date: .abbreviated, time: .shortened))
                            .foregroundColor(theme.textSecondary)
                    }

                    Toggle("Still ongoing", isOn: $isOngoing)
                        .tint(theme.accentLight)

                    if !isOngoing {
                        DatePicker("Ended", selection: $endedAt,
                                   in: entry.startedAt...,
                                   displayedComponents: [.date, .hourAndMinute])
                            .foregroundColor(theme.textPrimary)
                    }
                }


            }
            .scrollContentBackground(.hidden)
            .background(theme.backgroundPrimary)
            .navigationTitle("Edit Front Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(theme.accentLight)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView().tint(theme.accentLight)
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                                .foregroundColor(selectedIDs.isEmpty
                                    ? theme.textTertiary : theme.accentLight)
                        }
                    }
                    .disabled(selectedIDs.isEmpty || isSaving)
                }
            }
            .onAppear {
                selectedIDs = Set(entry.memberIDs)
                isOngoing = entry.endedAt == nil
                endedAt = entry.endedAt ?? Date()
                customStatus = entry.customStatus ?? ""
            }
        }
    }

    private func save() async {
        guard !selectedIDs.isEmpty else { return }
        isSaving = true
        let update = FrontUpdate(
            endedAt: isOngoing ? nil : endedAt,
            memberIDs: Array(selectedIDs),
            customStatus: customStatus
        )
        await store.updateFront(id: entry.id, update: update)
        isSaving = false
        dismiss()
    }
}
