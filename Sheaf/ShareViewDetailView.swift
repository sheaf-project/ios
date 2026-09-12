import SwiftUI

struct ShareViewDetailView: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: SystemStore

    let stepUpArmed: Bool
    let authTier: DeleteConfirmation
    let totpEnabled: Bool
    let publishingEnabled: Bool
    let onUpdate: (ShareView) -> Void
    let onDelete: (String) -> Void

    @State private var share: ShareView
    @State private var auditEntries: [ShareAuditEntry] = []
    @State private var errorMessage: String?
    @State private var stepUp: StepUpRequest?
    @State private var showPreview = false
    @State private var showMemberPicker = false
    @State private var showGroupPicker = false
    @State private var showFieldPicker = false
    @State private var groupAddResult: ShareViewGroupAddResult?
    @State private var detachTarget: ShareViewGroupRow?
    @State private var showDeleteConfirm = false

    init(initial: ShareView, stepUpArmed: Bool, authTier: DeleteConfirmation,
         totpEnabled: Bool, publishingEnabled: Bool,
         onUpdate: @escaping (ShareView) -> Void, onDelete: @escaping (String) -> Void) {
        _share = State(initialValue: initial)
        self.stepUpArmed = stepUpArmed
        self.authTier = authTier
        self.totpEnabled = totpEnabled
        self.publishingEnabled = publishingEnabled
        self.onUpdate = onUpdate
        self.onDelete = onDelete
    }

    var body: some View {
        ZStack {
            theme.backgroundPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    if share.isShared {
                        HStack(spacing: 8) {
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .foregroundColor(theme.success)
                            Text("This view is published.")
                                .font(.footnote)
                                .foregroundColor(theme.textSecondary)
                            Spacer(minLength: 0)
                        }
                        .padding(14)
                        .background(theme.backgroundCard)
                        .cornerRadius(12)
                        .padding(.horizontal, 24)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundColor(theme.danger)
                            .padding(.horizontal, 24)
                    }

                    flagsSection
                    membersSection
                    groupsSection
                    fieldsSection
                    if !auditEntries.isEmpty {
                        auditSection
                    }
                    actionsSection
                }
                .padding(.vertical, 16)
            }
            .refreshable { await reload() }
        }
        .navigationTitle(share.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await refreshAudit() }
        .sheet(item: $stepUp) { req in
            SharingStepUpSheet(request: req, authTier: authTier, totpEnabled: totpEnabled)
        }
        .sheet(isPresented: $showPreview) {
            SharePreviewSheet(viewID: share.id)
                .environmentObject(store)
        }
        .sheet(isPresented: $showMemberPicker) {
            SharePickerSheet(
                title: String(localized: "Add Member"),
                items: memberCandidates,
                onPick: { addMember($0) }
            )
        }
        .sheet(isPresented: $showGroupPicker) {
            SharePickerSheet(
                title: String(localized: "Add Group"),
                items: groupCandidates,
                onPick: { addGroup($0) }
            )
        }
        .sheet(isPresented: $showFieldPicker) {
            SharePickerSheet(
                title: String(localized: "Add Field"),
                items: fieldCandidates,
                onPick: { addField($0) }
            )
        }
        .alert("Group Added", isPresented: Binding(
            get: { groupAddResult != nil },
            set: { if !$0 { groupAddResult = nil } }
        )) {
            Button("OK") { groupAddResult = nil }
        } message: {
            if let r = groupAddResult {
                Text(groupAddSummary(r))
            }
        }
        .confirmationDialog(
            "Remove this group?",
            isPresented: Binding(get: { detachTarget != nil }, set: { if !$0 { detachTarget = nil } }),
            titleVisibility: .visible
        ) {
            Button("Remove Group and Its Members", role: .destructive) {
                if let g = detachTarget { removeGroup(g, removeMembers: true) }
            }
            Button("Remove Group, Keep Members") {
                if let g = detachTarget { removeGroup(g, removeMembers: false) }
            }
            Button("Cancel", role: .cancel) { detachTarget = nil }
        } message: {
            Text("Removing members takes them off the page immediately. Kept members stay as individually chosen ones.")
        }
        .confirmationDialog(
            "Delete this view?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete View", role: .destructive) {
                Task { await deleteView() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every share pointing at this view is revoked immediately.")
        }
    }

    // MARK: - Flags

    private var flagsSection: some View {
        section(title: String(localized: "What This View Shows")) {
            VStack(spacing: 0) {
                flagRow(String(localized: "Member roster"), icon: "person.2.fill",
                        flag: "include_members", isOn: share.includeMembers, pending: share.pendingIncludeMembers)
                Divider().background(theme.divider).padding(.leading, 52)
                flagRow(String(localized: "Member bios"), icon: "text.alignleft",
                        flag: "include_bio", isOn: share.includeBio, pending: share.pendingIncludeBio)
                Divider().background(theme.divider).padding(.leading, 52)
                flagRow(String(localized: "Current fronting"), icon: "clock.fill",
                        flag: "include_fronting", isOn: share.includeFronting, pending: share.pendingIncludeFronting)
                Divider().background(theme.divider).padding(.leading, 52)
                flagRow(String(localized: "Hidden fronter count"), icon: "number",
                        flag: "fronting_show_count", isOn: share.frontingShowCount, pending: share.pendingFrontingShowCount)
                Divider().background(theme.divider).padding(.leading, 52)
                flagRow(String(localized: "Relationships"), icon: "person.line.dotted.person",
                        flag: "include_relationships", isOn: share.includeRelationships, pending: share.pendingIncludeRelationships)
                Divider().background(theme.divider).padding(.leading, 52)
                flagRow(String(localized: "Groups"), icon: "folder.fill",
                        flag: "include_groups", isOn: share.includeGroups, pending: share.pendingIncludeGroups)
                Divider().background(theme.divider).padding(.leading, 52)
                permalinkRow
            }
        }
    }

    private func flagRow(_ title: String, icon: String, flag: String, isOn: Bool, pending: Bool?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(theme.accentLight)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(theme.textPrimary)
                if let pending, let at = share.flagsActivateAt {
                    Text("Turns \(pending ? String(localized: "on") : String(localized: "off")) \(at.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundColor(theme.warning)
                }
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { isOn },
                set: { setFlag(flag, $0) }
            ))
            .labelsHidden()
            .tint(theme.accentLight)
            .disabled(!publishingEnabled && !isOn)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private var permalinkRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "link")
                .foregroundColor(theme.accentLight)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text("Member permalinks")
                    .font(.subheadline)
                    .foregroundColor(theme.textPrimary)
                Text("Stable addresses for members the roster already shows.")
                    .font(.caption)
                    .foregroundColor(theme.textTertiary)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { share.memberPermalinks },
                set: { value in
                    Task {
                        var u = ShareViewUpdate()
                        u.memberPermalinks = value
                        do { try await apply(u) }
                        catch { await MainActor.run { errorMessage = error.userFacingMessage } }
                    }
                }
            ))
            .labelsHidden()
            .tint(theme.accentLight)
            .disabled(!publishingEnabled && !share.memberPermalinks)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    // MARK: - Members

    private var membersSection: some View {
        section(title: String(localized: "Members in This View")) {
            VStack(spacing: 0) {
                if share.members.isEmpty {
                    Text("No members selected. The roster is empty even when it is on.")
                        .font(.footnote)
                        .foregroundColor(theme.textTertiary)
                        .padding(.horizontal, 16).padding(.vertical, 14)
                }
                ForEach(share.members) { row in
                    memberRow(row)
                    Divider().background(theme.divider)
                }
                addButton(String(localized: "Add Member")) { showMemberPicker = true }
            }
        }
    }

    private func memberRow(_ row: ShareViewMemberRow) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(memberName(row.memberID))
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundColor(theme.textPrimary)
                HStack(spacing: 6) {
                    if row.status == "pending", let at = row.activatesAt {
                        Text("Appears \(at.formatted(.relative(presentation: .named)))")
                            .font(.caption)
                            .foregroundColor(theme.warning)
                    } else if !row.served {
                        Text(notServedText(row.notServedReason))
                            .font(.caption)
                            .foregroundColor(theme.textTertiary)
                    }
                    if row.addedViaGroupID != nil {
                        Text("via group")
                            .font(.caption)
                            .foregroundColor(theme.textTertiary)
                    }
                }
            }
            Spacer()
            Button {
                removeMember(row)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(theme.danger.opacity(0.8))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    // MARK: - Groups

    private var groupsSection: some View {
        section(title: String(localized: "Groups")) {
            VStack(spacing: 0) {
                if share.groups.isEmpty {
                    Text("Adding a group adds its shareable members in bulk.")
                        .font(.footnote)
                        .foregroundColor(theme.textTertiary)
                        .padding(.horizontal, 16).padding(.vertical, 14)
                }
                ForEach(share.groups) { row in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(groupName(row.groupID))
                                .font(.subheadline).fontWeight(.medium)
                                .foregroundColor(theme.textPrimary)
                            Text("Synced \(row.syncedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundColor(theme.textTertiary)
                        }
                        Spacer()
                        Button {
                            detachTarget = row
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(theme.danger.opacity(0.8))
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    Divider().background(theme.divider)
                }
                addButton(String(localized: "Add Group")) { showGroupPicker = true }
            }
        }
    }

    // MARK: - Fields

    private var fieldsSection: some View {
        section(title: String(localized: "Custom Fields")) {
            VStack(spacing: 0) {
                if share.fields.isEmpty {
                    Text("No fields exposed. Member cards show no custom fields.")
                        .font(.footnote)
                        .foregroundColor(theme.textTertiary)
                        .padding(.horizontal, 16).padding(.vertical, 14)
                }
                ForEach(share.fields) { row in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(fieldName(row.fieldID))
                                .font(.subheadline).fontWeight(.medium)
                                .foregroundColor(theme.textPrimary)
                            if row.status == "pending", let at = row.activatesAt {
                                Text("Appears \(at.formatted(.relative(presentation: .named)))")
                                    .font(.caption)
                                    .foregroundColor(theme.warning)
                            }
                        }
                        Spacer()
                        Button {
                            removeField(row)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(theme.danger.opacity(0.8))
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    Divider().background(theme.divider)
                }
                addButton(String(localized: "Add Field")) { showFieldPicker = true }
            }
        }
    }

    // MARK: - Audit (who can see what, scoped to this view's grants)

    private var auditSection: some View {
        section(title: String(localized: "Who Can See What")) {
            VStack(spacing: 0) {
                ForEach(Array(auditEntries.enumerated()), id: \.element.id) { i, e in
                    if i > 0 { Divider().background(theme.divider) }
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(e.grant.subjectType == "public" ? "Public profile" : "Share link")
                                .font(.subheadline).fontWeight(.medium)
                                .foregroundColor(theme.textPrimary)
                            if let note = e.grant.note, !note.isEmpty {
                                Text(note)
                                    .font(.caption)
                                    .foregroundColor(theme.textTertiary)
                                    .lineLimit(1)
                            }
                        }
                        Text(auditSummary(e))
                            .font(.caption)
                            .foregroundColor(theme.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }
            }
        }
    }

    private func auditSummary(_ e: ShareAuditEntry) -> String {
        var parts: [String] = []
        if e.includeMembers {
            if let served = e.servedMemberCount, served != e.memberCount {
                parts.append(String(localized: "\(served) of ^[\(e.memberCount) member](inflect: true) served"))
            } else {
                parts.append(String(localized: "^[\(e.memberCount) member](inflect: true)"))
            }
        } else {
            parts.append(String(localized: "roster hidden"))
        }
        parts.append(String(localized: "^[\(e.fieldCount) field](inflect: true)"))
        if e.includeFronting { parts.append(String(localized: "fronting")) }
        if e.includeRelationships { parts.append(String(localized: "^[\(e.relationshipCount) relationship](inflect: true)")) }
        if e.includeGroups { parts.append(String(localized: "^[\(e.groupCount) group](inflect: true)")) }
        return parts.joined(separator: " · ")
    }

    private func refreshAudit() async {
        guard let api = store.api else { return }
        if let audit = try? await api.getSharingAudit() {
            await MainActor.run {
                auditEntries = audit.entries.filter { $0.viewID == share.id }
            }
        }
    }

    // MARK: - Actions section

    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button {
                showPreview = true
            } label: {
                HStack {
                    Image(systemName: "eye.fill")
                    Text("Preview as Visitor")
                        .font(.subheadline).fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(theme.accentLight)
                .foregroundColor(.white)
                .cornerRadius(12)
            }

            Button {
                showDeleteConfirm = true
            } label: {
                Text("Delete View")
                    .font(.subheadline).fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(theme.danger.opacity(0.12))
                    .foregroundColor(theme.danger)
                    .cornerRadius(12)
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Mutations

    private func setFlag(_ flag: String, _ value: Bool) {
        var u = ShareViewUpdate()
        switch flag {
        case "include_members": u.includeMembers = value
        case "include_bio": u.includeBio = value
        case "include_fronting": u.includeFronting = value
        case "fronting_show_count": u.frontingShowCount = value
        case "include_relationships": u.includeRelationships = value
        case "include_groups": u.includeGroups = value
        default: return
        }
        let loosening = value && share.isShared
        performMutation(exposing: loosening,
                        message: String(localized: "Showing more on a published view requires re-authentication.")) { pw, totp in
            var x = u
            x.password = pw
            x.totpCode = totp
            try await apply(x)
        }
    }

    private func addMember(_ id: String) {
        performMutation(exposing: share.isShared,
                        message: String(localized: "Adding a member to a published view requires re-authentication.")) { pw, totp in
            guard let api = store.api else { return }
            let updated = try await api.addShareViewMember(
                viewID: share.id,
                add: ShareViewMemberAdd(memberID: id, password: pw, totpCode: totp)
            )
            await MainActor.run { setShare(updated) }
        }
    }

    private func addGroup(_ id: String) {
        performMutation(exposing: share.isShared,
                        message: String(localized: "Adding a group to a published view requires re-authentication.")) { pw, totp in
            guard let api = store.api else { return }
            let result = try await api.addShareViewGroup(
                viewID: share.id,
                add: ShareViewGroupAdd(groupID: id, password: pw, totpCode: totp)
            )
            await reload()
            await MainActor.run {
                if result.skippedNeverShareable > 0 || result.skippedNotPublic > 0 {
                    groupAddResult = result
                }
            }
        }
    }

    private func addField(_ id: String) {
        performMutation(exposing: share.isShared,
                        message: String(localized: "Exposing a field on a published view requires re-authentication.")) { pw, totp in
            guard let api = store.api else { return }
            let updated = try await api.addShareViewField(
                viewID: share.id,
                add: ShareViewFieldAdd(fieldID: id, password: pw, totpCode: totp)
            )
            await MainActor.run { setShare(updated) }
        }
    }

    private func removeMember(_ row: ShareViewMemberRow) {
        Task {
            guard let api = store.api else { return }
            do {
                try await api.removeShareViewMember(viewID: share.id, memberID: row.memberID)
                await MainActor.run {
                    share.members.removeAll { $0.id == row.id }
                    onUpdate(share)
                    errorMessage = nil
                }
            } catch {
                await MainActor.run { errorMessage = error.userFacingMessage }
            }
        }
    }

    private func removeGroup(_ row: ShareViewGroupRow, removeMembers: Bool) {
        detachTarget = nil
        Task {
            guard let api = store.api else { return }
            do {
                try await api.removeShareViewGroup(viewID: share.id, groupID: row.groupID, removeMembers: removeMembers)
                await reload()
            } catch {
                await MainActor.run { errorMessage = error.userFacingMessage }
            }
        }
    }

    private func removeField(_ row: ShareViewFieldRow) {
        Task {
            guard let api = store.api else { return }
            do {
                try await api.removeShareViewField(viewID: share.id, fieldID: row.fieldID)
                await MainActor.run {
                    share.fields.removeAll { $0.id == row.id }
                    onUpdate(share)
                    errorMessage = nil
                }
            } catch {
                await MainActor.run { errorMessage = error.userFacingMessage }
            }
        }
    }

    private func deleteView() async {
        guard let api = store.api else { return }
        do {
            try await api.deleteShareView(id: share.id)
            await MainActor.run {
                onDelete(share.id)
                dismiss()
            }
        } catch {
            await MainActor.run { errorMessage = error.userFacingMessage }
        }
    }

    /// Exposing mutations go through the step-up gate: pre-prompt when the local
    /// mirror says the category is armed, and re-prompt when the server bounces
    /// the bare call anyway. Un-exposing paths never come through here.
    private func performMutation(exposing: Bool, message: String,
                                 _ op: @escaping (_ password: String?, _ totpCode: String?) async throws -> Void) {
        if exposing && stepUpArmed && authTier != .none {
            stepUp = StepUpRequest(message: message, perform: op)
            return
        }
        Task {
            do {
                try await op(nil, nil)
                await MainActor.run { errorMessage = nil }
            } catch {
                await MainActor.run {
                    if isStepUpBounce(error) {
                        stepUp = StepUpRequest(message: message, perform: op)
                    } else {
                        errorMessage = error.userFacingMessage
                    }
                }
            }
        }
    }

    private func apply(_ u: ShareViewUpdate) async throws {
        guard let api = store.api else { return }
        let updated = try await api.updateShareView(id: share.id, update: u)
        await MainActor.run { setShare(updated) }
    }

    private func reload() async {
        guard let api = store.api else { return }
        if let fresh = try? await api.getShareView(id: share.id) {
            await MainActor.run {
                share = fresh
                onUpdate(fresh)
                errorMessage = nil
            }
        }
        await refreshAudit()
    }

    private func setShare(_ v: ShareView) {
        share = v
        onUpdate(v)
        errorMessage = nil
        Task { await refreshAudit() }
    }

    // MARK: - Helpers

    private var memberCandidates: [SharePickerItem] {
        let existing = Set(share.members.map(\.memberID))
        return store.members
            .filter { !existing.contains($0.id) && !$0.isArchived }
            .map { SharePickerItem(id: $0.id, label: $0.displayName ?? $0.name, detail: $0.privacy == .public ? nil : String(localized: "not public, will not be served")) }
    }

    private var groupCandidates: [SharePickerItem] {
        let existing = Set(share.groups.map(\.groupID))
        return store.groups
            .filter { !existing.contains($0.id) }
            .map { SharePickerItem(id: $0.id, label: $0.name, detail: nil) }
    }

    private var fieldCandidates: [SharePickerItem] {
        let existing = Set(share.fields.map(\.fieldID))
        return store.fields
            .filter { !existing.contains($0.id) }
            .map { SharePickerItem(id: $0.id, label: $0.name, detail: $0.privacy == .public ? nil : String(localized: "not public, will not be served")) }
    }

    private func memberName(_ id: String) -> String {
        guard let m = store.members.first(where: { $0.id == id }) else { return String(localized: "Unknown member") }
        return m.displayName ?? m.name
    }

    private func groupName(_ id: String) -> String {
        store.groups.first { $0.id == id }?.name ?? String(localized: "Deleted group")
    }

    private func fieldName(_ id: String) -> String {
        store.fields.first { $0.id == id }?.name ?? String(localized: "Deleted field")
    }

    private func notServedText(_ reason: String?) -> String {
        switch reason {
        case "member_private": return String(localized: "Not served: privacy is not public")
        case "never_shareable": return String(localized: "Not served: never shareable")
        case "archived": return String(localized: "Not served: archived")
        case "pending_deletion": return String(localized: "Not served: pending deletion")
        case let r?: return String(localized: "Not served: \(r.replacingOccurrences(of: "_", with: " "))")
        case nil: return String(localized: "Not served right now")
        }
    }

    private func groupAddSummary(_ r: ShareViewGroupAddResult) -> String {
        var parts = [String(localized: "^[\(r.added) member](inflect: true) added.")]
        if r.skippedNeverShareable > 0 {
            parts.append(String(localized: "\(r.skippedNeverShareable) skipped: never shareable."))
        }
        if r.skippedNotPublic > 0 {
            parts.append(String(localized: "\(r.skippedNotPublic) skipped: privacy is not public."))
        }
        return parts.joined(separator: " ")
    }

    private func addButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(theme.accentLight)
                    .frame(width: 20)
                Text(title)
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundColor(theme.accentLight)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
        }
        .disabled(!publishingEnabled)
        .opacity(publishingEnabled ? 1 : 0.5)
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
                .padding(.horizontal, 24)
        }
    }
}

// MARK: - Picker sheet

struct SharePickerItem: Identifiable {
    let id: String
    let label: String
    let detail: String?
}

struct SharePickerSheet: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss

    let title: String
    let items: [SharePickerItem]
    let onPick: (String) -> Void

    @State private var search = ""

    private var filtered: [SharePickerItem] {
        let q = search.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return items }
        return items.filter { $0.label.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundPrimary.ignoresSafeArea()

                if items.isEmpty {
                    Text("Nothing left to add.")
                        .font(.footnote)
                        .foregroundColor(theme.textTertiary)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(filtered) { item in
                                Button {
                                    onPick(item.id)
                                    dismiss()
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.label)
                                            .font(.subheadline).fontWeight(.medium)
                                            .foregroundColor(theme.textPrimary)
                                        if let detail = item.detail {
                                            Text(detail)
                                                .font(.caption)
                                                .foregroundColor(theme.textTertiary)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 16).padding(.vertical, 12)
                                }
                                Divider().background(theme.divider)
                            }
                        }
                        .background(theme.backgroundCard)
                        .cornerRadius(16)
                        .padding(24)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(theme.textSecondary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Preview as visitor

struct SharePreviewSheet: View {
    @Environment(\.theme) var theme
    @Environment(\.apiBaseURL) private var baseURL
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: SystemStore

    let viewID: String

    @State private var preview: SharePreview?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundPrimary.ignoresSafeArea()

                if isLoading {
                    ProgressView().tint(theme.accentLight)
                } else if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(40)
                } else if let p = preview {
                    ScrollView {
                        VStack(spacing: 24) {
                            if let s = p.suppressed {
                                suppressedNote(s)
                            }
                            systemCard(p.system)
                            if let fronting = p.fronting {
                                frontingCard(fronting)
                            }
                            if let members = p.members {
                                membersCard(members)
                            }
                            if let rels = p.relationships {
                                relationshipsCard(rels.relationships)
                            }
                            if let groups = p.groups {
                                groupsCard(groups.groups)
                            }
                        }
                        .padding(.vertical, 16)
                    }
                }
            }
            .navigationTitle("Visitor Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(theme.accentLight)
                }
            }
        }
        .presentationDetents([.large])
        .task { await load() }
    }

    private func load() async {
        guard let api = store.api else { return }
        do {
            preview = try await api.previewShareView(id: viewID)
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage
        }
        isLoading = false
    }

    private func suppressedNote(_ reason: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "eye.slash.fill")
                .foregroundColor(theme.warning)
                .frame(width: 20)
            Text(reason == "system_private"
                 ? String(localized: "Visitors currently get nothing: the system privacy level is not public. This preview shows what the page would serve.")
                 : String(localized: "Visitors currently get nothing. This preview shows what the page would serve."))
                .font(.footnote)
                .foregroundColor(theme.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(theme.backgroundCard)
        .cornerRadius(12)
        .padding(.horizontal, 24)
    }

    private func systemCard(_ s: PublicSystemView) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                publicAvatar(url: s.avatarURL, name: s.name, color: s.color, size: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.name)
                        .font(.headline)
                        .foregroundColor(theme.textPrimary)
                    if let tag = s.tag {
                        Text(tag)
                            .font(.caption)
                            .foregroundColor(theme.textTertiary)
                    }
                    if let n = s.memberCount {
                        Text("^[\(n) member](inflect: true)")
                            .font(.caption)
                            .foregroundColor(theme.textTertiary)
                    }
                }
                Spacer()
            }
            if let d = s.description, !d.isEmpty {
                Text(d)
                    .font(.footnote)
                    .foregroundColor(theme.textSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.backgroundCard)
        .cornerRadius(16)
        .padding(.horizontal, 24)
    }

    private func frontingCard(_ f: PublicFrontingView) -> some View {
        previewSection(title: String(localized: "Currently Fronting")) {
            VStack(alignment: .leading, spacing: 8) {
                if f.members.isEmpty && f.hiddenCount == 0 {
                    Text("Nobody fronting")
                        .font(.footnote)
                        .foregroundColor(theme.textTertiary)
                }
                ForEach(f.members) { m in
                    HStack(spacing: 10) {
                        publicAvatar(url: m.avatarURL, name: m.name, color: m.color, size: 28)
                        Text(m.name)
                            .font(.subheadline)
                            .foregroundColor(theme.textPrimary)
                        if let p = m.pronouns {
                            Text(p)
                                .font(.caption)
                                .foregroundColor(theme.textTertiary)
                        }
                        Spacer()
                    }
                }
                if f.hiddenCount > 0 {
                    Text("and ^[\(f.hiddenCount) other](inflect: true) not shown")
                        .font(.caption)
                        .foregroundColor(theme.textTertiary)
                }
            }
            .padding(16)
        }
    }

    private func membersCard(_ members: [PublicMemberView]) -> some View {
        previewSection(title: String(localized: "Members (\(members.count))")) {
            VStack(spacing: 0) {
                ForEach(members) { m in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            publicAvatar(url: m.avatarURL, name: m.name, color: m.color, size: 36)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(m.name)
                                    .font(.subheadline).fontWeight(.medium)
                                    .foregroundColor(theme.textPrimary)
                                if let p = m.pronouns {
                                    Text(p)
                                        .font(.caption)
                                        .foregroundColor(theme.textTertiary)
                                }
                            }
                            Spacer()
                        }
                        if let bio = m.bio, !bio.isEmpty {
                            Text(bio.replacingOccurrences(of: "#external-image-hidden", with: String(localized: "[external image hidden]")))
                                .font(.caption)
                                .foregroundColor(theme.textSecondary)
                                .lineLimit(6)
                        }
                        if !m.fields.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(Array(m.fields.enumerated()), id: \.offset) { _, f in
                                    Text("\(f.name): \(fieldValueText(f.value))")
                                        .font(.caption)
                                        .foregroundColor(theme.textTertiary)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    Divider().background(theme.divider)
                }
            }
        }
    }

    private func relationshipsCard(_ rels: [PublicRelationship]) -> some View {
        previewSection(title: String(localized: "Relationships (\(rels.count))")) {
            VStack(spacing: 0) {
                if rels.isEmpty {
                    Text("No relationships served")
                        .font(.footnote)
                        .foregroundColor(theme.textTertiary)
                        .padding(16)
                }
                ForEach(rels) { r in
                    HStack(spacing: 6) {
                        Text(r.source.name)
                            .font(.subheadline)
                            .foregroundColor(theme.textPrimary)
                        Image(systemName: r.mutual ? "arrow.left.arrow.right" : "arrow.right")
                            .font(.caption)
                            .foregroundColor(theme.textTertiary)
                        Text(r.target.name)
                            .font(.subheadline)
                            .foregroundColor(theme.textPrimary)
                        Spacer()
                        Text(r.sourceLabel)
                            .font(.caption)
                            .foregroundColor(Color(hex: r.typeColor ?? "") ?? theme.textTertiary)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    Divider().background(theme.divider)
                }
            }
        }
    }

    private func groupsCard(_ groups: [PublicGroupView]) -> some View {
        previewSection(title: String(localized: "Groups (\(groups.count))")) {
            VStack(spacing: 0) {
                if groups.isEmpty {
                    Text("No groups served")
                        .font(.footnote)
                        .foregroundColor(theme.textTertiary)
                        .padding(16)
                }
                ForEach(groups) { g in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(hex: g.color ?? "") ?? theme.accentLight)
                                .frame(width: 10, height: 10)
                            Text(g.name)
                                .font(.subheadline).fontWeight(.medium)
                                .foregroundColor(theme.textPrimary)
                        }
                        if let d = g.description, !d.isEmpty {
                            Text(d)
                                .font(.caption)
                                .foregroundColor(theme.textSecondary)
                        }
                        Text(g.members.map(\.name).joined(separator: ", "))
                            .font(.caption)
                            .foregroundColor(theme.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    Divider().background(theme.divider)
                }
            }
        }
    }

    private func previewSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
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
                .padding(.horizontal, 24)
        }
    }

    /// Public payloads only ever carry same-origin signed URLs; anything else
    /// was already stripped server-side, so a bare initials circle is the fallback.
    private func publicAvatar(url: String?, name: String, color: String?, size: CGFloat) -> some View {
        let fill = Color(hex: color ?? "") ?? theme.accentLight
        return ZStack {
            if let u = resolvedURL(url) {
                AsyncImage(url: u) { phase in
                    if case .success(let img) = phase {
                        img.resizable().scaledToFill()
                    } else {
                        initialsCircle(name, fill: fill)
                    }
                }
            } else {
                initialsCircle(name, fill: fill)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private func initialsCircle(_ name: String, fill: Color) -> some View {
        ZStack {
            fill.opacity(0.25)
            Text(String(name.prefix(2)).uppercased())
                .font(.caption2).fontWeight(.semibold)
                .foregroundColor(theme.textPrimary)
        }
    }

    private func resolvedURL(_ s: String?) -> URL? {
        guard let s, !s.isEmpty else { return nil }
        if s.hasPrefix("http") { return URL(string: s) }
        return URL(string: baseURL + s)
    }

    private func fieldValueText(_ v: AnyCodable?) -> String {
        guard let raw = v?.value, !(raw is NSNull) else { return "" }
        if let s = raw as? String { return s }
        if let b = raw as? Bool { return b ? String(localized: "Yes") : String(localized: "No") }
        if let list = raw as? [String] { return list.joined(separator: ", ") }
        return String(describing: raw)
    }
}
