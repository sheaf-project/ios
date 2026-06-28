import SwiftUI
import PhotosUI

struct MembersView: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    @State private var searchText = ""
    @Binding var showAddMember: Bool
    @State private var selectedMember: Member?
    @State private var memberToDelete: Member?
    @State private var showDeleteConfirm = false
    @State private var showDeleteAuthSheet = false
    @State private var deleteQueuedInfo: DeleteQueued?
    @State private var showDeleteQueued = false

    // Archive: nil unless the server demands step-up auth (the system's
    // archive safety category is on). Drives the prompt sheet.
    @State private var archiveAuthMember: Member?
    @State private var archiveError: String?
    @State private var showArchived = false


    private func removeMemberFromFront(_ member: Member) async {
        await store.removeMemberFromFront(member.id)
    }

    /// Active members (non-archived). The list endpoint returns archived
    /// members too; we split them so the main roster stays clean and
    /// archived members surface in their own collapsible section.
    var activeMembers: [Member] {
        store.members.filter { !$0.isArchived }
    }

    var archivedMembers: [Member] {
        store.members.filter { $0.isArchived }
    }

    var filtered: [Member] {
        if searchText.isEmpty { return activeMembers }
        return activeMembers.filter {
            ($0.displayName ?? $0.name).localizedCaseInsensitiveContains(searchText) ||
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        Group {
            if store.isLoading && store.members.isEmpty {
                ProgressView()
                    .tint(theme.accentLight)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(theme.textTertiary)
                        TextField("Search members", text: $searchText)
                            .foregroundColor(theme.textPrimary)
                            .autocorrectionDisabled()
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(theme.textTertiary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(10)
                    .background(theme.backgroundCard)
                    .cornerRadius(12)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 4, trailing: 24))

                    ForEach(filtered) { member in
                        MemberRow(member: member, isFronting: store.frontingMembers.contains(where: { $0.id == member.id })) {
                            selectedMember = member
                        } onDelete: {
                            requestDelete(member)
                        } onArchive: {
                            Task { await archive(member) }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            let isFronting = store.frontingMembers.contains(where: { $0.id == member.id })
                            if isFronting {
                                Button {
                                    Task { await removeMemberFromFront(member) }
                                } label: {
                                    Label("Remove Front", systemImage: "person.fill.xmark")
                                }
                                .tint(.orange)
                            } else {
                                Button {
                                    Task { await store.addToFront([member.id]) }
                                } label: {
                                    Label("Add to Front", systemImage: "person.fill.checkmark")
                                }
                                .tint(theme.accentLight)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                requestDelete(member)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                Task { await archive(member) }
                            } label: {
                                Label("Archive", systemImage: "archivebox")
                            }
                            .tint(.gray)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 5, leading: 24, bottom: 5, trailing: 24))
                    }

                    if !archivedMembers.isEmpty {
                        Button {
                            withAnimation { showArchived.toggle() }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: showArchived ? "chevron.down" : "chevron.right")
                                    .font(.caption)
                                Text("Archived (\(archivedMembers.count))")
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                            }
                            .foregroundColor(theme.textSecondary)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 4)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 24, bottom: 0, trailing: 24))

                        if showArchived {
                            ForEach(archivedMembers) { member in
                                ArchivedMemberRow(member: member) {
                                    selectedMember = member
                                } onUnarchive: {
                                    Task { await unarchive(member) }
                                }
                                .swipeActions(edge: .trailing) {
                                    Button {
                                        Task { await unarchive(member) }
                                    } label: {
                                        Label("Unarchive", systemImage: "tray.and.arrow.up")
                                    }
                                    .tint(theme.accentLight)
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 5, leading: 24, bottom: 5, trailing: 24))
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .background(theme.backgroundPrimary)
                .scrollContentBackground(.hidden)
                .refreshable {
                    store.loadAll()
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
            }
        }
        .background(theme.backgroundPrimary.ignoresSafeArea())
        .sheet(isPresented: $showAddMember) {
            MemberEditSheet(member: nil)
                .environmentObject(store)
        }
        .sheet(item: $selectedMember) { member in
            MemberDetailSheet(member: member)
                .environmentObject(store)
        }
        .alert("Delete this member?", isPresented: $showDeleteConfirm, presenting: memberToDelete) { member in
            Button("Delete", role: .destructive) {
                Task {
                    let queued = await store.deleteMember(id: member.id)
                    if let queued {
                        deleteQueuedInfo = queued
                        showDeleteQueued = true
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { member in
            Text("This will permanently delete \(member.displayName ?? member.name) and cannot be undone.")
        }
        .sheet(isPresented: $showDeleteAuthSheet) {
            if let member = memberToDelete {
                MemberDeleteConfirmSheet(member: member) { queued in
                    deleteQueuedInfo = queued
                    showDeleteQueued = true
                }
                .environmentObject(store)
            }
        }
        .alert("Deletion Queued", isPresented: $showDeleteQueued) {
            Button("OK", role: .cancel) { deleteQueuedInfo = nil }
        } message: {
            if let info = deleteQueuedInfo {
                Text("This deletion has been queued and will finalize \(info.finalizeAfter, style: .relative). You can cancel it from System Safety settings.")
            }
        }
        .sheet(item: $archiveAuthMember) { member in
            ArchiveAuthSheet(member: member, error: archiveError) { password, totp in
                await archiveWithCredentials(member: member, password: password, totpCode: totp)
            }
            .environmentObject(store)
        }
    }

    /// Archive a member. Try with no credentials first; the server returns
    /// 400/403 if the system's archive safety category demands step-up, in
    /// which case we surface the auth sheet and retry with creds.
    private func archive(_ member: Member) async {
        do {
            _ = try await store.archiveMember(id: member.id)
        } catch {
            let code = (error as NSError).code
            if code == 400 || code == 403 {
                archiveError = nil
                archiveAuthMember = member
            } else {
                store.errorMessage = error.userFacingMessage
            }
        }
    }

    private func archiveWithCredentials(member: Member, password: String, totpCode: String?) async -> Bool {
        let confirmation = MemberDeleteConfirm(password: password, totpCode: totpCode)
        do {
            _ = try await store.archiveMember(id: member.id, confirmation: confirmation)
            return true
        } catch {
            let code = (error as NSError).code
            if code == 400 || code == 403 {
                archiveError = "Incorrect password or authenticator code."
            } else {
                archiveError = error.userFacingMessage
            }
            return false
        }
    }

    private func unarchive(_ member: Member) async {
        do {
            _ = try await store.unarchiveMember(id: member.id)
        } catch {
            store.errorMessage = error.userFacingMessage
        }
    }

    private func requestDelete(_ member: Member) {
        memberToDelete = member
        let level = store.systemProfile?.deleteConfirmation ?? .none
        if level == .none {
            showDeleteConfirm = true
        } else {
            showDeleteAuthSheet = true
        }
    }
}

// MARK: - Member Row
struct MemberRow: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    let member: Member
    let isFronting: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    let onArchive: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                AvatarView(member: member, size: 52)
                    .overlay(alignment: .bottomTrailing) {
                        if isFronting {
                            Circle()
                                .fill(theme.success)
                                .frame(width: 12, height: 12)
                                .overlay(Circle().stroke(theme.backgroundPrimary, lineWidth: 2))
                        }
                    }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(member.displayName ?? member.name)
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundColor(theme.textPrimary)
                        if let emoji = member.emoji, !emoji.isEmpty {
                            Text(emoji).font(.caption)
                        }
                        if member.isCustomFront {
                            Text("CF")
                                .font(.caption2).fontWeight(.bold)
                                .foregroundColor(theme.textTertiary)
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background(theme.textTertiary.opacity(0.15))
                                .cornerRadius(4)
                        }
                    }
                    if let pronouns = member.pronouns, !pronouns.isEmpty {
                        Text(pronouns)
                            .font(.caption)
                            .foregroundColor(theme.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundColor(theme.textTertiary)
            }
            .padding(14)
            .background(theme.backgroundCard)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(isFronting ? member.displayColor.opacity(0.3) : theme.backgroundCard, lineWidth: 1))
        }
        .buttonStyle(ScaleButtonStyle())
        .contextMenu {
            if isFronting {
                Button {
                    Task { await removeMemberFromFront() }
                } label: {
                    Label("Remove from Front", systemImage: "person.fill.xmark")
                }
            } else {
                Button {
                    Task { await store.addToFront([member.id]) }
                } label: {
                    Label("Add to Front", systemImage: "person.fill.checkmark")
                }
                Button {
                    Task { await store.switchFronting(to: [member.id]) }
                } label: {
                    Label("Switch to \(member.displayName ?? member.name) as the only fronter", systemImage: "arrow.left.arrow.right")
                }
            }

            Divider()

            Button { onTap() } label: {
                Label("View Profile", systemImage: "person.crop.circle")
            }

            Divider()

            Button {
                onArchive()
            } label: {
                Label("Archive Member", systemImage: "archivebox")
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Member", systemImage: "trash")
            }
        }
    }

    private func removeMemberFromFront() async {
        await store.removeMemberFromFront(member.id)
    }
}

// MARK: - Archived Member Row
struct ArchivedMemberRow: View {
    @Environment(\.theme) var theme
    let member: Member
    let onTap: () -> Void
    let onUnarchive: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                AvatarView(member: member, size: 40)
                    .opacity(0.6)
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.displayName ?? member.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(theme.textSecondary)
                    Text("Archived")
                        .font(.caption2)
                        .foregroundColor(theme.textTertiary)
                }
                Spacer()
                Button {
                    onUnarchive()
                } label: {
                    Text("Unarchive")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(theme.accentLight)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(theme.backgroundCard.opacity(0.6))
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Archive Auth Sheet
/// Step-up auth sheet shown when the system's archive safety category is
/// enabled and the server demands re-authentication to archive a member.
struct ArchiveAuthSheet: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: SystemStore
    let member: Member
    let error: String?
    /// Returns true if the archive succeeded so the sheet auto-dismisses.
    let onConfirm: (String, String?) async -> Bool

    @State private var password = ""
    @State private var totp = ""
    @State private var isArchiving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("This instance requires re-authentication to archive a member.")
                        .font(.subheadline)
                        .foregroundColor(theme.textSecondary)
                }
                Section("Password") {
                    SecureField("Account password", text: $password)
                }
                Section("Authenticator code (if enabled)") {
                    TextField("123456", text: $totp)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                }
                if let error {
                    Section {
                        Text(error)
                            .font(.footnote)
                            .foregroundColor(theme.danger)
                    }
                }
            }
            .navigationTitle("Confirm Archive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isArchiving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            isArchiving = true
                            let success = await onConfirm(password, totp.isEmpty ? nil : totp)
                            isArchiving = false
                            if success { dismiss() }
                        }
                    } label: {
                        if isArchiving { ProgressView() }
                        else { Text("Archive").fontWeight(.semibold) }
                    }
                    .disabled(password.isEmpty || isArchiving)
                }
            }
        }
    }
}

// MARK: - Member Detail Sheet
struct MemberDetailSheet: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var store: SystemStore
    @Environment(\.dismiss) var dismiss
    let member: Member
    @State private var showEdit = false
    @State private var showBioRevisions = false
    @State private var fieldValues: [CustomFieldValue] = []
    @State private var loadingFields = false

    private var liveMember: Member {
        store.members.first(where: { $0.id == member.id }) ?? member
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Banner (3:1, profile-only)
                    if let banner = liveMember.bannerURL, !banner.isEmpty,
                       let url = resolveAvatarURL(banner, baseURL: store.api?.auth.baseURL ?? "") {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                Rectangle().fill(theme.backgroundCard)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .aspectRatio(3, contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Avatar + name
                    VStack(spacing: 12) {
                        AvatarView(member: liveMember, size: 96)
                        HStack(spacing: 8) {
                            Text(liveMember.displayName ?? liveMember.name)
                                .font(.title2).fontWeight(.bold).fontDesign(.rounded)
                                .foregroundColor(theme.textPrimary)
                            if let emoji = liveMember.emoji, !emoji.isEmpty {
                                Text(emoji).font(.callout)
                            }
                            if liveMember.isCustomFront {
                                Text("Custom Front")
                                    .font(.caption2).fontWeight(.bold)
                                    .foregroundColor(theme.textTertiary)
                                    .padding(.horizontal, 6).padding(.vertical, 3)
                                    .background(theme.textTertiary.opacity(0.15))
                                    .cornerRadius(6)
                            }
                        }
                        if let p = liveMember.pronouns, !p.isEmpty {
                            Text(p)
                                .padding(.horizontal, 14).padding(.vertical, 5)
                                .background(liveMember.displayColor.opacity(0.15))
                                .cornerRadius(10)
                                .foregroundColor(liveMember.displayColor)
                                .font(.subheadline)
                        }
                    }
                    .padding(.top, 20)

                    // Fronting status
                    if store.frontingMembers.contains(where: { $0.id == member.id }) {
                        Label("Currently Fronting", systemImage: "checkmark.seal.fill")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundColor(theme.success)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(theme.success.opacity(0.1))
                            .cornerRadius(12)
                    }

                    // Description
                    if let desc = liveMember.description, !desc.isEmpty {
                        MarkdownText(desc, color: theme.textSecondary)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(theme.backgroundCard)
                            .cornerRadius(14)
                    }

                    // Note
                    if let note = liveMember.note, !note.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Note", systemImage: "note.text")
                                .font(.footnote).fontWeight(.semibold)
                                .foregroundColor(theme.textSecondary)
                                .textCase(.uppercase)
                                .kerning(0.8)
                            Text(note)
                                .font(.subheadline)
                                .foregroundColor(theme.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(16)
                        .background(theme.backgroundCard)
                        .cornerRadius(14)
                    }

                    // Birthday
                    if let bday = liveMember.birthday, !bday.isEmpty {
                        HStack {
                            Label("Birthday", systemImage: "gift")
                                .font(.subheadline).fontWeight(.medium)
                                .foregroundColor(theme.textSecondary)
                            Spacer()
                            Text(bday)
                                .font(.subheadline)
                                .foregroundColor(theme.textPrimary)
                        }
                        .padding(16)
                        .background(theme.backgroundCard)
                        .cornerRadius(14)
                    }

                    // PluralKit ID
                    if let pkID = liveMember.pluralkitID, !pkID.isEmpty {
                        HStack {
                            Label("PluralKit ID", systemImage: "link")
                                .font(.subheadline).fontWeight(.medium)
                                .foregroundColor(theme.textSecondary)
                            Spacer()
                            Text(pkID)
                                .font(.subheadline.monospaced())
                                .foregroundColor(theme.textPrimary)
                        }
                        .padding(16)
                        .background(theme.backgroundCard)
                        .cornerRadius(14)
                    }

                    // Custom fields
                    if !fieldValues.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Custom Fields")
                                .font(.footnote).fontWeight(.semibold)
                                .foregroundColor(theme.textSecondary)
                                .textCase(.uppercase)
                                .kerning(0.8)

                            VStack(spacing: 0) {
                                ForEach(Array(fieldValues.enumerated()), id: \.offset) { i, fv in
                                    if let field = store.fields.first(where: { $0.id == fv.fieldID }) {
                                        HStack(alignment: .top, spacing: 12) {
                                            Text(field.name)
                                                .font(.subheadline)
                                                .foregroundColor(theme.textSecondary)
                                                .frame(width: 100, alignment: .leading)
                                            MarkdownText(displayValue(fv.value, field: field), color: theme.textPrimary)
                                                .font(.subheadline).fontWeight(.medium)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        if i < fieldValues.count - 1 {
                                            Divider().background(theme.divider).padding(.leading, 16)
                                        }
                                    }
                                }
                            }
                            .background(theme.backgroundCard)
                            .cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.border, lineWidth: 1))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else if loadingFields {
                        ProgressView().tint(theme.accentLight)
                    }

                    // Switch to button
                    Button {
                        Task {
                            await store.switchFronting(to: [member.id])
                            dismiss()
                        }
                    } label: {
                        Label("Switch to \(liveMember.displayName ?? liveMember.name)", systemImage: "arrow.left.arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(theme.accentLight)
                    .padding(.bottom, 40)
                }
                .padding(.horizontal, 24)
            }
            .background(theme.backgroundPrimary)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(theme.accentLight)
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        showBioRevisions = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(theme.accentLight)
                    }
                    .accessibilityLabel("Bio History")

                    Button {
                        showEdit = true
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundColor(theme.accentLight)
                    }
                    .accessibilityLabel("Edit")
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            MemberEditSheet(member: liveMember)
                .environmentObject(store)
        }
        .sheet(isPresented: $showBioRevisions) {
            MemberBioRevisionsView(member: liveMember)
                .environmentObject(store)
        }
        .presentationDragIndicator(.visible)
        .task {
            await loadFieldValues()
        }
    }

    private func loadFieldValues() async {
        loadingFields = true
        fieldValues = await store.getMemberFieldValues(memberID: member.id)
        loadingFields = false
    }

    private func displayValue(_ value: AnyCodable, field: CustomField) -> String {
        if value.value is NSNull { return "—" }
        switch field.fieldType {
        case .boolean:
            if let b = value.value as? Bool { return b ? "Yes" : "No" }
        case .date:
            if let s = value.value as? String, !s.isEmpty {
                let inFmt = DateFormatter()
                inFmt.dateFormat = "yyyy-MM-dd"
                if let d = inFmt.date(from: s) {
                    let outFmt = DateFormatter()
                    outFmt.dateStyle = .medium
                    return outFmt.string(from: d)
                }
                return s
            }
        case .multiselect:
            if let arr = value.value as? [String] {
                return arr.isEmpty ? "—" : arr.joined(separator: ", ")
            }
        default: break
        }
        if let s = value.value as? String, !s.isEmpty { return s }
        if let n = value.value as? Int { return "\(n)" }
        if let d = value.value as? Double { return String(format: "%g", d) }
        return "—"
    }

    func infoSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.footnote).fontWeight(.semibold)
                .foregroundColor(theme.textSecondary)
                .textCase(.uppercase)
                .kerning(0.8)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Member Edit Sheet
struct MemberEditSheet: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var store: SystemStore
    @Environment(\.dismiss) var dismiss
    let member: Member?

    @State private var name = ""
    @State private var displayName = ""
    @State private var pronouns = ""
    @State private var description = ""
    @State private var avatarURL = ""
    @State private var bannerURL = ""
    @State private var colorHex = "#A78BFA"
    @State private var birthday = ""
    @State private var emoji = ""
    @State private var note = ""
    @State private var isCustomFront = false
    @State private var privacy: PrivacyLevel = .private
    @State private var isSaving = false
    // Staged per-field values; AnyCodable wraps the type-erased server
    // value (Bool / Int / Double / String / [String] / NSNull-for-cleared).
    // Save() diffs against `fieldValuesBaseline` so unchanged fields don't
    // re-rotate server-side ciphertext or audit history.
    @State private var fieldValues: [String: AnyCodable] = [:]
    @State private var fieldValuesBaseline: [String: AnyCodable] = [:]
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isUploadingAvatar = false
    @State private var avatarMode: AvatarInputMode = .url
    @State private var selectedBannerPhoto: PhotosPickerItem?
    @State private var isUploadingBanner = false
    @State private var bannerCropImage: UIImage?

    // Load-time snapshots of form fields + staged field values used to
    // detect unsaved changes when the user tries to leave the editor.
    @State private var formBaseline: FormSnapshot?
    @State private var showUnsavedAlert = false

    private struct FormSnapshot: Equatable {
        var name: String
        var displayName: String
        var pronouns: String
        var description: String
        var avatarURL: String
        var bannerURL: String
        var colorHex: String
        var birthday: String
        var emoji: String
        var note: String
        var isCustomFront: Bool
        var privacy: PrivacyLevel
    }

    private var currentSnapshot: FormSnapshot {
        FormSnapshot(
            name: name, displayName: displayName, pronouns: pronouns,
            description: description, avatarURL: avatarURL, bannerURL: bannerURL,
            colorHex: colorHex, birthday: birthday, emoji: emoji, note: note,
            isCustomFront: isCustomFront, privacy: privacy
        )
    }

    private var isDirty: Bool {
        guard let baseline = formBaseline else { return false }
        if baseline != currentSnapshot { return true }
        // Compare staged custom-field values against the load-time baseline.
        // Treat NSNull-staged vs absent baseline as no-change so a brand-new
        // edit that immediately gets cleared doesn't count as dirty.
        let keys = Set(fieldValues.keys).union(fieldValuesBaseline.keys)
        for key in keys {
            if !customFieldValuesEqual(fieldValues[key], fieldValuesBaseline[key]) {
                return true
            }
        }
        return false
    }

    var isNew: Bool { member == nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    BannerInputSection(
                        bannerURL: $bannerURL,
                        selectedPhoto: $selectedBannerPhoto,
                        isUploading: $isUploadingBanner,
                        cropImage: $bannerCropImage,
                        api: store.api
                    )

                    formField("Name *", value: $name, placeholder: "member-name")
                    formField("Display Name", value: $displayName, placeholder: "Shown to others")
                    formField("Pronouns", value: $pronouns, placeholder: "e.g. she/her")
                    formField("Emoji", value: $emoji, placeholder: "e.g. ✨")
                    formField("Description", value: $description, placeholder: "Brief description", multiline: true)
                    formField("Note", value: $note, placeholder: "Private note (only visible to you)", multiline: true)

                    // Custom front toggle
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Custom Front")
                                .font(.subheadline).fontWeight(.medium)
                                .foregroundColor(theme.textPrimary)
                            Text("Non-counting fronter (e.g. Asleep, Away)")
                                .font(.caption)
                                .foregroundColor(theme.textTertiary)
                        }
                        Spacer()
                        Toggle("", isOn: $isCustomFront)
                            .tint(theme.accentLight)
                            .labelsHidden()
                    }
                    .padding(14)
                    .background(theme.backgroundCard)
                    .cornerRadius(12)

                    // Birthday
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Birthday")
                            .font(.footnote).fontWeight(.semibold)
                            .foregroundColor(theme.textSecondary)
                        HStack {
                            DatePicker(
                                "",
                                selection: Binding(
                                    get: {
                                        let fmt = DateFormatter()
                                        fmt.dateFormat = "yyyy-MM-dd"
                                        return fmt.date(from: birthday) ?? Date()
                                    },
                                    set: {
                                        let fmt = DateFormatter()
                                        fmt.dateFormat = "yyyy-MM-dd"
                                        birthday = fmt.string(from: $0)
                                    }
                                ),
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                            .tint(theme.accentLight)
                            .labelsHidden()
                            .disabled(birthday.isEmpty)
                            .opacity(birthday.isEmpty ? 0.4 : 1)

                            Spacer()

                            if birthday.isEmpty {
                                Button("Set") {
                                    let fmt = DateFormatter()
                                    fmt.dateFormat = "yyyy-MM-dd"
                                    birthday = fmt.string(from: Date())
                                }
                                .font(.subheadline).fontWeight(.medium)
                                .foregroundColor(theme.accentLight)
                            } else {
                                Button("Clear") {
                                    birthday = ""
                                }
                                .font(.subheadline).fontWeight(.medium)
                                .foregroundColor(theme.textSecondary)
                            }
                        }
                        .padding(12)
                        .background(theme.backgroundCard)
                        .cornerRadius(12)
                    }

                    // Avatar section
                    AvatarInputSection(
                        avatarURL: $avatarURL,
                        mode: $avatarMode,
                        selectedPhoto: $selectedPhoto,
                        isUploading: $isUploadingAvatar,
                        api: store.api
                    )

                    // Color picker
                    HStack {
                        Text("Color")
                            .font(.subheadline).fontWeight(.medium)
                            .foregroundColor(theme.textSecondary)
                        Spacer()
                        ColorPicker("", selection: Binding(
                            get: { Color(hex: colorHex) ?? .purple },
                            set: { colorHex = $0.toHex() }
                        ))
                        .labelsHidden()
                    }
                    .padding(14)
                    .background(theme.backgroundCard)
                    .cornerRadius(12)

                    // Privacy picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Privacy")
                            .font(.footnote).fontWeight(.semibold)
                            .foregroundColor(theme.textSecondary)
                        Picker("Privacy", selection: $privacy) {
                            ForEach(PrivacyLevel.allCases, id: \.self) { level in
                                Text(level.rawValue.capitalized).tag(level)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Custom fields
                    if !store.fields.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Custom Fields")
                                .font(.footnote).fontWeight(.semibold)
                                .foregroundColor(theme.textSecondary)
                            ForEach(store.fields) { field in
                                customFieldEditor(field)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 80)
            }
            .background(theme.backgroundPrimary)
            .navigationTitle(isNew ? "Add Member" : "Edit Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { attemptDismiss() }
                        .foregroundColor(theme.accentLight)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: save) {
                        if isSaving { ProgressView().tint(theme.accentLight) }
                        else {
                            Text("Save")
                                .fontWeight(.semibold)
                                .foregroundColor(name.isEmpty ? theme.textTertiary : theme.accentLight)
                        }
                    }
                    .disabled(name.isEmpty || isSaving)
                }
            }
        }
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isDirty)
        .onAppear { populateFields() }
        .confirmationDialog(
            "You have unsaved changes to this member.",
            isPresented: $showUnsavedAlert,
            titleVisibility: .visible
        ) {
            Button("Save and Exit") { save() }
                .disabled(name.isEmpty || isSaving)
            Button("Discard Changes", role: .destructive) { dismiss() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func attemptDismiss() {
        if isDirty { showUnsavedAlert = true } else { dismiss() }
    }

    func populateFields() {
        guard let m = member else {
            // New-member sheet: snapshot the empty form as baseline so any
            // typed input flips dirty.
            formBaseline = currentSnapshot
            return
        }
        name          = m.name
        displayName   = m.displayName ?? ""
        pronouns      = m.pronouns ?? ""
        description   = m.description ?? ""
        avatarURL     = m.avatarURL ?? ""
        bannerURL     = m.bannerURL ?? ""
        if avatarURL.hasPrefix("/") { avatarMode = .upload }
        colorHex      = m.color ?? "#A78BFA"
        birthday      = m.birthday ?? ""
        emoji         = m.emoji ?? ""
        note          = m.note ?? ""
        isCustomFront = m.isCustomFront
        privacy       = m.privacy
        formBaseline  = currentSnapshot
        // Load existing field values. Server omits fields the viewer
        // isn't allowed to see — those keys won't be in the map.
        Task {
            guard let memberID = member?.id else { return }
            let values = await store.getMemberFieldValues(memberID: memberID)
            await MainActor.run {
                var byID: [String: AnyCodable] = [:]
                for v in values { byID[v.fieldID] = v.value }
                fieldValues = byID
                fieldValuesBaseline = byID
            }
        }
    }

    func formField(_ label: String, value: Binding<String>, placeholder: String, multiline: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.footnote).fontWeight(.semibold).foregroundColor(theme.textSecondary)
            if multiline {
                TextField(placeholder, text: value, axis: .vertical)
                    .lineLimit(3...6)
                    .padding(12).background(theme.backgroundCard).cornerRadius(12).foregroundColor(theme.textPrimary)
            } else {
                TextField(placeholder, text: value)
                    .autocorrectionDisabled().autocapitalization(.none)
                    .padding(12).background(theme.backgroundCard).cornerRadius(12).foregroundColor(theme.textPrimary)
            }
        }
    }

    func save() {
        isSaving = true
        let create = MemberCreate(
            name: name,
            displayName: displayName.isEmpty ? nil : displayName,
            description: description.isEmpty ? nil : description,
            pronouns: pronouns.isEmpty ? nil : pronouns,
            avatarURL: avatarURL.isEmpty ? nil : avatarURL,
            bannerURL: bannerURL.isEmpty ? nil : bannerURL,
            color: colorHex.isEmpty ? nil : colorHex,
            birthday: birthday.isEmpty ? nil : birthday,
            emoji: emoji.isEmpty ? nil : emoji,
            isCustomFront: isCustomFront,
            privacy: privacy,
            note: note.isEmpty ? nil : note
        )
        Task {
            await store.saveMember(existing: member, create: create)
            // Diff staged values against the load-time baseline so an
            // unchanged field doesn't re-rotate its server-side ciphertext
            // or audit row. Editor stores NSNull to signal "clear".
            if let memberID = member?.id ?? store.members.last?.id {
                var sets: [CustomFieldValueSet] = []
                for (fieldID, value) in fieldValues {
                    if !customFieldValuesEqual(value, fieldValuesBaseline[fieldID]) {
                        sets.append(CustomFieldValueSet(fieldID: fieldID, value: value))
                    }
                }
                if !sets.isEmpty {
                    await store.setMemberFieldValues(memberID: memberID, values: sets)
                }
            }
            isSaving = false
            dismiss()
        }
    }

    // Equality across the type-erased values the wire carries. An
    // explicit NSNull stage compared to an absent baseline reads as
    // "no change" so we don't ping the server for a no-op clear.
    private func customFieldValuesEqual(_ a: AnyCodable?, _ b: AnyCodable?) -> Bool {
        let av: Any? = a?.value
        let bv: Any? = b?.value
        let aIsNullish = av == nil || av is NSNull
        let bIsNullish = bv == nil || bv is NSNull
        if aIsNullish && bIsNullish { return true }
        if aIsNullish != bIsNullish { return false }
        switch (av, bv) {
        case let (l as Bool, r as Bool):       return l == r
        case let (l as Int, r as Int):         return l == r
        case let (l as Double, r as Double):   return l == r
        case let (l as String, r as String):   return l == r
        case let (l as [String], r as [String]): return l == r
        default: return false
        }
    }

    // Dispatch to the right input widget per field type. Mirrors the
    // Android `CustomFieldEditor` composable. Choices on a select /
    // multiselect collapse to nil = freeform input.
    @ViewBuilder
    func customFieldEditor(_ field: CustomField) -> some View {
        let choices = field.options?.choices
        let hasChoices = !(choices?.isEmpty ?? true)

        VStack(alignment: .leading, spacing: 6) {
            // Boolean shows the label inline with the switch — every
            // other type gets the label above its input.
            if field.fieldType != .boolean {
                Text(field.name)
                    .font(.footnote).fontWeight(.semibold)
                    .foregroundColor(theme.textSecondary)
            }

            switch field.fieldType {
            case .text:
                cfTextEditor(field: field)
            case .number:
                cfNumberEditor(field: field)
            case .date:
                cfDateEditor(field: field)
            case .boolean:
                cfBooleanEditor(field: field)
            case .select:
                if hasChoices, let choices {
                    cfSelectChoiceEditor(field: field, choices: choices)
                } else {
                    cfTextEditor(field: field)
                }
            case .multiselect:
                if hasChoices, let choices {
                    cfMultiselectChoiceEditor(field: field, choices: choices)
                } else {
                    MultiselectFreeformEditor(field: field, values: $fieldValues)
                }
            }
        }
    }

    // MARK: Per-type custom field editors

    private func cfTextEditor(field: CustomField) -> some View {
        TextField(field.name, text: Binding(
            get: { (fieldValues[field.id]?.value as? String) ?? "" },
            set: { newVal in
                if newVal.isEmpty { fieldValues[field.id] = AnyCodable(NSNull()) }
                else { fieldValues[field.id] = AnyCodable(newVal) }
            }
        ))
        .autocorrectionDisabled()
        .padding(12).background(theme.backgroundCard).cornerRadius(12)
        .foregroundColor(theme.textPrimary)
    }

    private func cfNumberEditor(field: CustomField) -> some View {
        TextField("0", text: Binding(
            get: {
                switch fieldValues[field.id]?.value {
                case let v as Int:    return "\(v)"
                case let v as Double: return String(format: "%g", v)
                case let v as String: return v
                default: return ""
                }
            },
            set: { raw in
                let trimmed = raw.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty {
                    fieldValues[field.id] = AnyCodable(NSNull())
                } else if let i = Int(trimmed) {
                    fieldValues[field.id] = AnyCodable(i)
                } else if let d = Double(trimmed) {
                    fieldValues[field.id] = AnyCodable(d)
                } else {
                    // Keep the raw string while the user types intermediates
                    // ("3.", "-", "1e"). Server would 422 these, but save()
                    // path won't fire until they finish typing.
                    fieldValues[field.id] = AnyCodable(trimmed)
                }
            }
        ))
        .keyboardType(.decimalPad)
        .padding(12).background(theme.backgroundCard).cornerRadius(12)
        .foregroundColor(theme.textPrimary)
    }

    private func cfDateEditor(field: CustomField) -> some View {
        let isoFmt: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            return f
        }()
        let current = fieldValues[field.id]?.value as? String
        let parsed = current.flatMap { isoFmt.date(from: $0) }

        return HStack {
            DatePicker(
                "",
                selection: Binding(
                    get: { parsed ?? Date() },
                    set: { fieldValues[field.id] = AnyCodable(isoFmt.string(from: $0)) }
                ),
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .tint(theme.accentLight)
            .labelsHidden()
            .disabled(parsed == nil)
            .opacity(parsed == nil ? 0.4 : 1)

            Spacer()

            if parsed == nil {
                Button("Set") {
                    fieldValues[field.id] = AnyCodable(isoFmt.string(from: Date()))
                }
                .font(.subheadline).fontWeight(.medium)
                .foregroundColor(theme.accentLight)
            } else {
                Button("Clear") {
                    fieldValues[field.id] = AnyCodable(NSNull())
                }
                .font(.subheadline).fontWeight(.medium)
                .foregroundColor(theme.textSecondary)
            }
        }
        .padding(12).background(theme.backgroundCard).cornerRadius(12)
    }

    private func cfBooleanEditor(field: CustomField) -> some View {
        HStack {
            Text(field.name)
                .font(.subheadline).fontWeight(.medium)
                .foregroundColor(theme.textPrimary)
            Spacer()
            Toggle("", isOn: Binding(
                get: { (fieldValues[field.id]?.value as? Bool) == true },
                set: { fieldValues[field.id] = AnyCodable($0) }
            ))
            .tint(theme.accentLight)
            .labelsHidden()
        }
        .padding(12).background(theme.backgroundCard).cornerRadius(12)
    }

    private func cfSelectChoiceEditor(field: CustomField, choices: [String]) -> some View {
        let current = fieldValues[field.id]?.value as? String
        return Menu {
            // Sentinel "(none)" row clears the value — matches the
            // explicit-clear convention used elsewhere.
            Button("(none)") {
                fieldValues[field.id] = AnyCodable(NSNull())
            }
            ForEach(choices, id: \.self) { choice in
                Button(choice) {
                    fieldValues[field.id] = AnyCodable(choice)
                }
            }
        } label: {
            HStack {
                Text(current?.isEmpty == false ? current! : "(none)")
                    .foregroundColor(current?.isEmpty == false ? theme.textPrimary : theme.textTertiary)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundColor(theme.textTertiary)
            }
            .padding(12).background(theme.backgroundCard).cornerRadius(12)
        }
    }

    private func cfMultiselectChoiceEditor(field: CustomField, choices: [String]) -> some View {
        let selected = Set((fieldValues[field.id]?.value as? [String]) ?? [])
        return ChipWrapLayout(spacing: 6) {
            ForEach(choices, id: \.self) { choice in
                let isSelected = selected.contains(choice)
                Button {
                    var next = selected
                    if isSelected { next.remove(choice) } else { next.insert(choice) }
                    // Empty -> nil so the server clears rather than persisting [].
                    if next.isEmpty {
                        fieldValues[field.id] = AnyCodable(NSNull())
                    } else {
                        // Preserve choices order rather than Set's arbitrary order.
                        let ordered = choices.filter { next.contains($0) }
                        fieldValues[field.id] = AnyCodable(ordered)
                    }
                } label: {
                    Text(choice)
                        .font(.subheadline).fontWeight(.medium)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(isSelected ? theme.accentSoft : theme.backgroundCard)
                        .foregroundColor(isSelected ? theme.accent : theme.textPrimary)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(isSelected ? theme.accent.opacity(0.25) : theme.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Chip Wrap Layout
// Simple wrap layout for chip rows — places subviews left-to-right and
// breaks to the next line when out of width. iOS 16+ Layout protocol.
private struct ChipWrapLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)
            if lineWidth + size.width > width, lineWidth > 0 {
                totalHeight += lineHeight + spacing
                lineWidth = 0
                lineHeight = 0
            }
            lineWidth += size.width + (lineWidth > 0 ? spacing : 0)
            lineHeight = max(lineHeight, size.height)
        }
        totalHeight += lineHeight
        return CGSize(width: width.isFinite ? width : lineWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0
        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            sv.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

// MARK: - Multiselect Freeform Editor
// Chip group + inline TextField for freeform multiselect fields (no
// predefined choices). Three ways to commit a tag: Return key, tap +,
// or type a comma. Empty state shows a visible "No tags yet" hint so
// the editor doesn't look like a plain text field. Empty list collapses
// to NSNull on save so the server clears the value rather than
// persisting [].
private struct MultiselectFreeformEditor: View {
    @Environment(\.theme) var theme
    let field: CustomField
    @Binding var values: [String: AnyCodable]
    @State private var draft = ""
    @FocusState private var inputFocused: Bool

    private var currentTags: [String] {
        (values[field.id]?.value as? [String]) ?? []
    }

    private func commit(_ raw: String) {
        let tag = raw.trimmingCharacters(in: .whitespaces)
        guard !tag.isEmpty else { draft = ""; return }
        if currentTags.contains(tag) { draft = ""; return }
        values[field.id] = AnyCodable(currentTags + [tag])
        draft = ""
        // Re-focus so chained "type tag, Done, type tag, Done" stays smooth
        // — without this, the keyboard hides between submits on some setups.
        inputFocused = true
    }

    private func remove(_ tag: String) {
        let next = currentTags.filter { $0 != tag }
        values[field.id] = next.isEmpty ? AnyCodable(NSNull()) : AnyCodable(next)
    }

    // Comma triggers commit so users can rapid-fire "alpha, beta, gamma".
    // We strip the comma before committing so it doesn't end up inside
    // the tag.
    private func onDraftChange(_ newValue: String) {
        guard newValue.contains(",") else { return }
        let parts = newValue.split(separator: ",", omittingEmptySubsequences: false)
        let trailing = String(parts.last ?? "")
        for part in parts.dropLast() {
            commit(String(part))
        }
        draft = trailing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Chip strip — always visible, with an empty-state hint so the
            // editor looks like a tag input from the moment it opens
            // rather than a plain text field.
            if currentTags.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "tag")
                        .font(.caption)
                        .foregroundColor(theme.textTertiary)
                    Text("No tags yet")
                        .font(.caption).italic()
                        .foregroundColor(theme.textTertiary)
                }
                .padding(.vertical, 6)
            } else {
                ChipWrapLayout(spacing: 6) {
                    ForEach(currentTags, id: \.self) { tag in
                        Button { remove(tag) } label: {
                            HStack(spacing: 4) {
                                Text(tag)
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                            }
                            .font(.subheadline).fontWeight(.medium)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(theme.accentSoft)
                            .foregroundColor(theme.accent)
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(theme.accent.opacity(0.25), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Input row. Leading + icon makes the affordance explicit even
            // before the user types anything; the trailing Add button
            // becomes the prominent action once a draft exists.
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundColor(theme.accentLight)
                TextField("Type a tag, press return", text: $draft)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.done)
                    .focused($inputFocused)
                    .onSubmit { commit(draft) }
                    .onChange(of: draft) { _, new in onDraftChange(new) }
                    .foregroundColor(theme.textPrimary)
                if !draft.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button {
                        commit(draft)
                    } label: {
                        Text("Add")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundColor(theme.accentLight)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(theme.backgroundCard)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(inputFocused ? theme.accentLight : theme.border, lineWidth: 1)
            )
        }
    }
}

// MARK: - Avatar Input Mode
enum AvatarInputMode {
    case url
    case upload
}

// MARK: - Avatar Input Section
struct AvatarInputSection: View {
    @Environment(\.theme) var theme
    @Binding var avatarURL: String
    @Binding var mode: AvatarInputMode
    @Binding var selectedPhoto: PhotosPickerItem?
    @Binding var isUploading: Bool
    var api: APIClient?
    @State private var uploadError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Avatar")
                .font(.footnote).fontWeight(.semibold)
                .foregroundColor(theme.textSecondary)

            // Preview
            if !avatarURL.isEmpty, let url = resolveAvatarURL(avatarURL, baseURL: api?.auth.baseURL ?? "") {
                HStack {
                    Spacer()
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                                .frame(width: 72, height: 72)
                                .clipShape(Circle())
                        case .failure:
                            Circle().fill(theme.backgroundCard)
                                .frame(width: 72, height: 72)
                                .overlay(
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(theme.textTertiary)
                                )
                        default:
                            Circle().fill(theme.backgroundCard)
                                .frame(width: 72, height: 72)
                                .overlay(ProgressView().tint(theme.accentLight))
                        }
                    }
                    Spacer()
                }
                .padding(.bottom, 4)
            }

            // Mode picker
            Picker("", selection: $mode) {
                Text("Upload Image").tag(AvatarInputMode.upload)
                Text("Enter URL").tag(AvatarInputMode.url)
            }
            .pickerStyle(.segmented)

            switch mode {
            case .upload:
                HStack(spacing: 12) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        HStack(spacing: 8) {
                            if isUploading {
                                ProgressView().tint(.white).scaleEffect(0.8)
                            } else {
                                Image(systemName: "photo.on.rectangle.angled")
                            }
                            Text(isUploading ? "Uploading..." : "Choose Photo")
                                .font(.subheadline).fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(theme.accentLight)
                        .cornerRadius(12)
                    }
                    .disabled(isUploading)
                    .onChange(of: selectedPhoto) { _, newItem in
                        guard let newItem else { return }
                        Task { await uploadPhoto(newItem) }
                    }

                    if !avatarURL.isEmpty {
                        Button {
                            avatarURL = ""
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(theme.danger)
                                .padding(12)
                                .background(theme.danger.opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                }
            case .url:
                HStack(spacing: 8) {
                    let displayBinding = Binding<String>(
                        get: { avatarURL.hasPrefix("/") ? "" : avatarURL },
                        set: { avatarURL = $0 }
                    )
                    TextField("https://...", text: displayBinding)
                        .autocorrectionDisabled()
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                        .padding(12)
                        .background(theme.backgroundCard)
                        .cornerRadius(12)
                        .foregroundColor(theme.textPrimary)

                    if !avatarURL.isEmpty {
                        Button {
                            avatarURL = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(theme.textTertiary)
                        }
                    }
                }
            }

            if let uploadError {
                Text(uploadError)
                    .font(.footnote)
                    .foregroundColor(theme.danger)
            }
        }
    }

    private func uploadPhoto(_ item: PhotosPickerItem) async {
        isUploading = true
        uploadError = nil
        defer { isUploading = false }

        guard let data = try? await item.loadTransferable(type: Data.self),
              let api else { return }

        // Determine MIME type
        let mimeType: String
        if let uti = item.supportedContentTypes.first {
            if uti.conforms(to: .png) {
                mimeType = "image/png"
            } else if uti.conforms(to: .gif) {
                mimeType = "image/gif"
            } else if uti.conforms(to: .webP) {
                mimeType = "image/webp"
            } else {
                mimeType = "image/jpeg"
            }
        } else {
            mimeType = "image/jpeg"
        }

        do {
            let url = try await api.uploadFile(imageData: data, mimeType: mimeType)
            await MainActor.run {
                if !url.isEmpty {
                    avatarURL = url
                }
                selectedPhoto = nil
            }
        } catch is CancellationError {
            await MainActor.run { selectedPhoto = nil }
        } catch {
            await MainActor.run {
                uploadError = error.userFacingMessage
                selectedPhoto = nil
            }
        }
    }
}

// MARK: - Banner Input Section
struct BannerInputSection: View {
    @Environment(\.theme) var theme
    @Binding var bannerURL: String
    @Binding var selectedPhoto: PhotosPickerItem?
    @Binding var isUploading: Bool
    @Binding var cropImage: UIImage?
    var api: APIClient?
    @State private var uploadError: String?
    @State private var showPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Banner")
                .font(.footnote).fontWeight(.semibold)
                .foregroundColor(theme.textSecondary)

            ZStack(alignment: .bottomTrailing) {
                Group {
                    if !bannerURL.isEmpty,
                       let url = resolveAvatarURL(bannerURL, baseURL: api?.auth.baseURL ?? "") {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            case .failure:
                                bannerPlaceholder
                            default:
                                ProgressView().tint(theme.accentLight)
                            }
                        }
                    } else {
                        bannerPlaceholder
                    }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(3, contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .contentShape(RoundedRectangle(cornerRadius: 12))
                .onTapGesture {
                    if !isUploading { showPicker = true }
                }

                Menu {
                    Button {
                        showPicker = true
                    } label: {
                        Label("Choose Photo", systemImage: "photo")
                    }
                    if !bannerURL.isEmpty {
                        Button(role: .destructive) {
                            bannerURL = ""
                        } label: {
                            Label("Remove Banner", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "pencil")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.black.opacity(0.55))
                        .clipShape(Circle())
                        .padding(10)
                }
                .disabled(isUploading)

                if isUploading {
                    ZStack {
                        Color.black.opacity(0.4)
                        ProgressView().tint(.white)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .allowsHitTesting(false)
                }
            }

            if let uploadError {
                Text(uploadError)
                    .font(.footnote)
                    .foregroundColor(theme.danger)
            }
        }
        .photosPicker(isPresented: $showPicker, selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) { _, newItem in
            guard let newItem else { return }
            Task { await pickPhoto(newItem) }
        }
        .sheet(item: Binding<CropImage?>(
            get: { cropImage.map(CropImage.init) },
            set: { if $0 == nil { cropImage = nil } }
        )) { wrapper in
            ImageCropperView(
                sourceImage: wrapper.image,
                aspectRatio: 3.0,
                cropShape: .roundedRect(cornerRadius: 12),
                title: "Crop Banner",
                onConfirm: { data in
                    Task { await uploadCropped(data: data) }
                }
            )
        }
    }

    private var bannerPlaceholder: some View {
        ZStack {
            Rectangle().fill(theme.backgroundCard)
            HStack(spacing: 6) {
                Image(systemName: "photo")
                Text("Add Banner")
            }
            .font(.subheadline.weight(.medium))
            .foregroundColor(theme.textTertiary)
        }
    }

    private func pickPhoto(_ item: PhotosPickerItem) async {
        uploadError = nil
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            await MainActor.run { selectedPhoto = nil }
            return
        }
        let decoded = UIImage.decodeForCrop(data: data) ?? UIImage(data: data)
        await MainActor.run {
            cropImage = decoded
            selectedPhoto = nil
        }
    }

    private func uploadCropped(data: Data) async {
        await MainActor.run { isUploading = true }
        defer { Task { @MainActor in isUploading = false } }
        guard let api else { return }
        do {
            let url = try await api.uploadFile(imageData: data, mimeType: "image/png", purpose: "banner")
            await MainActor.run {
                if !url.isEmpty { bannerURL = url }
            }
        } catch {
            await MainActor.run { uploadError = error.userFacingMessage }
        }
    }
}

private struct CropImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

// MARK: - Member Delete Confirmation Sheet
struct MemberDeleteConfirmSheet: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var store: SystemStore
    @Environment(\.dismiss) var dismiss
    let member: Member
    var onQueued: ((DeleteQueued) -> Void)?

    @State private var password = ""
    @State private var totpCode = ""
    @State private var isDeleting = false
    @State private var errorMessage: String?

    private var level: DeleteConfirmation {
        store.systemProfile?.deleteConfirmation ?? .none
    }

    private var needsPassword: Bool {
        level == .password || level == .both
    }

    private var needsTOTP: Bool {
        level == .totp || level == .both
    }

    private var canSubmit: Bool {
        (!needsPassword || !password.isEmpty) && (!needsTOTP || totpCode.count == 6)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Deleting \(member.displayName ?? member.name)")
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundColor(theme.textPrimary)

                    Text("Deletion protection is enabled. Please verify your identity to continue.")
                        .font(.subheadline)
                        .foregroundColor(theme.textSecondary)
                        .multilineTextAlignment(.center)

                    if needsPassword {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Password").font(.footnote).fontWeight(.semibold).foregroundColor(theme.textSecondary)
                            SecureField("Enter your password", text: $password)
                                .autocorrectionDisabled().textContentType(.password)
                                .padding(14).background(theme.backgroundCard).cornerRadius(12).foregroundColor(theme.textPrimary)
                        }
                    }

                    if needsTOTP {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("TOTP Code").font(.footnote).fontWeight(.semibold).foregroundColor(theme.textSecondary)
                            TextField("6-digit code", text: $totpCode)
                                .keyboardType(.numberPad).textContentType(.oneTimeCode)
                                .padding(14).background(theme.backgroundCard).cornerRadius(12).foregroundColor(theme.textPrimary)
                                .onChange(of: totpCode) { _, newValue in
                                    totpCode = String(newValue.prefix(6)).filter(\.isNumber)
                                }
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundColor(theme.danger)
                    }

                    Button {
                        performDelete()
                    } label: {
                        HStack {
                            if isDeleting {
                                ProgressView().tint(.white).scaleEffect(0.8)
                            }
                            Text("Delete Member")
                                .font(.subheadline).fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(canSubmit && !isDeleting ? theme.danger : theme.danger.opacity(0.4))
                        .cornerRadius(14)
                    }
                    .disabled(!canSubmit || isDeleting)
                }
                .padding(.horizontal, 24).padding(.top, 24)
            }
            .background(theme.backgroundPrimary)
            .navigationTitle("Confirm Deletion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(theme.accentLight)
                }
            }
        }
    }

    private func performDelete() {
        isDeleting = true
        errorMessage = nil
        let confirmation = MemberDeleteConfirm(
            password: needsPassword ? password : nil,
            totpCode: needsTOTP ? totpCode : nil
        )
        Task {
            let queued = await store.deleteMember(id: member.id, confirmation: confirmation)
            await MainActor.run {
                isDeleting = false
                if let queued {
                    dismiss()
                    onQueued?(queued)
                } else if !store.members.contains(where: { $0.id == member.id }) {
                    dismiss()
                } else {
                    errorMessage = "Deletion failed. Please check your credentials and try again."
                }
            }
        }
    }
}

// MARK: - Member Bio Revisions View

struct MemberBioRevisionsView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var store: SystemStore
    @Environment(\.dismiss) var dismiss
    let member: Member
    @State private var revisions: [ContentRevision] = []
    @State private var isLoading = true
    @State private var selectedRevision: ContentRevision?

    private var sortedRevisions: [ContentRevision] {
        revisions.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            return a.createdAt > b.createdAt
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView().tint(theme.accentLight)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if revisions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.largeTitle)
                            .foregroundColor(theme.textTertiary)
                        Text("No revisions")
                            .font(.body).fontWeight(.medium).fontDesign(.rounded)
                            .foregroundColor(theme.textTertiary)
                        Text("Revisions are created when the bio is edited.")
                            .font(.footnote)
                            .foregroundColor(theme.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(sortedRevisions) { revision in
                            Button {
                                selectedRevision = revision
                            } label: {
                                RevisionRow(revision: revision)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 5, leading: 24, bottom: 5, trailing: 24))
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(theme.backgroundPrimary)
            .navigationTitle("Bio History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(theme.accentLight)
                }
            }
        }
        .sheet(item: $selectedRevision) { revision in
            MemberBioRevisionDetailView(member: member, revision: revision, onPinChanged: { updated in
                if let idx = revisions.firstIndex(where: { $0.id == updated.id }) {
                    revisions[idx] = updated
                }
            }) {
                dismiss()
            }
            .environmentObject(store)
        }
        .task { await loadRevisions() }
    }

    func loadRevisions() async {
        isLoading = true
        if let fetched = try? await store.api?.getMemberBioRevisions(memberID: member.id) {
            revisions = fetched
        }
        isLoading = false
    }
}

// MARK: - Member Bio Revision Detail View

struct MemberBioRevisionDetailView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var store: SystemStore
    @Environment(\.dismiss) var dismiss
    let member: Member
    let revision: ContentRevision
    var onPinChanged: ((ContentRevision) -> Void)?
    var onRestored: (() -> Void)?
    @State private var showRestoreConfirm = false
    @State private var isRestoring = false
    @State private var isPinned: Bool = false
    @State private var isPinLoading = false
    @State private var pinError: String?
    @State private var showUnpinConfirm = false
    @State private var showUnpinAuth = false
    @State private var unpinQueued: DeleteQueued?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar")
                                .font(.caption)
                                .foregroundColor(theme.textTertiary)
                            Text(revision.createdAt, format: .dateTime.month(.wide).day().year().hour().minute())
                                .font(.subheadline)
                                .foregroundColor(theme.textSecondary)
                        }
                        if !revision.editorMemberNames.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "person.fill")
                                    .font(.caption)
                                    .foregroundColor(theme.textTertiary)
                                Text(revision.editorMemberNames.joined(separator: ", "))
                                    .font(.subheadline)
                                    .foregroundColor(theme.textSecondary)
                            }
                        }
                        if isPinned {
                            HStack(spacing: 8) {
                                Image(systemName: "pin.fill")
                                    .font(.caption)
                                    .foregroundColor(theme.accentLight)
                                Text("Pinned")
                                    .font(.subheadline).fontWeight(.medium)
                                    .foregroundColor(theme.accentLight)
                            }
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.backgroundCard)
                    .cornerRadius(14)

                    MarkdownText(revision.body, color: theme.textPrimary)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let error = pinError {
                        Text(error)
                            .font(.footnote)
                            .foregroundColor(.red)
                    }

                    if let info = unpinQueued {
                        Label("Unpin queued — finalizes \(info.finalizeAfter, style: .relative). Cancel from System Safety settings.", systemImage: "clock")
                            .font(.footnote)
                            .foregroundColor(theme.textSecondary)
                    }

                    HStack(spacing: 12) {
                        Button {
                            if isPinned {
                                Task { await requestUnpin() }
                            } else {
                                Task { await togglePin() }
                            }
                        } label: {
                            HStack {
                                if isPinLoading {
                                    ProgressView().tint(isPinned ? .white : theme.accentLight).scaleEffect(0.8)
                                }
                                Label(isPinned ? "Unpin" : "Pin", systemImage: isPinned ? "pin.slash" : "pin")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .tint(theme.accentLight)
                        .disabled(isPinLoading)
                        .confirmationDialog("Unpin this revision?", isPresented: $showUnpinConfirm) {
                            Button("Unpin", role: .destructive) {
                                Task { await performUnpin() }
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("Unpinned revisions may be removed by automatic retention cleanup.")
                        }
                        .sheet(isPresented: $showUnpinAuth) {
                            UnpinRevisionSheet(onUnpin: { password, totpCode in
                                try await store.api?.unpinMemberBioRevision(memberID: member.id, revisionID: revision.id, password: password, totpCode: totpCode)
                            }, onSuccess: { response in
                                handleUnpinResponse(response)
                            })
                            .environmentObject(store)
                        }

                        Button {
                            showRestoreConfirm = true
                        } label: {
                            HStack {
                                if isRestoring {
                                    ProgressView().tint(.white).scaleEffect(0.8)
                                }
                                Label("Restore", systemImage: "arrow.uturn.backward")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(theme.accentLight)
                        .disabled(isRestoring)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(theme.backgroundPrimary)
            .navigationTitle("Revision")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(theme.accentLight)
                }
            }
        }
        .onAppear { isPinned = revision.isPinned }
        .confirmationDialog("Restore this version?", isPresented: $showRestoreConfirm) {
            Button("Restore") {
                Task {
                    isRestoring = true
                    if let updated = try? await store.api?.restoreMemberBioRevision(memberID: member.id, revisionID: revision.id) {
                        store.refreshMember(updated)
                    }
                    isRestoring = false
                    dismiss()
                    onRestored?()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The current bio will be saved as a revision, and this version will become the current bio.")
        }
    }

    private func requestUnpin() async {
        if let safety = try? await store.api?.getSystemSafety(),
           safety.settings.appliesToRevisions,
           safety.settings.authTier != .none {
            showUnpinAuth = true
        } else {
            showUnpinConfirm = true
        }
    }

    private func performUnpin() async {
        isPinLoading = true
        pinError = nil
        do {
            let response = try await store.api?.unpinMemberBioRevision(memberID: member.id, revisionID: revision.id)
            handleUnpinResponse(response)
        } catch {
            pinError = error.userFacingMessage
        }
        isPinLoading = false
    }

    private func handleUnpinResponse(_ response: UnpinRevisionResponse?) {
        if let actionID = response?.pendingActionID, let after = response?.finalizeAfter {
            unpinQueued = DeleteQueued(pendingActionID: actionID, finalizeAfter: after)
        } else {
            isPinned = false
            var updated = revision
            updated.pinnedAt = nil
            onPinChanged?(updated)
        }
    }

    func togglePin() async {
        isPinLoading = true
        pinError = nil
        unpinQueued = nil
        do {
            let updated = try await store.api?.pinMemberBioRevision(memberID: member.id, revisionID: revision.id)
            isPinned = true
            if let updated { onPinChanged?(updated) }
        } catch {
            pinError = error.userFacingMessage
        }
        isPinLoading = false
    }
}

// MARK: - FlowLayout
struct FlowLayout<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content
    @State private var totalHeight: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            self.generateContent(in: geo)
        }
        .frame(height: totalHeight)
    }

    private func generateContent(in geo: GeometryProxy) -> some View {
        var width: CGFloat = 0
        var height: CGFloat = 0

        return ZStack(alignment: .topLeading) {
            ForEach(items, id: \.self) { item in
                content(item)
                    .padding(.trailing, 8).padding(.bottom, 6)
                    .alignmentGuide(.leading) { d in
                        if abs(width - d.width) > geo.size.width {
                            width = 0; height -= d.height + 6
                        }
                        let result = width
                        if item == items.last { width = 0 } else { width -= d.width }
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        if item == items.last { height = 0 }
                        return result
                    }
            }
        }
        .background(viewHeightReader($totalHeight))
    }

    private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
        GeometryReader { geo -> Color in
            DispatchQueue.main.async { binding.wrappedValue = geo.size.height }
            return .clear
        }
    }
}
