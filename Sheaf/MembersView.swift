import SwiftUI

struct MembersView: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    @State private var searchText = ""
    @State private var showAddMember = false
    @State private var selectedMember: Member?


    private func removeMemberFromFront(_ member: Member) async {
        let remaining = store.frontingMembers
            .filter { $0.id != member.id }
            .map { $0.id }
        if remaining.isEmpty {
            for front in store.currentFronts where front.endedAt == nil {
                _ = try? await store.api?.updateFront(
                    id: front.id,
                    update: FrontUpdate(endedAt: Date(), memberIDs: nil)
                )
            }
            await MainActor.run { store.currentFronts = [] }
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
                                    Task { await store.deleteMember(id: member.id) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .listRowBackground(theme.backgroundCard)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 5, leading: 24, bottom: 5, trailing: 24))
                        }
                    }
                    .listStyle(.plain)
                    .background(theme.backgroundPrimary)
                    .scrollContentBackground(.hidden)
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
                            .font(.system(size: 22))
                            .foregroundColor(theme.accentLight)
                    }
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
    }
}

// MARK: - Member Row
struct MemberRow: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    let member: Member
    let isFronting: Bool
    let onTap: () -> Void

    @State private var showDeleteConfirm = false

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
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                    if let pronouns = member.pronouns, !pronouns.isEmpty {
                        Text(pronouns)
                            .font(.system(size: 12))
                            .foregroundColor(theme.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.textTertiary)
            }
            .padding(14)
            .background(theme.backgroundCard)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(isFronting ? member.displayColor.opacity(0.3) : theme.backgroundCard, lineWidth: 1))
        }
        .buttonStyle(ScaleButtonStyle())
        .confirmationDialog(
            "Delete \(member.displayName ?? member.name)?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task { await store.deleteMember(id: member.id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete this member and cannot be undone.")
        }
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
                    Label("Switch Front to \(member.displayName ?? member.name)", systemImage: "arrow.left.arrow.right")
                }
            }

            Divider()

            Button { onTap() } label: {
                Label("View Profile", systemImage: "person.crop.circle")
            }

            Divider()

            Button(role: .destructive) {
                showDeleteConfirm = true
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
            for front in store.currentFronts where front.endedAt == nil {
                _ = try? await store.api?.updateFront(
                    id: front.id,
                    update: FrontUpdate(endedAt: Date(), memberIDs: nil)
                )
            }
            await MainActor.run { store.currentFronts = [] }
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
                // Handle
                Capsule()
                    .fill(theme.inputBorder)
                    .frame(width: 40, height: 4)
                    .padding(.top, 12)

                HStack {
                    Button("Close") { dismiss() }
                        .foregroundColor(theme.textSecondary)
                    Spacer()
                    Button("Edit") { showEdit = true }
                        .foregroundColor(theme.accentLight)
                        .font(.system(size: 16, weight: .semibold))
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                ScrollView {
                    VStack(spacing: 24) {
                        // Avatar + name
                        VStack(spacing: 12) {
                            AvatarView(member: member, size: 96)
                            Text(member.displayName ?? member.name)
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(theme.textPrimary)
                            if let p = member.pronouns, !p.isEmpty {
                                Text(p)
                                    .padding(.horizontal, 14).padding(.vertical, 5)
                                    .background(member.displayColor.opacity(0.15))
                                    .cornerRadius(10)
                                    .foregroundColor(member.displayColor)
                                    .font(.system(size: 14))
                            }
                        }
                        .padding(.top, 20)

                        // Fronting status
                        if store.frontingMembers.contains(where: { $0.id == member.id }) {
                            Label("Currently Fronting", systemImage: "checkmark.seal.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(theme.success)
                                .padding(.horizontal, 16).padding(.vertical, 8)
                                .background(theme.success.opacity(0.1))
                                .cornerRadius(12)
                        }

                        // Description
                        if let desc = member.description, !desc.isEmpty {
                            Text(desc)
                                .font(.system(size: 15))
                                .foregroundColor(theme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(theme.backgroundCard)
                                .cornerRadius(14)
                        }



                        // Custom fields
                        if !fieldValues.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Custom Fields")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(theme.textSecondary)
                                    .textCase(.uppercase)
                                    .kerning(0.8)

                                VStack(spacing: 0) {
                                    ForEach(Array(fieldValues.enumerated()), id: \.offset) { i, fv in
                                        if let field = store.fields.first(where: { $0.id == fv.fieldID }) {
                                            HStack(alignment: .top, spacing: 12) {
                                                Text(field.name)
                                                    .font(.system(size: 14))
                                                    .foregroundColor(theme.textSecondary)
                                                    .frame(width: 100, alignment: .leading)
                                                Text(displayValue(fv.value, field: field))
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundColor(theme.textPrimary)
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
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(theme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(16)
                                .background(LinearGradient(
                                    colors: [theme.accentLight, theme.accent],
                                    startPoint: .leading, endPoint: .trailing))
                                .cornerRadius(14)
                        }
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
        .task {
            await loadFieldValues()
        }
    }

    private func loadFieldValues() async {
        guard let api = store.api else { return }
        loadingFields = true
        fieldValues = (try? await api.getMemberFieldValues(memberID: member.id)) ?? []
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
                .font(.system(size: 13, weight: .semibold))
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
    @State private var isSaving = false
    @State private var fieldValues: [String: String] = [:]  // fieldID -> string value

    var isNew: Bool { member == nil }

    var body: some View {
        ZStack {
            theme.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                Capsule().fill(theme.inputBorder).frame(width: 40, height: 4).padding(.top, 12)

                HStack {
                    Button("Cancel") { dismiss() }.foregroundColor(theme.textSecondary)
                    Spacer()
                    Text(isNew ? "Add Member" : "Edit Member")
                        .font(.system(size: 17, weight: .semibold)).foregroundColor(theme.textPrimary)
                    Spacer()
                    Button(isSaving ? "" : "Save") {
                        save()
                    }
                    .foregroundColor(theme.accentLight)
                    .font(.system(size: 16, weight: .semibold))
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
                        formField("Avatar URL", value: $avatarURL, placeholder: "https://...")

                        // Color picker
                        HStack {
                            Text("Color")
                                .font(.system(size: 14, weight: .medium))
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

                        // Custom fields
                        if !store.fields.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Custom Fields")
                                    .font(.system(size: 13, weight: .semibold))
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
        .onAppear { populateFields() }
    }

    func populateFields() {
        guard let m = member else { return }
        name        = m.name
        displayName = m.displayName ?? ""
        pronouns    = m.pronouns ?? ""
        description = m.description ?? ""
        avatarURL   = m.avatarURL ?? ""
        colorHex    = m.color ?? "#A78BFA"
        // Load existing field values
        Task {
            guard let api = store.api, let memberID = member?.id else { return }
            let values = (try? await api.getMemberFieldValues(memberID: memberID)) ?? []
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
            Text(label).font(.system(size: 13, weight: .semibold)).foregroundColor(theme.textSecondary)
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
            birthday: nil,
            privacy: .private
        )
        Task {
            await store.saveMember(existing: member, create: create)
            // Save custom field values if editing existing member
            if let memberID = member?.id ?? store.members.last?.id,
               let api = store.api, !fieldValues.isEmpty {
                let sets: [CustomFieldValueSet] = store.fields.compactMap { field in
                    guard let val = fieldValues[field.id], !val.isEmpty else { return nil }
                    return CustomFieldValueSet(
                        fieldID: field.id,
                        value: AnyCodable(val)
                    )
                }
                if !sets.isEmpty {
                    _ = try? await api.setMemberFieldValues(memberID: memberID, values: sets)
                }
            }
            isSaving = false
            dismiss()
        }
    }

    @ViewBuilder
    func customFieldEditor(_ field: CustomField) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(field.name)
                .font(.system(size: 13, weight: .semibold))
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
                TextField("YYYY-MM-DD", text: Binding(
                    get: { fieldValues[field.id] ?? "" },
                    set: { fieldValues[field.id] = $0 }
                ))
                .keyboardType(.numbersAndPunctuation)
                .padding(12).background(theme.backgroundCard).cornerRadius(12).foregroundColor(theme.textPrimary)
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
