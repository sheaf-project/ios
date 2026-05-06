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


    private func removeMemberFromFront(_ member: Member) async {
        let remaining = store.frontingMembers
            .filter { $0.id != member.id }
            .map { $0.id }
        if remaining.isEmpty {
            await store.endAllFronts()
        } else {
            await store.switchFronting(to: remaining)
        }
    }

    var filtered: [Member] {
        if searchText.isEmpty { return store.members }
        return store.members.filter {
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
                                    Task { await store.switchFronting(to: store.frontingMembers.map { $0.id } + [member.id]) }
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
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 5, leading: 24, bottom: 5, trailing: 24))
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
                    Task { await store.switchFronting(to: store.frontingMembers.map { $0.id } + [member.id]) }
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

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Member", systemImage: "trash")
            }
        }
    }

    private func removeMemberFromFront() async {
        let remaining = store.frontingMembers
            .filter { $0.id != member.id }
            .map { $0.id }
        if remaining.isEmpty {
            await store.endAllFronts()
        } else {
            await store.switchFronting(to: remaining)
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Avatar + name
                    VStack(spacing: 12) {
                        AvatarView(member: member, size: 96)
                        HStack(spacing: 8) {
                            Text(member.displayName ?? member.name)
                                .font(.title2).fontWeight(.bold).fontDesign(.rounded)
                                .foregroundColor(theme.textPrimary)
                            if let emoji = member.emoji, !emoji.isEmpty {
                                Text(emoji).font(.callout)
                            }
                            if member.isCustomFront {
                                Text("Custom Front")
                                    .font(.caption2).fontWeight(.bold)
                                    .foregroundColor(theme.textTertiary)
                                    .padding(.horizontal, 6).padding(.vertical, 3)
                                    .background(theme.textTertiary.opacity(0.15))
                                    .cornerRadius(6)
                            }
                        }
                        if let p = member.pronouns, !p.isEmpty {
                            Text(p)
                                .padding(.horizontal, 14).padding(.vertical, 5)
                                .background(member.displayColor.opacity(0.15))
                                .cornerRadius(10)
                                .foregroundColor(member.displayColor)
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
                    if let desc = member.description, !desc.isEmpty {
                        MarkdownText(desc, color: theme.textSecondary)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(theme.backgroundCard)
                            .cornerRadius(14)
                    }

                    // Birthday
                    if let bday = member.birthday, !bday.isEmpty {
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
                    if let pkID = member.pluralkitID, !pkID.isEmpty {
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
                        Label("Switch to \(member.displayName ?? member.name)", systemImage: "arrow.left.arrow.right")
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
            MemberEditSheet(member: member)
                .environmentObject(store)
        }
        .sheet(isPresented: $showBioRevisions) {
            MemberBioRevisionsView(member: member)
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
        switch field.fieldType {
        case .boolean:
            if let b = value.value as? Bool { return b ? "Yes" : "No" }
        case .date:
            if let s = value.value as? String { return s }
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
    @State private var colorHex = "#A78BFA"
    @State private var birthday = ""
    @State private var emoji = ""
    @State private var isCustomFront = false
    @State private var privacy: PrivacyLevel = .private
    @State private var isSaving = false
    @State private var fieldValues: [String: String] = [:]  // fieldID -> string value
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isUploadingAvatar = false
    @State private var avatarMode: AvatarInputMode = .url

    var isNew: Bool { member == nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    formField("Name *", value: $name, placeholder: "member-name")
                    formField("Display Name", value: $displayName, placeholder: "Shown to others")
                    formField("Pronouns", value: $pronouns, placeholder: "e.g. she/her")
                    formField("Emoji", value: $emoji, placeholder: "e.g. ✨")
                    formField("Description", value: $description, placeholder: "Brief description", multiline: true)

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
                    Button("Cancel") { dismiss() }
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
        .onAppear { populateFields() }
    }

    func populateFields() {
        guard let m = member else { return }
        name          = m.name
        displayName   = m.displayName ?? ""
        pronouns      = m.pronouns ?? ""
        description   = m.description ?? ""
        avatarURL     = m.avatarURL ?? ""
        if avatarURL.hasPrefix("/") { avatarMode = .upload }
        colorHex      = m.color ?? "#A78BFA"
        birthday      = m.birthday ?? ""
        emoji         = m.emoji ?? ""
        isCustomFront = m.isCustomFront
        privacy       = m.privacy
        // Load existing field values
        Task {
            guard let memberID = member?.id else { return }
            let values = await store.getMemberFieldValues(memberID: memberID)
            await MainActor.run {
                for v in values {
                    if let s = v.value.value as? String { fieldValues[v.fieldID] = s }
                    else if let n = v.value.value as? Int { fieldValues[v.fieldID] = "\(n)" }
                    else if let d = v.value.value as? Double { fieldValues[v.fieldID] = String(format: "%g", d) }
                    else if let b = v.value.value as? Bool { fieldValues[v.fieldID] = b ? "true" : "false" }
                }
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
            color: colorHex.isEmpty ? nil : colorHex,
            birthday: birthday.isEmpty ? nil : birthday,
            emoji: emoji.isEmpty ? nil : emoji,
            isCustomFront: isCustomFront,
            privacy: privacy
        )
        Task {
            await store.saveMember(existing: member, create: create)
            // Save custom field values
            if let memberID = member?.id ?? store.members.last?.id,
               !fieldValues.isEmpty {
                let sets: [CustomFieldValueSet] = store.fields.compactMap { field in
                    guard let val = fieldValues[field.id], !val.isEmpty else { return nil }
                    return CustomFieldValueSet(
                        fieldID: field.id,
                        value: AnyCodable(val)
                    )
                }
                // Always send the PUT even with an empty array to clear removed values
                await store.setMemberFieldValues(memberID: memberID, values: sets)
            }
            isSaving = false
            dismiss()
        }
    }

    @ViewBuilder
    func customFieldEditor(_ field: CustomField) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(field.name)
                .font(.footnote).fontWeight(.semibold)
                .foregroundColor(theme.textSecondary)
            switch field.fieldType {
            case .boolean:
                Toggle("", isOn: Binding(
                    get: { fieldValues[field.id] == "true" },
                    set: { fieldValues[field.id] = $0 ? "true" : "false" }
                ))
                .tint(theme.accentLight)
                .labelsHidden()
            case .number:
                TextField("0", text: Binding(
                    get: { fieldValues[field.id] ?? "" },
                    set: { fieldValues[field.id] = $0 }
                ))
                .keyboardType(.decimalPad)
                .padding(12).background(theme.backgroundCard).cornerRadius(12).foregroundColor(theme.textPrimary)
            case .date:
                DatePicker(
                    "",
                    selection: Binding(
                        get: {
                            let fmt = DateFormatter()
                            fmt.dateFormat = "yyyy-MM-dd"
                            return fmt.date(from: fieldValues[field.id] ?? "") ?? Date()
                        },
                        set: {
                            let fmt = DateFormatter()
                            fmt.dateFormat = "yyyy-MM-dd"
                            fieldValues[field.id] = fmt.string(from: $0)
                        }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .tint(theme.accentLight)
                .labelsHidden()
            default:
                TextField(field.name, text: Binding(
                    get: { fieldValues[field.id] ?? "" },
                    set: { fieldValues[field.id] = $0 }
                ))
                .autocorrectionDisabled()
                .padding(12).background(theme.backgroundCard).cornerRadius(12).foregroundColor(theme.textPrimary)
            }
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
                uploadError = error.localizedDescription
                selectedPhoto = nil
            }
        }
    }
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
            pinError = error.localizedDescription
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
            pinError = error.localizedDescription
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
