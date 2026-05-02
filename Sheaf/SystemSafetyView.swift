import SwiftUI

struct SystemSafetyView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var store: SystemStore

    @State private var safety: SystemSafetyResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?

    // Edit state
    @State private var draft: SystemSafetySettings?
    @State private var isSaving = false

    // Re-auth fields (required for loosening changes)
    @State private var password = ""
    @State private var totpCode = ""
    @State private var totpEnabled = false

    var body: some View {
        ZStack {
            theme.backgroundPrimary.ignoresSafeArea()

            if isLoading {
                ProgressView().tint(theme.accentLight)
            } else if let safety, let draft {
                ScrollView {
                    VStack(spacing: 24) {
                        descriptionSection
                        settingsForm(current: safety.settings, draft: draft)

                        if isLoosening(current: safety.settings, draft: draft) {
                            reauthSection(current: safety.settings)
                        }

                        if isDirty(current: safety.settings, draft: draft) {
                            saveButtons(current: safety.settings, draft: draft)
                        }

                        if !safety.pendingActions.isEmpty {
                            pendingActionsSection(safety.pendingActions)
                        }

                        if !safety.pendingChanges.isEmpty {
                            pendingChangesSection(safety.pendingChanges)
                        }
                    }
                    .padding(.vertical, 16)
                }
                .refreshable { await load() }
            } else if let errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(theme.textTertiary)
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Button("Retry") { Task { await load() } }
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundColor(theme.accentLight)
                }
            }
        }
        .navigationTitle("System Safety")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load(); await loadTotpStatus() }
    }

    // MARK: - Sections

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Optional grace periods and re-authentication for destructive actions like deleting members, groups, or front entries.")
                .font(.footnote)
                .foregroundColor(theme.textSecondary)
            Text("Tightening applies immediately. Loosening waits the current grace period before taking effect.")
                .font(.footnote)
                .foregroundColor(theme.textTertiary)
        }
        .padding(.horizontal, 24)
    }

    private func settingsForm(current: SystemSafetySettings, draft: SystemSafetySettings) -> some View {
        VStack(spacing: 16) {
            // Grace period
            section(title: "Grace Period") {
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(theme.accentLight)
                            .frame(width: 20)
                        Text("Days")
                            .font(.subheadline)
                            .foregroundColor(theme.textPrimary)
                        Spacer()
                        Stepper(value: Binding(
                            get: { self.draft?.gracePeriodDays ?? 0 },
                            set: { self.draft?.gracePeriodDays = $0 }
                        ), in: 0...365) {
                            Text("\(self.draft?.gracePeriodDays ?? 0)")
                                .font(.subheadline).fontWeight(.semibold)
                                .foregroundColor(theme.accentLight)
                                .frame(minWidth: 30)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)

                    if (self.draft?.gracePeriodDays ?? 0) == 0 {
                        Divider().background(theme.divider)
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundColor(theme.textTertiary)
                            Text("Grace period is disabled. Deletions happen immediately.")
                                .font(.caption)
                                .foregroundColor(theme.textTertiary)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                    }
                }
            }

            // Auth tier
            section(title: "Auth Tier") {
                VStack(spacing: 0) {
                    authTierRow(.none, label: String(localized: "No confirmation"), icon: "minus.circle")
                    Divider().background(theme.divider).padding(.leading, 52)
                    authTierRow(.password, label: String(localized: "Require password"), icon: "key.fill")
                    if totpEnabled {
                        Divider().background(theme.divider).padding(.leading, 52)
                        authTierRow(.totp, label: String(localized: "Require 2FA code"), icon: "lock.shield.fill")
                        Divider().background(theme.divider).padding(.leading, 52)
                        authTierRow(.both, label: String(localized: "Password + 2FA"), icon: "lock.fill")
                    }
                }
            }

            // Category toggles
            section(title: "Apply Safety To") {
                VStack(spacing: 0) {
                    categoryToggle(label: "Members", icon: "person.fill", keyPath: \.appliesToMembers)
                    Divider().background(theme.divider).padding(.leading, 52)
                    categoryToggle(label: "Groups", icon: "folder.fill", keyPath: \.appliesToGroups)
                    Divider().background(theme.divider).padding(.leading, 52)
                    categoryToggle(label: "Tags", icon: "tag.fill", keyPath: \.appliesToTags)
                    Divider().background(theme.divider).padding(.leading, 52)
                    categoryToggle(label: "Custom Fields", icon: "list.bullet.rectangle", keyPath: \.appliesToFields)
                    Divider().background(theme.divider).padding(.leading, 52)
                    categoryToggle(label: "Front Entries", icon: "clock.arrow.2.circlepath", keyPath: \.appliesToFronts)
                    Divider().background(theme.divider).padding(.leading, 52)
                    categoryToggle(label: "Journal Entries", icon: "book.fill", keyPath: \.appliesToJournals)
                    Divider().background(theme.divider).padding(.leading, 52)
                    categoryToggle(label: "Images", icon: "photo.fill", keyPath: \.appliesToImages)
                    Divider().background(theme.divider).padding(.leading, 52)
                    categoryToggle(label: "Pinned Revisions", icon: "pin.fill", keyPath: \.appliesToRevisions)
                }
            }
        }
    }

    private func reauthSection(current: SystemSafetySettings) -> some View {
        section(title: "Re-authentication Required") {
            VStack(spacing: 0) {
                Text("Loosening safety settings requires re-authentication and will take effect after the current grace period.")
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
                    .padding(.horizontal, 16).padding(.vertical, 10)

                if current.authTier == .password || current.authTier == .both {
                    Divider().background(theme.divider)
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(theme.textTertiary)
                            .frame(width: 20)
                        SecureField("Password", text: $password)
                            .font(.subheadline)
                            .textContentType(.password)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }

                if (current.authTier == .totp || current.authTier == .both) && totpEnabled {
                    Divider().background(theme.divider)
                    HStack {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(theme.textTertiary)
                            .frame(width: 20)
                        TextField("6-digit code", text: $totpCode)
                            .font(.subheadline)
                            .textContentType(.oneTimeCode)
                            .keyboardType(.numberPad)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }
            }
        }
    }

    private func saveButtons(current: SystemSafetySettings, draft: SystemSafetySettings) -> some View {
        HStack(spacing: 12) {
            Button {
                Task { await save(current: current, draft: draft) }
            } label: {
                HStack {
                    if isSaving { ProgressView().tint(.white) }
                    Text(isSaving ? "Saving…" : "Save")
                        .font(.subheadline).fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(theme.accentLight)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isSaving)

            Button {
                self.draft = current
                password = ""
                totpCode = ""
            } label: {
                Text("Revert")
                    .font(.subheadline).fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(theme.backgroundCard)
                    .foregroundColor(theme.textPrimary)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.divider, lineWidth: 1))
            }
            .disabled(isSaving)
        }
        .padding(.horizontal, 24)
    }

    private func pendingActionsSection(_ actions: [PendingAction]) -> some View {
        section(title: "Pending Destructive Actions") {
            VStack(spacing: 0) {
                ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                    if index > 0 { Divider().background(theme.divider) }
                    pendingActionRow(action)
                }
            }
        }
    }

    private func pendingChangesSection(_ changes: [SafetyChangeRequest]) -> some View {
        section(title: "Pending Safety Changes") {
            VStack(spacing: 0) {
                ForEach(Array(changes.enumerated()), id: \.element.id) { index, change in
                    if index > 0 { Divider().background(theme.divider) }
                    pendingChangeRow(change)
                }
            }
        }
    }

    // MARK: - Row Helpers

    private func authTierRow(_ tier: DeleteConfirmation, label: String, icon: String) -> some View {
        Button {
            self.draft?.authTier = tier
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(self.draft?.authTier == tier ? theme.accentLight : theme.textTertiary)
                    .frame(width: 20)
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(theme.textPrimary)
                Spacer()
                if self.draft?.authTier == tier {
                    Image(systemName: "checkmark")
                        .font(.footnote).fontWeight(.semibold)
                        .foregroundColor(theme.accentLight)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
        }
    }

    private func categoryToggle(label: String, icon: String, keyPath: WritableKeyPath<SystemSafetySettings, Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(theme.accentLight)
                .frame(width: 20)
            Text(label)
                .font(.subheadline)
                .foregroundColor(theme.textPrimary)
            Spacer()
            Toggle("", isOn: Binding(
                get: { self.draft?[keyPath: keyPath] ?? false },
                set: { self.draft?[keyPath: keyPath] = $0 }
            ))
            .labelsHidden()
            .tint(theme.accentLight)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private func pendingActionRow(_ action: PendingAction) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(action.targetLabel)
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundColor(theme.textPrimary)
                Text("\(actionTypeLabel(action.actionType)) · Finalizes \(action.finalizeAfter, style: .relative)")
                    .font(.caption)
                    .foregroundColor(theme.textTertiary)
                if !action.frontingMemberNames.isEmpty {
                    Text("Fronting: \(action.frontingMemberNames.joined(separator: ", "))")
                        .font(.caption2)
                        .foregroundColor(theme.textTertiary)
                }
            }
            Spacer()
            Button {
                Task { await cancelAction(action.id) }
            } label: {
                Text("Cancel")
                    .font(.caption).fontWeight(.medium)
                    .foregroundColor(theme.danger)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(theme.danger.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private func pendingChangeRow(_ change: SafetyChangeRequest) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(changeSummary(change.changes))
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundColor(theme.textPrimary)
                Text("Finalizes \(change.finalizeAfter, style: .relative)")
                    .font(.caption)
                    .foregroundColor(theme.textTertiary)
            }
            Spacer()
            Button {
                Task { await cancelChange(change.id) }
            } label: {
                Text("Cancel")
                    .font(.caption).fontWeight(.medium)
                    .foregroundColor(theme.danger)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(theme.danger.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption).fontWeight(.semibold)
                .foregroundColor(theme.textSecondary)
                .textCase(.uppercase)
                .kerning(0.8)
                .padding(.horizontal, 24)
            VStack(spacing: 0) { content() }
                .background(theme.backgroundCard)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.backgroundCard, lineWidth: 1))
                .padding(.horizontal, 24)
        }
    }

    // MARK: - Actions

    private func load() async {
        guard let api = store.api else { return }
        isLoading = safety == nil
        do {
            let response = try await api.getSystemSafety()
            safety = response
            if draft == nil { draft = response.settings }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func loadTotpStatus() async {
        guard let api = store.api else { return }
        if let me = try? await api.getMe() {
            totpEnabled = me.totpEnabled
        }
    }

    private func save(current: SystemSafetySettings, draft: SystemSafetySettings) async {
        guard let api = store.api else { return }
        isSaving = true
        defer { isSaving = false }

        var update = SystemSafetyUpdate()
        if current.gracePeriodDays != draft.gracePeriodDays { update.gracePeriodDays = draft.gracePeriodDays }
        if current.authTier != draft.authTier { update.authTier = draft.authTier }
        if current.appliesToMembers != draft.appliesToMembers { update.appliesToMembers = draft.appliesToMembers }
        if current.appliesToGroups != draft.appliesToGroups { update.appliesToGroups = draft.appliesToGroups }
        if current.appliesToTags != draft.appliesToTags { update.appliesToTags = draft.appliesToTags }
        if current.appliesToFields != draft.appliesToFields { update.appliesToFields = draft.appliesToFields }
        if current.appliesToFronts != draft.appliesToFronts { update.appliesToFronts = draft.appliesToFronts }
        if current.appliesToJournals != draft.appliesToJournals { update.appliesToJournals = draft.appliesToJournals }
        if current.appliesToImages != draft.appliesToImages { update.appliesToImages = draft.appliesToImages }
        if current.appliesToRevisions != draft.appliesToRevisions { update.appliesToRevisions = draft.appliesToRevisions }

        if isLoosening(current: current, draft: draft) {
            if !password.isEmpty { update.password = password }
            if !totpCode.isEmpty { update.totpCode = totpCode }
        }

        do {
            let result = try await api.updateSystemSafety(update)
            safety = SystemSafetyResponse(
                settings: result.settings,
                pendingActions: safety?.pendingActions ?? [],
                pendingChanges: safety?.pendingChanges ?? (result.pendingChange.map { [$0] } ?? [])
            )
            self.draft = result.settings
            password = ""
            totpCode = ""
            // Reload to get fresh pending lists
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func cancelAction(_ id: String) async {
        guard let api = store.api else { return }
        do {
            try await api.cancelPendingAction(id: id)
            safety?.pendingActions.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func cancelChange(_ id: String) async {
        guard let api = store.api else { return }
        do {
            try await api.cancelPendingChange(id: id)
            safety?.pendingChanges.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private func isDirty(current: SystemSafetySettings, draft: SystemSafetySettings) -> Bool {
        current.gracePeriodDays != draft.gracePeriodDays ||
        current.authTier != draft.authTier ||
        current.appliesToMembers != draft.appliesToMembers ||
        current.appliesToGroups != draft.appliesToGroups ||
        current.appliesToTags != draft.appliesToTags ||
        current.appliesToFields != draft.appliesToFields ||
        current.appliesToFronts != draft.appliesToFronts ||
        current.appliesToJournals != draft.appliesToJournals ||
        current.appliesToImages != draft.appliesToImages ||
        current.appliesToRevisions != draft.appliesToRevisions
    }

    private func isLoosening(current: SystemSafetySettings, draft: SystemSafetySettings) -> Bool {
        if draft.gracePeriodDays < current.gracePeriodDays { return true }
        if tierStrength(draft.authTier) < tierStrength(current.authTier) { return true }
        if current.appliesToMembers && !draft.appliesToMembers { return true }
        if current.appliesToGroups && !draft.appliesToGroups { return true }
        if current.appliesToTags && !draft.appliesToTags { return true }
        if current.appliesToFields && !draft.appliesToFields { return true }
        if current.appliesToFronts && !draft.appliesToFronts { return true }
        if current.appliesToJournals && !draft.appliesToJournals { return true }
        if current.appliesToImages && !draft.appliesToImages { return true }
        if current.appliesToRevisions && !draft.appliesToRevisions { return true }
        return false
    }

    private func tierStrength(_ tier: DeleteConfirmation) -> Int {
        switch tier {
        case .none: return 0
        case .password, .totp: return 1
        case .both: return 2
        }
    }

    private func actionTypeLabel(_ type: String) -> String {
        switch type {
        case "member_delete": return String(localized: "Delete member")
        case "group_delete": return String(localized: "Delete group")
        case "tag_delete": return String(localized: "Delete tag")
        case "field_delete": return String(localized: "Delete field")
        case "front_delete": return String(localized: "Delete front")
        case "journal_delete": return String(localized: "Delete journal entry")
        case "image_delete": return String(localized: "Delete image")
        default: return type
        }
    }

    private func changeSummary(_ changes: [String: AnyCodable]) -> String {
        var parts: [String] = []
        for (key, value) in changes {
            if key == "safety_grace_period_days" {
                parts.append("Grace period → \(value.value) days")
            } else if key == "delete_confirmation" {
                parts.append("Auth tier → \(value.value)")
            } else if key.hasPrefix("safety_applies_to_") {
                let cat = key.replacingOccurrences(of: "safety_applies_to_", with: "")
                parts.append("Disable \(cat)")
            } else {
                parts.append("\(key) → \(value.value)")
            }
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Unpin Revision Sheet

struct UnpinRevisionSheet: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var store: SystemStore
    @Environment(\.dismiss) var dismiss

    let onUnpin: (_ password: String?, _ totpCode: String?) async throws -> UnpinRevisionResponse?
    let onSuccess: (UnpinRevisionResponse?) -> Void

    @State private var password = ""
    @State private var totpCode = ""
    @State private var authTier: DeleteConfirmation = .none
    @State private var totpEnabled = false
    @State private var isLoading = true
    @State private var isUnpinning = false
    @State private var errorMessage: String?

    private var needsPassword: Bool {
        authTier == .password || authTier == .both
    }

    private var needsTotp: Bool {
        (authTier == .totp || authTier == .both) && totpEnabled
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if isLoading {
                    ProgressView().tint(theme.accentLight)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Unpinned revisions may be removed by automatic retention cleanup.", systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundColor(theme.textSecondary)

                        if needsPassword {
                            HStack {
                                Image(systemName: "key.fill")
                                    .foregroundColor(theme.textTertiary)
                                    .frame(width: 20)
                                SecureField("Password", text: $password)
                                    .font(.subheadline)
                                    .textContentType(.password)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 12)
                            .background(theme.backgroundCard)
                            .cornerRadius(12)
                        }

                        if needsTotp {
                            HStack {
                                Image(systemName: "lock.shield.fill")
                                    .foregroundColor(theme.textTertiary)
                                    .frame(width: 20)
                                TextField("6-digit code", text: $totpCode)
                                    .font(.subheadline)
                                    .textContentType(.oneTimeCode)
                                    .keyboardType(.numberPad)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 12)
                            .background(theme.backgroundCard)
                            .cornerRadius(12)
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundColor(.red)
                        }
                    }

                    Spacer()

                    Button {
                        Task { await performUnpin() }
                    } label: {
                        HStack {
                            if isUnpinning { ProgressView().tint(.white) }
                            Text(isUnpinning ? "Unpinning…" : "Unpin Revision")
                                .font(.subheadline).fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(theme.danger)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isUnpinning || (needsPassword && password.isEmpty) || (needsTotp && totpCode.isEmpty))
                }
            }
            .padding(24)
            .background(theme.backgroundPrimary)
            .navigationTitle("Unpin Revision")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(theme.accentLight)
                }
            }
        }
        .presentationDetents([.medium])
        .task { await loadAuthRequirements() }
    }

    private func loadAuthRequirements() async {
        if let safety = try? await store.api?.getSystemSafety() {
            if safety.settings.appliesToRevisions {
                authTier = safety.settings.authTier
            }
        }
        if let me = try? await store.api?.getMe() {
            totpEnabled = me.totpEnabled
        }
        isLoading = false
    }

    private func performUnpin() async {
        isUnpinning = true
        errorMessage = nil
        do {
            let pw = needsPassword ? password : nil
            let totp = needsTotp ? totpCode : nil
            let response = try await onUnpin(pw, totp)
            onSuccess(response)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isUnpinning = false
    }
}
