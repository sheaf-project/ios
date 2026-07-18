import SwiftUI

struct GroupsView: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    @Binding var showAddGroup: Bool
    @State private var selectedGroup: SystemGroup?
    @State private var groupToDelete: SystemGroup?
    @State private var showDeleteGroupConfirm = false
    @State private var showDeleteAuthSheet = false
    @State private var showDeleteQueued = false
    @State private var deleteQueuedInfo: DeleteQueued?

    var body: some View {
        VStack(spacing: 0) {
            if store.isLoading && store.groups.isEmpty {
                Spacer()
                ProgressView().tint(theme.accentLight)
                Spacer()
            } else if store.groups.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "square.grid.2x2")
                        .font(.largeTitle)
                        .foregroundColor(theme.textTertiary)
                    Text("No groups yet")
                        .font(.body).fontWeight(.medium).fontDesign(.rounded)
                        .foregroundColor(theme.textTertiary)
                    Text("Tap + to create your first group")
                        .font(.footnote)
                        .foregroundColor(theme.textTertiary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // Flatten parent-before-children so subgroups can
                        // render indented under their parent. Roots are
                        // groups with no parent (or an orphaned parent_id).
                        ForEach(orderHierarchically(store.groups), id: \.group.id) { entry in
                            GroupCard(group: entry.group, depth: entry.depth, members: store.membersIn(group: entry.group)) {
                                selectedGroup = entry.group
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    requestDelete(entry.group)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    requestDelete(entry.group)
                                } label: {
                                    Label("Delete Group", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 100)
                }
                .refreshable {
                    store.loadAll()
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.backgroundPrimary.ignoresSafeArea())
        .sheet(isPresented: $showAddGroup) {
            GroupEditSheet(group: nil)
                .environmentObject(store)
        }
        .sheet(item: $selectedGroup) { group in
            GroupDetailSheet(group: group)
                .environmentObject(store)
        }
        .confirmationDialog("Delete this group?", isPresented: $showDeleteGroupConfirm, presenting: groupToDelete) { group in
            Button("Delete", role: .destructive) {
                Task {
                    let queued = await store.deleteGroup(id: group.id)
                    if let queued {
                        deleteQueuedInfo = queued
                        showDeleteQueued = true
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { group in
            Text("This will permanently delete \"\(group.name)\" and cannot be undone.")
        }
        .sheet(isPresented: $showDeleteAuthSheet) {
            if let group = groupToDelete {
                GroupDeleteConfirmSheet(group: group) { queued in
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

    private func requestDelete(_ group: SystemGroup) {
        groupToDelete = group
        let level = store.systemProfile?.deleteConfirmation ?? .none
        if level == .none {
            showDeleteGroupConfirm = true
        } else {
            showDeleteAuthSheet = true
        }
    }
}

// MARK: - Group Delete Confirmation Sheet
struct GroupDeleteConfirmSheet: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var store: SystemStore
    @Environment(\.dismiss) var dismiss
    let group: SystemGroup
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
                    Text("Deleting \"\(group.name)\"")
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
                            Text("Delete Group")
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
            let queued = await store.deleteGroup(id: group.id, confirmation: confirmation)
            await MainActor.run {
                isDeleting = false
                if let queued {
                    dismiss()
                    onQueued?(queued)
                } else if !store.groups.contains(where: { $0.id == group.id }) {
                    dismiss()
                } else {
                    errorMessage = "Deletion failed. Please check your credentials and try again."
                }
            }
        }
    }
}

// MARK: - Group Card
struct GroupCard: View {
    @Environment(\.theme) var theme
    let group: SystemGroup
    var depth: Int = 0
    let members: [Member]
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Color dot
                RoundedRectangle(cornerRadius: 6)
                    .fill(group.displayColor)
                    .frame(width: 6, height: 56)

                VStack(alignment: .leading, spacing: 6) {
                    Text(group.name)
                        .font(.headline)
                        .foregroundColor(theme.textPrimary)

                    if let desc = group.description, !desc.isEmpty {
                        MarkdownText(desc, color: theme.textSecondary)
                            .font(.footnote)
                            .lineLimit(1)
                    }

                    // Stacked avatars
                    if !members.isEmpty {
                        HStack(spacing: -10) {
                            ForEach(members.prefix(5)) { m in
                                AvatarView(member: m, size: 26)
                                    .overlay(Circle().stroke(theme.backgroundPrimary, lineWidth: 1.5))
                            }
                            if members.count > 5 {
                                ZStack {
                                    Circle().fill(theme.backgroundElevated).frame(width: 26, height: 26)
                                    Text("+\(members.count - 5)")
                                        .font(.caption2).fontWeight(.bold)
                                        .foregroundColor(theme.textPrimary)
                                }
                            }
                            Text("\(members.count) member\(members.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(theme.textTertiary)
                                .padding(.leading, 14)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundColor(theme.textTertiary)
            }
            .padding(16)
            .background(theme.backgroundCard)
            .cornerRadius(18)
            .overlay(RoundedRectangle(cornerRadius: 18)
                .stroke(theme.backgroundCard, lineWidth: 1))
        }
        .buttonStyle(ScaleButtonStyle())
        // Indent subgroups under their parent. Capped so deep nesting stays
        // usable on a narrow screen; the server also caps nesting depth.
        .padding(.leading, CGFloat(min(depth, 4)) * 16)
    }
}

// MARK: - Group Detail Sheet
struct GroupDetailSheet: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var store: SystemStore
    @Environment(\.dismiss) var dismiss
    let group: SystemGroup
    @State private var showEdit = false
    @State private var members: [Member] = []
    @State private var relationships: [MemberRelationship] = []
    @State private var showAddRelationship = false

    var body: some View {
        NavigationStack {
            List {
                // Header section
                Section {
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(group.displayColor.opacity(0.2))
                                .frame(width: 72, height: 72)
                            Image(systemName: "square.grid.2x2.fill")
                                .font(.title)
                                .foregroundColor(group.displayColor)
                        }
                        if let desc = group.description, !desc.isEmpty {
                            MarkdownText(desc, color: theme.textSecondary)
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                // Members section
                Section("Members (\(members.count))") {
                    if members.isEmpty {
                        Text("No members in this group")
                            .font(.subheadline)
                            .foregroundColor(theme.textTertiary)
                            .listRowBackground(theme.backgroundCard)
                    } else {
                        ForEach(members) { member in
                            HStack(spacing: 12) {
                                AvatarView(member: member, size: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(member.displayName ?? member.name)
                                        .font(.subheadline).fontWeight(.medium)
                                        .foregroundColor(theme.textPrimary)
                                    if let p = member.pronouns, !p.isEmpty {
                                        Text(p).font(.caption).foregroundColor(theme.textSecondary)
                                    }
                                }
                                Spacer()
                                if store.frontingMembers.contains(where: { $0.id == member.id }) {
                                    Circle().fill(theme.success).frame(width: 8, height: 8)
                                }
                            }
                            .listRowBackground(theme.backgroundCard)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await removeFromGroup(member) }
                                } label: {
                                    Label("Remove", systemImage: "person.fill.xmark")
                                }
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    Task { await removeFromGroup(member) }
                                } label: {
                                    Label("Remove from Group", systemImage: "person.fill.xmark")
                                }
                            }
                        }
                    }
                }

                if !relationships.isEmpty || !store.relationshipTypes.isEmpty {
                    Section {
                        if relationships.isEmpty {
                            Text("No relationships yet")
                                .font(.subheadline)
                                .foregroundColor(theme.textTertiary)
                                .listRowBackground(theme.backgroundCard)
                        } else {
                            ForEach(relationships) { rel in
                                relationshipRow(rel)
                            }
                        }
                    } header: {
                        HStack {
                            Text("Relationships")
                            Spacer()
                            Button {
                                showAddRelationship = true
                            } label: {
                                Image(systemName: "plus")
                                    .font(.footnote)
                                    .foregroundColor(theme.accentLight)
                            }
                            .accessibilityLabel("Add Relationship")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(theme.backgroundPrimary)
            .navigationTitle(group.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(theme.accentLight)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") { showEdit = true }
                        .foregroundColor(theme.accentLight)
                        .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            GroupEditSheet(group: group)
                .environmentObject(store)
        }
        .sheet(isPresented: $showAddRelationship) {
            AddRelationshipSheet(scope: .group, nodeID: group.id, nodeName: group.name) {
                Task { await loadRelationships() }
            }
            .environmentObject(store)
        }
        .task {
            if let fetched = try? await store.api?.getGroupMembers(groupID: group.id) {
                members = fetched
            }
            await loadRelationships()
        }
    }

    private func loadRelationships() async {
        relationships = await store.getGroupRelationships(groupID: group.id)
    }

    @ViewBuilder
    private func relationshipRow(_ rel: MemberRelationship) -> some View {
        let other = store.groups.first { $0.id == rel.otherID }
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(other?.name ?? "Unknown group")
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundColor(theme.textPrimary)
                Text(rel.mutual ? "\(rel.label) (mutual)" : rel.label)
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
            }
            Spacer()
        }
        .listRowBackground(theme.backgroundCard)
        .contextMenu {
            Button(role: .destructive) {
                Task {
                    if await store.deleteGroupRelationship(id: rel.id) {
                        relationships.removeAll { $0.id == rel.id }
                    }
                }
            } label: {
                Label("Remove Relationship", systemImage: "trash")
            }
        }
    }

    private func removeFromGroup(_ member: Member) async {
        let newIDs = members
            .filter { $0.id != member.id }
            .map { $0.id }
        await store.setGroupMembers(groupID: group.id, memberIDs: newIDs)
        members.removeAll { $0.id == member.id }
    }
}

// MARK: - Group Edit Sheet
struct GroupEditSheet: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var store: SystemStore
    @Environment(\.dismiss) var dismiss
    let group: SystemGroup?

    @State private var name = ""
    @State private var description = ""
    @State private var colorHex = "#6366F1"
    @State private var parentID: String?
    @State private var selectedMemberIDs: Set<String> = []
    @State private var isSaving = false
    @State private var isLoadingMembers = false

    var isNew: Bool { group == nil }

    /// Parents eligible for selection: every group except this one and its
    /// descendants (preventing cycles). The server also caps nesting depth.
    private var eligibleParents: [SystemGroup] {
        guard let currentID = group?.id else { return store.groups }
        let descendants = collectDescendantIDs(of: currentID, in: store.groups)
        return store.groups.filter { $0.id != currentID && !descendants.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Group Name", text: $name)
                        .foregroundColor(theme.textPrimary)
                        .autocorrectionDisabled()
                        .listRowBackground(theme.backgroundCard)

                    TextField("Description", text: $description)
                        .foregroundColor(theme.textPrimary)
                        .autocorrectionDisabled()
                        .listRowBackground(theme.backgroundCard)

                    HStack {
                        Text("Color").foregroundColor(theme.textPrimary)
                        Spacer()
                        ColorPicker("", selection: Binding(
                            get: { Color(hex: colorHex) ?? .indigo },
                            set: { colorHex = $0.toHex() }
                        )).labelsHidden()
                    }
                    .listRowBackground(theme.backgroundCard)
                }

                Section("Parent group") {
                    Picker(selection: $parentID) {
                        Text("None (top-level)").tag(String?.none)
                        ForEach(eligibleParents) { g in
                            Text(g.name).tag(Optional(g.id))
                        }
                    } label: {
                        Text("Parent")
                            .foregroundColor(theme.textPrimary)
                    }
                    .pickerStyle(.menu)
                    .listRowBackground(theme.backgroundCard)
                }

                Section {
                    NavigationLink {
                        GroupMemberPickerView(
                            selectedMemberIDs: $selectedMemberIDs,
                            members: store.members
                        )
                    } label: {
                        HStack {
                            Text("Members")
                                .foregroundColor(theme.textPrimary)
                            Spacer()
                            if isLoadingMembers {
                                ProgressView().tint(theme.accentLight)
                            } else {
                                Text("\(selectedMemberIDs.count) selected")
                                    .foregroundColor(theme.textSecondary)
                                    .font(.subheadline)
                            }
                        }
                    }
                    .listRowBackground(theme.backgroundCard)
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.backgroundPrimary)
            .navigationTitle(isNew ? "New Group" : "Edit Group")
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
        .task { await populateFields() }
    }

    func populateFields() async {
        guard let g = group else { return }
        name        = g.name
        description = g.description ?? ""
        colorHex    = g.color ?? "#6366F1"
        parentID    = g.parentID
        // Load existing members from API so selections are pre-filled
        isLoadingMembers = true
        if let fetched = try? await store.api?.getGroupMembers(groupID: g.id) {
            selectedMemberIDs = Set(fetched.map { $0.id })
        }
        isLoadingMembers = false
    }

    func save() {
        isSaving = true
        let create = GroupCreate(
            name: name,
            description: description.isEmpty ? nil : description,
            color: colorHex.isEmpty ? nil : colorHex,
            parentID: parentID
        )
        Task {
            await store.saveGroup(existing: group, create: create)
            if let savedGroup = store.groups.first(where: { $0.id == group?.id }) ?? store.groups.last {
                await store.setGroupMembers(groupID: savedGroup.id, memberIDs: Array(selectedMemberIDs))
            }
            isSaving = false
            dismiss()
        }
    }
}

// MARK: - Group Member Picker
struct GroupMemberPickerView: View {
    @Environment(\.theme) var theme
    @Binding var selectedMemberIDs: Set<String>
    let members: [Member]

    var body: some View {
        List {
            ForEach(members) { member in
                Button {
                    if selectedMemberIDs.contains(member.id) {
                        selectedMemberIDs.remove(member.id)
                    } else {
                        selectedMemberIDs.insert(member.id)
                    }
                } label: {
                    HStack(spacing: 12) {
                        AvatarView(member: member, size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.displayName ?? member.name)
                                .font(.subheadline).fontWeight(.medium)
                                .foregroundColor(theme.textPrimary)
                            if let p = member.pronouns, !p.isEmpty {
                                Text(p)
                                    .font(.caption)
                                    .foregroundColor(theme.textSecondary)
                            }
                        }
                        Spacer()
                        Image(systemName: selectedMemberIDs.contains(member.id)
                              ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selectedMemberIDs.contains(member.id)
                                ? theme.accentLight : theme.textTertiary)
                            .font(.title3)
                    }
                }
                .buttonStyle(.plain)
                .listRowBackground(theme.backgroundCard)
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.backgroundPrimary)
        .navigationTitle("Members")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    selectedMemberIDs = Set(members.map { $0.id })
                } label: {
                    Text("All")
                        .foregroundColor(theme.accentLight)
                }
            }
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    selectedMemberIDs = []
                } label: {
                    Text("None")
                        .foregroundColor(theme.accentLight)
                }
            }
        }
    }
}

// MARK: - Hierarchical group ordering

struct GroupHierarchyEntry {
    let group: SystemGroup
    let depth: Int
}

/// Flatten the group list into parent-before-children order with a depth for
/// each, so the list can indent subgroups under their parent. Roots are
/// groups with no parent (or a parent_id that isn't in the set); orphans
/// fall back to roots so nothing is dropped.
func orderHierarchically(_ groups: [SystemGroup]) -> [GroupHierarchyEntry] {
    let byID = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0) })
    let childrenOf = Dictionary(grouping: groups, by: { $0.parentID })
    var out: [GroupHierarchyEntry] = []

    func visit(_ group: SystemGroup, depth: Int) {
        out.append(GroupHierarchyEntry(group: group, depth: depth))
        let children = (childrenOf[group.id] ?? []).sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        for child in children {
            visit(child, depth: depth + 1)
        }
    }

    let roots = groups.filter { g in
        guard let pid = g.parentID else { return true }
        return byID[pid] == nil
    }.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }

    for root in roots {
        visit(root, depth: 0)
    }
    return out
}

/// Ids of every group descended from `rootID` (its children, recursively).
func collectDescendantIDs(of rootID: String, in groups: [SystemGroup]) -> Set<String> {
    let childrenOf = Dictionary(grouping: groups, by: { $0.parentID })
    var result: Set<String> = []
    var stack: [String] = [rootID]
    while let next = stack.popLast() {
        for child in childrenOf[next] ?? [] where result.insert(child.id).inserted {
            stack.append(child.id)
        }
    }
    return result
}
