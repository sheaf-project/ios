import SwiftUI

// MARK: - Reminders List View

struct RemindersView: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    @State private var isLoading = false
    @State private var showNewReminder = false
    @State private var selectedReminder: Reminder?
    @State private var reminderToDelete: Reminder?
    @State private var showDeleteConfirm = false
    @State private var showDeleteQueued = false
    @State private var deleteQueuedInfo: DeleteQueued?
    @State private var channels: [NotificationChannel] = []

    private var enabledReminders: [Reminder] { store.reminders.filter { $0.enabled } }
    private var disabledReminders: [Reminder] { store.reminders.filter { !$0.enabled } }

    var body: some View {
        ZStack {
            theme.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                if isLoading && store.reminders.isEmpty {
                    Spacer()
                    ProgressView().tint(theme.accentLight)
                    Spacer()
                } else if store.reminders.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "bell.and.waves.left.and.right")
                            .font(.largeTitle)
                            .foregroundColor(theme.textTertiary)
                        Text("No reminders yet")
                            .font(.body).fontWeight(.medium).fontDesign(.rounded)
                            .foregroundColor(theme.textTertiary)
                        Text("Tap + to create your first reminder.")
                            .font(.footnote)
                            .foregroundColor(theme.textTertiary)
                    }
                    Spacer()
                } else {
                    List {
                        if !enabledReminders.isEmpty {
                            Section {
                                ForEach(enabledReminders) { reminder in
                                    reminderRow(reminder)
                                }
                            } header: {
                                Text("Active")
                                    .font(.caption).fontWeight(.semibold)
                                    .foregroundColor(theme.textTertiary)
                                    .textCase(nil)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }

                        if !disabledReminders.isEmpty {
                            Section {
                                ForEach(disabledReminders) { reminder in
                                    reminderRow(reminder)
                                }
                            } header: {
                                Text("Disabled")
                                    .font(.caption).fontWeight(.semibold)
                                    .foregroundColor(theme.textTertiary)
                                    .textCase(nil)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(theme.backgroundPrimary)
                    .refreshable {
                        await reload()
                    }
                }
            }
        }
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        showNewReminder = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(theme.accentLight)
                    }
                    Button {
                        Task { await reload() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundColor(theme.textSecondary)
                    }
                }
            }
        }
        .task { await reload() }
        .sheet(isPresented: $showNewReminder, onDismiss: { Task { await reload() } }) {
            EditReminderSheet(channels: channels)
                .environmentObject(store)
        }
        .sheet(item: $selectedReminder, onDismiss: { Task { await reload() } }) { reminder in
            EditReminderSheet(existing: reminder, channels: channels)
                .environmentObject(store)
        }
        .confirmationDialog("Delete this reminder?", isPresented: $showDeleteConfirm, presenting: reminderToDelete) { reminder in
            Button("Delete", role: .destructive) {
                Task {
                    let queued = await store.deleteReminder(id: reminder.id)
                    if let queued {
                        deleteQueuedInfo = queued
                        showDeleteQueued = true
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("This will permanently delete this reminder.")
        }
        .alert("Deletion Queued", isPresented: $showDeleteQueued) {
            Button("OK", role: .cancel) { deleteQueuedInfo = nil }
        } message: {
            if let info = deleteQueuedInfo {
                Text("This deletion has been queued and will finalize \(info.finalizeAfter, style: .relative). You can cancel it from System Safety settings.")
            }
        }
    }

    @ViewBuilder
    private func reminderRow(_ reminder: Reminder) -> some View {
        Button { selectedReminder = reminder } label: {
            ReminderRowView(reminder: reminder, channelName: channelName(for: reminder.channelID))
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                reminderToDelete = reminder
                showDeleteConfirm = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                Task { await store.toggleReminder(id: reminder.id, enabled: !reminder.enabled) }
            } label: {
                Label(
                    reminder.enabled ? "Disable" : "Enable",
                    systemImage: reminder.enabled ? "bell.slash" : "bell"
                )
            }
            .tint(reminder.enabled ? theme.warning : theme.success)
        }
        .listRowInsets(EdgeInsets(top: 5, leading: 24, bottom: 5, trailing: 24))
    }

    private func channelName(for channelID: String) -> String {
        channels.first(where: { $0.id == channelID })?.name ?? "Unknown channel"
    }

    func reload() async {
        isLoading = true
        await store.loadReminders()
        await loadChannels()
        isLoading = false
    }

    private func loadChannels() async {
        guard let api = store.api, let systemID = store.systemProfile?.id else { return }
        do {
            let tokens = try await api.listWatchTokens(systemID: systemID)
            var all: [NotificationChannel] = []
            for token in tokens where token.revokedAt == nil {
                let ch = try await api.listChannels(watchTokenID: token.id)
                all.append(contentsOf: ch)
            }
            channels = all
        } catch {
            // Non-fatal
        }
    }
}

// MARK: - Reminder Row

struct ReminderRowView: View {
    @Environment(\.theme) var theme
    let reminder: Reminder
    let channelName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(reminder.name)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(reminder.enabled ? theme.textPrimary : theme.textTertiary)
                    .lineLimit(1)
                Spacer()
                Text(reminder.parsedTriggerType.label)
                    .font(.caption2).fontWeight(.medium)
                    .foregroundColor(reminder.parsedTriggerType == .automated ? theme.accentLight : theme.success)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        (reminder.parsedTriggerType == .automated ? theme.accentLight : theme.success)
                            .opacity(0.15)
                    )
                    .cornerRadius(6)
            }

            Text(reminder.title)
                .font(.caption)
                .foregroundColor(theme.textSecondary)
                .lineLimit(1)

            HStack(spacing: 12) {
                Label(reminder.scheduleDescription, systemImage: reminder.parsedTriggerType == .automated ? "bolt.fill" : "clock")
                    .font(.caption2)
                    .foregroundColor(theme.textTertiary)
                    .lineLimit(1)

                Spacer()

                Label(channelName, systemImage: "bell.badge")
                    .font(.caption2)
                    .foregroundColor(theme.textTertiary)
                    .lineLimit(1)
            }

            if !reminder.enabled {
                HStack(spacing: 4) {
                    Image(systemName: "bell.slash.fill")
                        .font(.caption2)
                    Text("Disabled")
                        .font(.caption2).fontWeight(.medium)
                }
                .foregroundColor(theme.textTertiary)
            }
        }
        .padding(14)
        .background(theme.backgroundCard)
        .cornerRadius(14)
    }
}

// MARK: - Edit Reminder Sheet

struct EditReminderSheet: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var store: SystemStore
    @Environment(\.dismiss) var dismiss

    let existing: Reminder?
    let channels: [NotificationChannel]

    @State private var name = ""
    @State private var title = ""
    @State private var bodyText = ""
    @State private var enabled = true
    @State private var channelID = ""

    @State private var triggerType: ReminderTriggerType = .repeated
    @State private var triggerMemberID: String?
    @State private var triggerEvent: ReminderTriggerEvent = .any
    @State private var delayMinutes = 0

    @State private var scheduleKind: ReminderScheduleKind = .daily
    @State private var scheduleTimeHour = 9
    @State private var scheduleTimeMinute = 0
    @State private var scheduleDowMask = 0b0011111 // Mon-Fri
    @State private var scheduleDom = 1
    @State private var useCron = false
    @State private var cronExpression = ""

    @State private var scope: ReminderScope = .system
    @State private var scopeMemberIDs: Set<String> = []
    @State private var digestWhenAbsent = true

    @State private var isSaving = false
    @State private var errorMessage: String?

    private var isEditing: Bool { existing != nil }

    private var activeChannels: [NotificationChannel] {
        channels.filter { $0.destinationState == .active }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !channelID.isEmpty
        && !isSaving
    }

    init(existing: Reminder? = nil, channels: [NotificationChannel]) {
        self.existing = existing
        self.channels = channels
    }

    var body: some View {
        NavigationStack {
            Form {
                basicSection
                triggerSection
                if triggerType == .repeated {
                    scheduleSection
                    scopeSection
                }
                if triggerType == .automated {
                    automatedSection
                }
                channelSection

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .listRowBackground(Color.clear)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.backgroundPrimary)
            .navigationTitle(isEditing ? "Edit Reminder" : "New Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(theme.accentLight)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: save) {
                        if isSaving { ProgressView().tint(theme.accentLight) }
                        else {
                            Text(isEditing ? "Save" : "Create")
                                .fontWeight(.semibold)
                                .foregroundColor(canSave ? theme.accentLight : theme.textTertiary)
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear { loadExisting() }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var basicSection: some View {
        Section("Details") {
            TextField("Name", text: $name)
                .foregroundColor(theme.textPrimary)
                .listRowBackground(theme.backgroundCard)
            TextField("Notification title", text: $title)
                .foregroundColor(theme.textPrimary)
                .listRowBackground(theme.backgroundCard)
            TextField("Notification body (optional)", text: $bodyText, axis: .vertical)
                .lineLimit(2...4)
                .foregroundColor(theme.textPrimary)
                .listRowBackground(theme.backgroundCard)
            Toggle("Enabled", isOn: $enabled)
                .tint(theme.accentLight)
                .listRowBackground(theme.backgroundCard)
        }
    }

    @ViewBuilder
    private var triggerSection: some View {
        Section("Trigger Type") {
            Picker("Type", selection: $triggerType) {
                ForEach(ReminderTriggerType.allCases, id: \.self) { t in
                    Text(t.label).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(theme.backgroundCard)

            if triggerType == .automated {
                Text("Sends a notification when a fronting change happens.")
                    .font(.caption)
                    .foregroundColor(theme.textTertiary)
                    .listRowBackground(theme.backgroundCard)
            } else {
                Text("Sends notifications on a recurring schedule.")
                    .font(.caption)
                    .foregroundColor(theme.textTertiary)
                    .listRowBackground(theme.backgroundCard)
            }
        }
    }

    @ViewBuilder
    private var automatedSection: some View {
        Section("Automated Trigger") {
            Picker("Event", selection: $triggerEvent) {
                ForEach(ReminderTriggerEvent.allCases, id: \.self) { e in
                    Text(e.label).tag(e)
                }
            }
            .listRowBackground(theme.backgroundCard)

            Picker("Member", selection: $triggerMemberID) {
                Text("Any member").tag(nil as String?)
                ForEach(store.members) { member in
                    Text(member.displayName ?? member.name).tag(member.id as String?)
                }
            }
            .listRowBackground(theme.backgroundCard)

            Stepper("Delay: \(delayMinutes) min", value: $delayMinutes, in: 0...10080)
                .listRowBackground(theme.backgroundCard)
        }
    }

    @ViewBuilder
    private var scheduleSection: some View {
        Section("Schedule") {
            Toggle("Use cron expression", isOn: $useCron)
                .tint(theme.accentLight)
                .listRowBackground(theme.backgroundCard)

            if useCron {
                TextField("Cron expression", text: $cronExpression)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(theme.textPrimary)
                    .listRowBackground(theme.backgroundCard)
            } else {
                Picker("Frequency", selection: $scheduleKind) {
                    ForEach(ReminderScheduleKind.allCases, id: \.self) { k in
                        Text(k.label).tag(k)
                    }
                }
                .listRowBackground(theme.backgroundCard)

                HStack {
                    Text("Time")
                    Spacer()
                    Picker("Hour", selection: $scheduleTimeHour) {
                        ForEach(0..<24, id: \.self) { h in
                            Text(String(format: "%02d", h)).tag(h)
                        }
                    }
                    .pickerStyle(.menu)
                    Text(":")
                    Picker("Minute", selection: $scheduleTimeMinute) {
                        ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { m in
                            Text(String(format: "%02d", m)).tag(m)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .listRowBackground(theme.backgroundCard)

                if scheduleKind == .weekly {
                    dowPicker
                }

                if scheduleKind == .monthly {
                    Stepper("Day of month: \(scheduleDom)", value: $scheduleDom, in: 1...31)
                        .listRowBackground(theme.backgroundCard)
                }
            }
        }
    }

    @ViewBuilder
    private var dowPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Days of week")
                .font(.subheadline)
                .foregroundColor(theme.textPrimary)
            HStack(spacing: 6) {
                ForEach(Array(zip(0..<7, ["M", "T", "W", "T", "F", "S", "S"])), id: \.0) { idx, label in
                    let isSelected = scheduleDowMask & (1 << idx) != 0
                    Button {
                        scheduleDowMask ^= (1 << idx)
                    } label: {
                        Text(label)
                            .font(.caption).fontWeight(.semibold)
                            .frame(width: 32, height: 32)
                            .background(isSelected ? theme.accentLight : theme.backgroundCard)
                            .foregroundColor(isSelected ? .white : theme.textSecondary)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listRowBackground(theme.backgroundCard)
    }

    @ViewBuilder
    private var scopeSection: some View {
        Section("Scope") {
            Picker("Scope", selection: $scope) {
                ForEach(ReminderScope.allCases, id: \.self) { s in
                    Text(s.label).tag(s)
                }
            }
            .listRowBackground(theme.backgroundCard)

            if scope == .member {
                ForEach(store.members) { member in
                    let isSelected = scopeMemberIDs.contains(member.id)
                    Button {
                        if isSelected {
                            scopeMemberIDs.remove(member.id)
                        } else {
                            scopeMemberIDs.insert(member.id)
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(member.displayColor)
                                .frame(width: 8, height: 8)
                            Text(member.displayName ?? member.name)
                                .font(.subheadline)
                                .foregroundColor(theme.textPrimary)
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .foregroundColor(theme.accentLight)
                                    .font(.subheadline)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(theme.backgroundCard)
                }

                Toggle("Queue when absent", isOn: $digestWhenAbsent)
                    .tint(theme.accentLight)
                    .listRowBackground(theme.backgroundCard)

                Text("When enabled, missed reminders are queued and sent as a digest when a scoped member starts fronting.")
                    .font(.caption)
                    .foregroundColor(theme.textTertiary)
                    .listRowBackground(theme.backgroundCard)
            }
        }
    }

    @ViewBuilder
    private var channelSection: some View {
        Section("Notification Channel") {
            if activeChannels.isEmpty {
                Text("No active notification channels. Create one in Notification Channels settings first.")
                    .font(.caption)
                    .foregroundColor(theme.textTertiary)
                    .listRowBackground(theme.backgroundCard)
            } else {
                Picker("Channel", selection: $channelID) {
                    Text("Select a channel").tag("")
                    ForEach(activeChannels) { channel in
                        HStack {
                            Image(systemName: channel.destinationType.icon)
                            Text(channel.name)
                        }
                        .tag(channel.id)
                    }
                }
                .listRowBackground(theme.backgroundCard)
            }
        }
    }

    // MARK: - Load Existing

    private func loadExisting() {
        guard let r = existing else {
            if let first = activeChannels.first {
                channelID = first.id
            }
            return
        }

        name = r.name
        title = r.title
        bodyText = r.body ?? ""
        enabled = r.enabled
        channelID = r.channelID
        triggerType = r.parsedTriggerType

        triggerMemberID = r.triggerMemberID
        triggerEvent = r.triggerEvent.flatMap { ReminderTriggerEvent(rawValue: $0) } ?? .any
        delayMinutes = (r.delaySeconds ?? 0) / 60

        if let kind = r.parsedScheduleKind {
            scheduleKind = kind
        }
        if let time = r.scheduleTime, time.count >= 5 {
            let parts = time.split(separator: ":")
            if parts.count == 2 {
                scheduleTimeHour = Int(parts[0]) ?? 9
                scheduleTimeMinute = Int(parts[1]) ?? 0
            }
        }
        scheduleDowMask = r.scheduleDowMask ?? 0b0011111
        scheduleDom = r.scheduleDom ?? 1

        if let cron = r.cronExpression, !cron.isEmpty {
            useCron = true
            cronExpression = cron
        }

        scope = ReminderScope(rawValue: r.scope ?? "system") ?? .system
        scopeMemberIDs = Set(r.scopeMemberIDs ?? [])
        digestWhenAbsent = r.digestWhenAbsent ?? true
    }

    // MARK: - Save

    private func save() {
        isSaving = true
        errorMessage = nil

        Task {
            let scheduleTime = String(format: "%02d:%02d", scheduleTimeHour, scheduleTimeMinute)
            let tz = TimeZone.current.identifier

            if let existing {
                let update = ReminderUpdate(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    body: bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : bodyText.trimmingCharacters(in: .whitespacesAndNewlines),
                    enabled: enabled,
                    channelID: channelID,
                    triggerType: triggerType.rawValue,
                    triggerMemberID: triggerType == .automated ? triggerMemberID : nil,
                    triggerEvent: triggerType == .automated ? triggerEvent.rawValue : nil,
                    delaySeconds: triggerType == .automated ? delayMinutes * 60 : nil,
                    scheduleKind: triggerType == .repeated && !useCron ? scheduleKind.rawValue : nil,
                    scheduleTime: triggerType == .repeated && !useCron ? scheduleTime : nil,
                    scheduleDowMask: triggerType == .repeated && !useCron && scheduleKind == .weekly ? scheduleDowMask : nil,
                    scheduleDom: triggerType == .repeated && !useCron && scheduleKind == .monthly ? scheduleDom : nil,
                    scheduleTz: triggerType == .repeated ? tz : nil,
                    cronExpression: triggerType == .repeated && useCron ? cronExpression : nil,
                    scope: triggerType == .repeated ? scope.rawValue : nil,
                    scopeMemberIDs: triggerType == .repeated && scope == .member ? Array(scopeMemberIDs) : nil,
                    digestWhenAbsent: triggerType == .repeated && scope == .member ? digestWhenAbsent : nil
                )
                if await store.updateReminder(id: existing.id, update: update) != nil {
                    dismiss()
                } else {
                    errorMessage = store.errorMessage ?? "Failed to update reminder."
                }
            } else {
                let create = ReminderCreate(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    body: bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : bodyText.trimmingCharacters(in: .whitespacesAndNewlines),
                    enabled: enabled,
                    channelID: channelID,
                    triggerType: triggerType.rawValue,
                    triggerMemberID: triggerType == .automated ? triggerMemberID : nil,
                    triggerEvent: triggerType == .automated ? triggerEvent.rawValue : nil,
                    delaySeconds: triggerType == .automated ? delayMinutes * 60 : nil,
                    scheduleKind: triggerType == .repeated && !useCron ? scheduleKind.rawValue : nil,
                    scheduleTime: triggerType == .repeated && !useCron ? scheduleTime : nil,
                    scheduleDowMask: triggerType == .repeated && !useCron && scheduleKind == .weekly ? scheduleDowMask : nil,
                    scheduleDom: triggerType == .repeated && !useCron && scheduleKind == .monthly ? scheduleDom : nil,
                    scheduleTz: triggerType == .repeated ? tz : nil,
                    cronExpression: triggerType == .repeated && useCron ? cronExpression : nil,
                    scope: triggerType == .repeated ? scope.rawValue : nil,
                    scopeMemberIDs: triggerType == .repeated && scope == .member ? Array(scopeMemberIDs) : nil,
                    digestWhenAbsent: triggerType == .repeated && scope == .member ? digestWhenAbsent : nil
                )
                if await store.createReminder(create) != nil {
                    dismiss()
                } else {
                    errorMessage = store.errorMessage ?? "Failed to create reminder."
                }
            }
            isSaving = false
        }
    }
}
