import SwiftUI
import PhotosUI

struct MembersView: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    @State private var searchText = ""
    @State private var showAddMember = false
    @State private var selectedMember: Member?
    @State private var memberToDelete: Member?
    @State private var showDeleteConfirm = false
    @State private var showDeleteAuthSheet = false


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
        NavigationStack {
            Group {
                if store.isLoading && store.members.isEmpty {
                    ProgressView()
                        .tint(theme.accentLight)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
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
            .background(theme.backgroundPrimary)
            .navigationTitle("Members")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, placement: .automatic, prompt: "Search members")
            .searchToolbarBehavior(.automatic)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddMember = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(theme.accentLight)
                    }
                    .accessibilityLabel("Add member")
                }
            }
        }
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
                Task { await store.deleteMember(id: member.id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { member in
            Text("This will permanently delete \(member.displayName ?? member.name) and cannot be undone.")
        }
        .sheet(isPresented: $showDeleteAuthSheet) {
            if let member = memberToDelete {
                MemberDeleteConfirmSheet(member: member)
                    .environmentObject(store)
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
                    Text(member.displayName ?? member.name)
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundColor(theme.textPrimary)
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
    @State private var fieldValues: [CustomFieldValue] = []
    @State private var loadingFields = false

    var body: some View {
        ZStack {
            theme.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button("Close") { dismiss() }
                        .foregroundColor(theme.textSecondary)
                    Spacer()
                    Button("Edit") { showEdit = true }
                        .foregroundColor(theme.accentLight)
                        .font(.subheadline).fontWeight(.semibold)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                ScrollView {
                    VStack(spacing: 24) {
                        // Avatar + name
                        VStack(spacing: 12) {
                            AvatarView(member: member, size: 96)
                            Text(member.displayName ?? member.name)
                                .font(.title2).fontWeight(.bold).fontDesign(.rounded)
                                .foregroundColor(theme.textPrimary)
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
            }
        }
        .sheet(isPresented: $showEdit) {
            MemberEditSheet(member: member)
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
    @State private var privacy: PrivacyLevel = .private
    @State private var isSaving = false
    @State private var fieldValues: [String: String] = [:]  // fieldID -> string value
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isUploadingAvatar = false
    @State private var avatarMode: AvatarInputMode = .url

    var isNew: Bool { member == nil }

    var body: some View {
        ZStack {
            theme.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button("Cancel") { dismiss() }.foregroundColor(theme.textSecondary)
                    Spacer()
                    Text(isNew ? "Add Member" : "Edit Member")
                        .font(.headline).foregroundColor(theme.textPrimary)
                    Spacer()
                    Button(isSaving ? "" : "Save") {
                        save()
                    }
                    .foregroundColor(theme.accentLight)
                    .font(.subheadline).fontWeight(.semibold)
                    .overlay(isSaving ? AnyView(ProgressView().tint(theme.accentLight)) : AnyView(EmptyView()))
                    .disabled(name.isEmpty || isSaving)
                }
                .padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 8)

                ScrollView {
                    VStack(spacing: 16) {
                        formField("Name *", value: $name, placeholder: "member-name")
                        formField("Display Name", value: $displayName, placeholder: "Shown to others")
                        formField("Pronouns", value: $pronouns, placeholder: "e.g. she/her")
                        formField("Description", value: $description, placeholder: "Brief description", multiline: true)

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
            }
        }
        .presentationDragIndicator(.visible)
        .onAppear { populateFields() }
    }

    func populateFields() {
        guard let m = member else { return }
        name        = m.name
        displayName = m.displayName ?? ""
        pronouns    = m.pronouns ?? ""
        description = m.description ?? ""
        avatarURL   = m.avatarURL ?? ""
        if avatarURL.hasPrefix("/") { avatarMode = .upload }
        colorHex    = m.color ?? "#A78BFA"
        birthday    = m.birthday ?? ""
        privacy     = m.privacy
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
        ZStack {
            theme.backgroundPrimary.ignoresSafeArea()
            VStack(spacing: 0) {
                Capsule().fill(theme.inputBorder).frame(width: 40, height: 4).padding(.top, 12)

                HStack {
                    Button("Cancel") { dismiss() }.foregroundColor(theme.textSecondary)
                    Spacer()
                    Text("Confirm Deletion").font(.headline).foregroundColor(theme.textPrimary)
                    Spacer()
                    // Spacer to balance the Cancel button
                    Text("Cancel").foregroundColor(.clear)
                }
                .padding(.horizontal, 24).padding(.top, 16)

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
                Spacer()
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
            await store.deleteMember(id: member.id, confirmation: confirmation)
            await MainActor.run {
                isDeleting = false
                // If the member was removed, the delete succeeded
                if !store.members.contains(where: { $0.id == member.id }) {
                    dismiss()
                } else {
                    errorMessage = "Deletion failed. Please check your credentials and try again."
                }
            }
        }
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
