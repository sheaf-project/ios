import SwiftUI

struct AddFrontEntrySheet: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss

    @State private var selectedIDs: Set<String> = []
    @State private var startedAt: Date = Date().addingTimeInterval(-3600)
    @State private var endedAt: Date = Date()
    @State private var isOngoing = false
    @State private var customStatus = ""
    @State private var isSaving = false
    @State private var error: String?
    @State private var showAllMembers = false
    @State private var openFronts: [FrontEntry] = []

    // An entry left open is a switch, so the server ends every open front at
    // its start. One that began after that start cannot be ended there and
    // the request fails with a 500, so the sheet checks first. Equal
    // timestamps pass: a zero-length front is allowed.
    private var clashes: [FrontEntry] {
        guard isOngoing, store.systemProfile?.replaceFrontsDefault ?? true else { return [] }
        return openFronts.filter { $0.endedAt == nil && $0.startedAt > startedAt }
    }

    private var clashMessage: String {
        var names = [String]()
        for id in clashes.flatMap(\.memberIDs) {
            guard let m = store.members.first(where: { $0.id == id }) else { continue }
            let n = m.displayName ?? m.name
            if !names.contains(n) { names.append(n) }
        }
        if names.isEmpty { names = [String(localized: "whoever is fronting")] }
        let who = names.joined(separator: ", ")
        let verb = names.count == 1 ? String(localized: "has been fronting") : String(localized: "have been fronting")
        var text = String(localized: "An entry left open starts a front, which ends the ones already running. ")
        text += "\(who) \(verb)"
        if let earliest = clashes.map(\.startedAt).min() {
            text += " " + String(localized: "since \(earliest.formatted(date: .abbreviated, time: .shortened))")
        }
        text += String(localized: ", which is after this start, so it can't be ended there. Pick a later start, or give this entry an end time to record it as history instead.")
        return text
    }

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
                                HStack(spacing: 4) {
                                    Text(member.displayName ?? member.name)
                                        .foregroundColor(theme.textPrimary)
                                    if let emoji = member.emoji, !emoji.isEmpty {
                                        Text(emoji).font(.caption)
                                    }
                                }
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

                // Custom status
                Section("Status") {
                    TextField("Custom status (optional)", text: $customStatus)
                        .foregroundColor(theme.textPrimary)
                        .listRowBackground(theme.backgroundCard)
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

                    if !clashes.isEmpty {
                        Text(clashMessage)
                            .font(.footnote)
                            .foregroundColor(theme.danger)
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
                                .foregroundColor(selectedIDs.isEmpty || !clashes.isEmpty
                                    ? theme.textTertiary : theme.accentLight)
                        }
                    }
                    .disabled(selectedIDs.isEmpty || isSaving || !clashes.isEmpty)
                }
            }
            .task {
                // The history page is paginated, so an open front is only
                // probably on it; ask for the live roster instead.
                openFronts = store.currentFronts
                if let api = store.api, let fresh = try? await api.getCurrentFronts() {
                    openFronts = fresh
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
                endedAt: isOngoing ? nil : endedAt,
                customStatus: customStatus.isEmpty ? nil : customStatus
            )
            isSaving = false
            dismiss()
        } catch is CancellationError {
            isSaving = false
        } catch {
            self.error = error.userFacingMessage
            isSaving = false
        }
    }
}
