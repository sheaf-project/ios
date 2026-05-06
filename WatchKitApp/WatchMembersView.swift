import SwiftUI

// MARK: - Members list page
struct WatchMembersView: View {
    @EnvironmentObject var store: WatchStore
    @State private var showAddMember = false
    @State private var searchText = ""

    private var filteredMembers: [Member] {
        if searchText.isEmpty { return store.members }
        return store.members.filter {
            ($0.displayName ?? $0.name).localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            if store.isLoading && store.members.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if store.members.isEmpty {
                Text("No members")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(filteredMembers) { member in
                    let isFronting = store.frontingMembers.contains(where: { $0.id == member.id })
                    NavigationLink {
                        WatchMemberDetailView(member: member, isFronting: isFronting)
                            .environmentObject(store)
                    } label: {
                        WatchMemberTile(member: member, showFrontingDot: isFronting)
                    }
                    .contextMenu {
                        if isFronting {
                            Button {
                                Task { await removeFromFront(member) }
                            } label: {
                                Label("Remove from Front", systemImage: "person.fill.xmark")
                            }
                        } else {
                            Button {
                                Task { await addToFront(member) }
                            } label: {
                                Label("Add to Front", systemImage: "person.fill.checkmark")
                            }
                            Button {
                                Task { await switchToOnly(member) }
                            } label: {
                                Label("Switch to \(member.displayName ?? member.name) as the only fronter", systemImage: "arrow.left.arrow.right")
                            }
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if isFronting {
                            Button(role: .destructive) {
                                Task { await removeFromFront(member) }
                            } label: {
                                Label("Remove", systemImage: "person.fill.xmark")
                            }
                        } else {
                            Button {
                                Task { await addToFront(member) }
                            } label: {
                                Label("Add", systemImage: "person.fill.checkmark")
                            }
                            .tint(.purple)
                        }
                    }
                }
            }
        }
        .navigationTitle("Members")
        .searchable(text: $searchText, prompt: "Search members")
        .onAppear { store.loadAll() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddMember = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddMember) {
            WatchAddMemberSheet()
                .environmentObject(store)
        }
    }

    private func addToFront(_ member: Member) async {
        let current = store.frontingMembers.map { $0.id }
        await store.switchFronting(to: current + [member.id])
    }

    private func switchToOnly(_ member: Member) async {
        await store.switchFronting(to: [member.id])
    }

    private func removeFromFront(_ member: Member) async {
        let remaining = store.frontingMembers
            .filter { $0.id != member.id }
            .map { $0.id }
        await store.switchFronting(to: remaining)
    }
}

// MARK: - Member Detail View
struct WatchMemberDetailView: View {
    @EnvironmentObject var store: WatchStore
    let member: Member
    let isFronting: Bool
    @State private var showGroupPicker = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Avatar
                AvatarView(member: member, size: 56)
                    .overlay(alignment: .bottomTrailing) {
                        if isFronting {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 14, height: 14)
                                .overlay(Circle().stroke(Color.black, lineWidth: 2))
                        }
                    }

                // Name + pronouns
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Text(member.displayName ?? member.name)
                            .font(.headline)
                            .fontDesign(.rounded)
                        if let emoji = member.emoji, !emoji.isEmpty {
                            Text(emoji).font(.subheadline)
                        }
                    }
                    .multilineTextAlignment(.center)

                    if let pronouns = member.pronouns, !pronouns.isEmpty {
                        Text(pronouns)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if isFronting {
                        Label("Fronting", systemImage: "checkmark.seal.fill")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                            .padding(.top, 2)
                    }
                }

                // Description
                if let desc = member.description, !desc.isEmpty {
                    Text(desc)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 4)
                }

                Divider()

                // Actions
                if isFronting {
                    Button {
                        Task {
                            let remaining = store.frontingMembers
                                .filter { $0.id != member.id }
                                .map { $0.id }
                            await store.switchFronting(to: remaining)
                        }
                    } label: {
                        Label("Remove from Front", systemImage: "person.fill.xmark")
                            .font(.footnote)
                    }
                    .tint(.orange)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle)
                } else {
                    Button {
                        Task {
                            let current = store.frontingMembers.map { $0.id }
                            await store.switchFronting(to: current + [member.id])
                        }
                    } label: {
                        Label("Add to Front", systemImage: "person.fill.checkmark")
                            .font(.footnote)
                    }
                    .tint(.purple)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle)

                    Button {
                        Task { await store.switchFronting(to: [member.id]) }
                    } label: {
                        Label("Set as sole fronter", systemImage: "arrow.left.arrow.right")
                            .font(.footnote)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle)
                }

                if !store.groups.isEmpty {
                    Divider()

                    Button {
                        showGroupPicker = true
                    } label: {
                        Label("Add to Group", systemImage: "folder.badge.plus")
                            .font(.footnote)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle)
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle(member.displayName ?? member.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showGroupPicker) {
            WatchMemberGroupPickerView(member: member)
                .environmentObject(store)
        }
    }
}

// MARK: - Reusable member tile
struct WatchMemberTile: View {
    let member: Member
    let showFrontingDot: Bool

    var body: some View {
        HStack(spacing: 10) {
            AvatarView(member: member, size: 32)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 3) {
                    Text(member.displayName ?? member.name)
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    if let emoji = member.emoji, !emoji.isEmpty {
                        Text(emoji).font(.caption2)
                    }
                }
                if let pronouns = member.pronouns, !pronouns.isEmpty {
                    Text(pronouns)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if showFrontingDot {
                Circle()
                    .fill(Color.green)
                    .frame(width: 7, height: 7)
            }
        }
    }
}

// MARK: - Member Group Picker
struct WatchMemberGroupPickerView: View {
    @EnvironmentObject var store: WatchStore
    @Environment(\.dismiss) private var dismiss
    let member: Member
    @State private var memberGroupIDs: Set<String> = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    ForEach(store.groups) { group in
                        Button {
                            Task { await toggleGroup(group) }
                        } label: {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(group.displayColor)
                                    .frame(width: 10, height: 10)
                                Text(group.name)
                                    .font(.footnote)
                                    .lineLimit(1)
                                Spacer()
                                if memberGroupIDs.contains(group.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Groups")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await loadMemberships() }
        }
    }

    private func loadMemberships() async {
        isLoading = true
        var ids: Set<String> = []
        for group in store.groups {
            let members = await store.getGroupMembers(groupID: group.id)
            if members.contains(where: { $0.id == member.id }) {
                ids.insert(group.id)
            }
        }
        memberGroupIDs = ids
        isLoading = false
    }

    private func toggleGroup(_ group: SystemGroup) async {
        let currentMembers = await store.getGroupMembers(groupID: group.id)
        if memberGroupIDs.contains(group.id) {
            let remaining = currentMembers.filter { $0.id != member.id }.map { $0.id }
            await store.setGroupMembers(groupID: group.id, memberIDs: remaining)
            memberGroupIDs.remove(group.id)
        } else {
            let updated = currentMembers.map { $0.id } + [member.id]
            await store.setGroupMembers(groupID: group.id, memberIDs: updated)
            memberGroupIDs.insert(group.id)
        }
    }
}

// MARK: - Groups List
struct WatchGroupsView: View {
    @EnvironmentObject var store: WatchStore
    @State private var showAddGroup = false

    var body: some View {
        List {
            if store.isLoading && store.groups.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if store.groups.isEmpty {
                Text("No groups")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(store.groups) { group in
                    NavigationLink {
                        WatchGroupDetailView(group: group)
                            .environmentObject(store)
                    } label: {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(group.displayColor)
                                .frame(width: 10, height: 10)
                            Text(group.name)
                                .font(.footnote)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task { await store.deleteGroup(id: group.id) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("Groups")
        .onAppear { store.loadAll() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddGroup = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddGroup) {
            WatchAddGroupSheet()
                .environmentObject(store)
        }
    }
}

// MARK: - Group Detail
struct WatchGroupDetailView: View {
    @EnvironmentObject var store: WatchStore
    let group: SystemGroup
    @State private var groupMembers: [Member] = []
    @State private var isLoadingMembers = true
    @State private var showMemberPicker = false

    var body: some View {
        List {
            if let desc = group.description, !desc.isEmpty {
                Text(desc)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Section("Members") {
                if isLoadingMembers {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if groupMembers.isEmpty {
                    Text("No members")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(groupMembers) { member in
                        HStack(spacing: 10) {
                            AvatarView(member: member, size: 28)
                            Text(member.displayName ?? member.name)
                                .font(.footnote)
                                .lineLimit(1)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task { await removeMember(member) }
                            } label: {
                                Label("Remove", systemImage: "minus.circle")
                            }
                        }
                    }
                }
            }

            Button {
                showMemberPicker = true
            } label: {
                Label("Manage Members", systemImage: "person.2.badge.gearshape")
                    .font(.footnote)
            }
        }
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadMembers() }
        .sheet(isPresented: $showMemberPicker) {
            WatchGroupMemberPickerView(group: group, selectedMemberIDs: Set(groupMembers.map { $0.id })) { newIDs in
                Task {
                    await store.setGroupMembers(groupID: group.id, memberIDs: Array(newIDs))
                    await loadMembers()
                }
            }
            .environmentObject(store)
        }
    }

    private func loadMembers() async {
        isLoadingMembers = true
        groupMembers = await store.getGroupMembers(groupID: group.id)
        isLoadingMembers = false
    }

    private func removeMember(_ member: Member) async {
        let remaining = groupMembers.filter { $0.id != member.id }.map { $0.id }
        await store.setGroupMembers(groupID: group.id, memberIDs: remaining)
        await loadMembers()
    }
}

// MARK: - Group Member Picker
struct WatchGroupMemberPickerView: View {
    @EnvironmentObject var store: WatchStore
    @Environment(\.dismiss) private var dismiss
    let group: SystemGroup
    @State var selectedIDs: Set<String>
    let onSave: (Set<String>) -> Void

    init(group: SystemGroup, selectedMemberIDs: Set<String>, onSave: @escaping (Set<String>) -> Void) {
        self.group = group
        self._selectedIDs = State(initialValue: selectedMemberIDs)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.members) { member in
                    Button {
                        if selectedIDs.contains(member.id) {
                            selectedIDs.remove(member.id)
                        } else {
                            selectedIDs.insert(member.id)
                        }
                    } label: {
                        HStack(spacing: 10) {
                            AvatarView(member: member, size: 28)
                            Text(member.displayName ?? member.name)
                                .font(.footnote)
                                .lineLimit(1)
                            Spacer()
                            if selectedIDs.contains(member.id) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.green)
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Members")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(selectedIDs)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Add Group Sheet
struct WatchAddGroupSheet: View {
    @EnvironmentObject var store: WatchStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
            }
            .navigationTitle("New Group")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        isSaving = true
                        Task {
                            await store.createGroup(name: name)
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
    }
}

// MARK: - Add Member Sheet
struct WatchAddMemberSheet: View {
    @EnvironmentObject var store: WatchStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var pronouns = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Pronouns", text: $pronouns)
            }
            .navigationTitle("New Member")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        isSaving = true
                        Task {
                            await store.createMember(name: name, pronouns: pronouns.isEmpty ? nil : pronouns)
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
    }
}
