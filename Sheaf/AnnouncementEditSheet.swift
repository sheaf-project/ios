import SwiftUI

// MARK: - Announcement Edit Sheet

struct AnnouncementEditSheet: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var store: SystemStore
    @Environment(\.dismiss) var dismiss

    let announcement: AnnouncementRead?
    let onSave: () -> Void

    @State private var title = ""
    @State private var bodyText = ""
    @State private var severity: AnnouncementSeverity = .info
    @State private var dismissible = true
    @State private var active = true
    @State private var hasStartDate = false
    @State private var startsAt = Date()
    @State private var hasExpireDate = false
    @State private var expiresAt = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var isSaving = false
    @State private var error: String?

    var isNew: Bool { announcement == nil }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Title
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Title")
                                .font(.footnote).fontWeight(.semibold)
                                .foregroundColor(theme.textSecondary)
                            TextField("Announcement title", text: $title)
                                .autocorrectionDisabled()
                                .padding(12)
                                .background(theme.backgroundCard)
                                .cornerRadius(12)
                                .foregroundColor(theme.textPrimary)
                        }

                        // Body
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Body")
                                .font(.footnote).fontWeight(.semibold)
                                .foregroundColor(theme.textSecondary)
                            TextField("Announcement body", text: $bodyText, axis: .vertical)
                                .lineLimit(3...8)
                                .padding(12)
                                .background(theme.backgroundCard)
                                .cornerRadius(12)
                                .foregroundColor(theme.textPrimary)
                        }

                        // Severity
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Severity")
                                .font(.footnote).fontWeight(.semibold)
                                .foregroundColor(theme.textSecondary)
                            Picker("Severity", selection: $severity) {
                                Text("Info").tag(AnnouncementSeverity.info)
                                Text("Warning").tag(AnnouncementSeverity.warning)
                                Text("Critical").tag(AnnouncementSeverity.critical)
                            }
                            .pickerStyle(.segmented)
                        }

                        // Toggles
                        VStack(spacing: 0) {
                            Toggle(isOn: $active) {
                                Text("Active")
                                    .font(.subheadline)
                                    .foregroundColor(theme.textPrimary)
                            }
                            .tint(theme.accentLight)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)

                            Divider().background(theme.divider).padding(.leading, 12)

                            Toggle(isOn: $dismissible) {
                                Text("Dismissible")
                                    .font(.subheadline)
                                    .foregroundColor(theme.textPrimary)
                            }
                            .tint(theme.accentLight)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                        }
                        .background(theme.backgroundCard)
                        .cornerRadius(12)

                        // Start date
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle(isOn: $hasStartDate) {
                                Text("Starts at")
                                    .font(.subheadline)
                                    .foregroundColor(theme.textPrimary)
                            }
                            .tint(theme.accentLight)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(theme.backgroundCard)
                            .cornerRadius(12)

                            if hasStartDate {
                                DatePicker("Start Date", selection: $startsAt, displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(.compact)
                                    .tint(theme.accentLight)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(theme.backgroundCard)
                                    .cornerRadius(12)
                                    .foregroundColor(theme.textPrimary)
                            }
                        }

                        // Expire date
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle(isOn: $hasExpireDate) {
                                Text("Expires at")
                                    .font(.subheadline)
                                    .foregroundColor(theme.textPrimary)
                            }
                            .tint(theme.accentLight)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(theme.backgroundCard)
                            .cornerRadius(12)

                            if hasExpireDate {
                                DatePicker("Expiry Date", selection: $expiresAt, displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(.compact)
                                    .tint(theme.accentLight)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(theme.backgroundCard)
                                    .cornerRadius(12)
                                    .foregroundColor(theme.textPrimary)
                            }
                        }

                        if let error {
                            Text(error)
                                .font(.footnote)
                                .foregroundColor(theme.danger)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(isNew ? "New Announcement" : "Edit Announcement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(theme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView().tint(theme.accentLight).scaleEffect(0.8)
                        } else {
                            Text("Save")
                                .font(.callout).fontWeight(.semibold)
                                .foregroundColor(theme.accentLight)
                        }
                    }
                    .disabled(title.isEmpty || bodyText.isEmpty || isSaving)
                }
            }
        }
        .presentationDetents([.large])
        .onAppear { populate() }
    }

    private func populate() {
        guard let a = announcement else { return }
        title = a.title
        bodyText = a.body
        severity = a.severity
        dismissible = a.dismissible
        active = a.active
        if let start = a.startsAt {
            hasStartDate = true
            startsAt = start
        }
        if let expire = a.expiresAt {
            hasExpireDate = true
            expiresAt = expire
        }
    }

    private func save() async {
        guard let api = store.api else { return }
        isSaving = true
        error = nil

        do {
            if let existing = announcement {
                let update = AnnouncementUpdate(
                    title: title,
                    body: bodyText,
                    severity: severity,
                    dismissible: dismissible,
                    active: active,
                    startsAt: hasStartDate ? startsAt : nil,
                    expiresAt: hasExpireDate ? expiresAt : nil,
                    clearStartsAt: !hasStartDate && existing.startsAt != nil ? true : nil,
                    clearExpiresAt: !hasExpireDate && existing.expiresAt != nil ? true : nil
                )
                _ = try await api.updateAnnouncement(id: existing.id, update: update)
            } else {
                let create = AnnouncementCreate(
                    title: title,
                    body: bodyText,
                    severity: severity,
                    dismissible: dismissible,
                    active: active,
                    startsAt: hasStartDate ? startsAt : nil,
                    expiresAt: hasExpireDate ? expiresAt : nil
                )
                _ = try await api.createAnnouncement(create)
            }
            await MainActor.run {
                isSaving = false
                onSave()
                dismiss()
            }
        } catch is CancellationError {
            await MainActor.run { isSaving = false }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isSaving = false
            }
        }
    }
}
