import SwiftUI

struct GroupsView: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    @State private var showAddGroup = false
    @State private var selectedGroup: SystemGroup?

    var body: some View {
        ZStack {
            theme.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("Groups")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textPrimary)
                    Spacer()
                    Button {
                        showAddGroup = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(theme.accentLight)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 20)

                if store.isLoading && store.groups.isEmpty {
                    Spacer()
                    ProgressView().tint(theme.accentLight)
                    Spacer()
                } else if store.groups.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 44))
                            .foregroundColor(theme.textTertiary)
                        Text("No groups yet")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundColor(theme.textTertiary)
                        Text("Tap + to create your first group")
                            .font(.system(size: 13))
                            .foregroundColor(theme.textTertiary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(store.groups) { group in
                                GroupCard(group: group, members: store.membersIn(group: group)) {
                                    selectedGroup = group
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        Task { await store.deleteGroup(id: group.id) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 100)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddGroup) {
            GroupEditSheet(group: nil)
                .environmentObject(store)
        }
        .sheet(item: $selectedGroup) { group in
            GroupDetailSheet(group: group)
                .environmentObject(store)
        }
    }
}

// MARK: - Group Card
struct GroupCard: View {
    @Environment(\.theme) var theme
    let group: SystemGroup
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
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(theme.textPrimary)

                    if let desc = group.description, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 13))
                            .foregroundColor(theme.textSecondary)
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
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(theme.textPrimary)
                                }
                            }
                            Text("\(members.count) member\(members.count == 1 ? "" : "s")")
                                .font(.system(size: 12))
                                .foregroundColor(theme.textTertiary)
                                .padding(.leading, 14)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.textTertiary)
            }
            .padding(16)
            .background(theme.backgroundCard)
            .cornerRadius(18)
            .overlay(RoundedRectangle(cornerRadius: 18)
                .stroke(theme.backgroundCard, lineWidth: 1))
        }
        .buttonStyle(ScaleButtonStyle())
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
                                .font(.system(size: 30))
                                .foregroundColor(group.displayColor)
                        }
                        if let desc = group.description, !desc.isEmpty {
                            Text(desc)
                                .font(.system(size: 14))
                                .foregroundColor(theme.textSecondary)
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
                            .font(.system(size: 14))
                            .foregroundColor(theme.textTertiary)
                            .listRowBackground(theme.backgroundCard)
                    } else {
                        ForEach(members) { member in
                            HStack(spacing: 12) {
                                AvatarView(member: member, size: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(member.displayName ?? member.name)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(theme.textPrimary)
                                    if let p = member.pronouns, !p.isEmpty {
                                        Text(p).font(.system(size: 12)).foregroundColor(theme.textSecondary)
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
        .task {
            if let fetched = try? await store.api?.getGroupMembers(groupID: group.id) {
                members = fetched
            }
        }
    }

    private func removeFromGroup(_ member: Member) async {
        let newIDs = members
            .filter { $0.id != member.id }
            .map { $0.id }
        do {
            try await store.api?.setGroupMembers(groupID: group.id, memberIDs: newIDs)
            await MainActor.run {
                members.removeAll { $0.id == member.id }
            }
        } catch {
            store.errorMessage = error.localizedDescription
        }
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
    @State private var selectedMemberIDs: Set<String> = []
    @State private var isSaving = false
    @State private var isLoadingMembers = false

    var isNew: Bool { group == nil }

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
                                    .font(.system(size: 14))
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
            parentID: nil
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
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(theme.textPrimary)
                            if let p = member.pronouns, !p.isEmpty {
                                Text(p)
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.textSecondary)
                            }
                        }
                        Spacer()
                        Image(systemName: selectedMemberIDs.contains(member.id)
                              ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selectedMemberIDs.contains(member.id)
                                ? theme.accentLight : theme.textTertiary)
                            .font(.system(size: 20))
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
