import SwiftUI

struct AddFrontEntrySheet: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss

    @State private var selectedIDs: Set<String> = []
    @State private var startedAt: Date = Date().addingTimeInterval(-3600)
    @State private var endedAt: Date = Date()
    @State private var isOngoing = false
    @State private var isSaving = false
    @State private var error: String?
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
                        .listRowBackground(theme.backgroundCard)
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
                        .listRowBackground(theme.backgroundCard)
                    }
                }

                // Time range
                Section("When") {
                    DatePicker("Started", selection: $startedAt, displayedComponents: [.date, .hourAndMinute])
                        .foregroundColor(theme.textPrimary)
                        .listRowBackground(theme.backgroundCard)
                        .onChange(of: startedAt) { _, new in
                            if endedAt < new { endedAt = new.addingTimeInterval(3600) }
                        }

                    Toggle("Still ongoing", isOn: $isOngoing)
                        .tint(theme.accentLight)
                        .listRowBackground(theme.backgroundCard)

                    if !isOngoing {
                        DatePicker("Ended", selection: $endedAt,
                                   in: startedAt...,
                                   displayedComponents: [.date, .hourAndMinute])
                            .foregroundColor(theme.textPrimary)
                            .listRowBackground(theme.backgroundCard)
                    }
                }

                if let error {
                    Section {
                        Text(error)
                            .foregroundColor(theme.danger)
                            .font(.footnote)
                    }
                    .listRowBackground(theme.backgroundCard)
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.backgroundPrimary)
            .navigationTitle("Add Front Entry")
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
                            Text("Add")
                                .fontWeight(.semibold)
                                .foregroundColor(selectedIDs.isEmpty
                                    ? theme.textTertiary : theme.accentLight)
                        }
                    }
                    .disabled(selectedIDs.isEmpty || isSaving)
                }
            }
        }
    }

    private func save() async {
        guard !selectedIDs.isEmpty else { return }
        guard endedAt > startedAt || isOngoing else {
            error = "End time must be after start time."
            return
        }
        isSaving = true
        error = nil
        do {
            try await store.addFrontEntry(
                memberIDs: Array(selectedIDs),
                startedAt: startedAt,
                endedAt: isOngoing ? nil : endedAt
            )
            isSaving = false
            dismiss()
        } catch is CancellationError {
            isSaving = false
        } catch {
            self.error = error.localizedDescription
            isSaving = false
        }
    }
}
