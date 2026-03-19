import SwiftUI

struct GroupsView: View {
    @EnvironmentObject var store: SystemStore
    @State private var showAddGroup = false
    @State private var selectedGroup: SystemGroup?

    var body: some View {
        ZStack {
            Color(hex: "#0F0C29")!.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("Groups")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    Button {
                        showAddGroup = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(Color(hex: "#A78BFA")!)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 20)

                if store.isLoading && store.groups.isEmpty {
                    Spacer()
                    ProgressView().tint(Color(hex: "#A78BFA")!)
                    Spacer()
                } else if store.groups.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 44))
                            .foregroundColor(.white.opacity(0.2))
                        Text("No groups yet")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                        Text("Tap + to create your first group")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.25))
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
                        .foregroundColor(.white)

                    if let desc = group.description, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(1)
                    }

                    // Stacked avatars
                    if !members.isEmpty {
                        HStack(spacing: -10) {
                            ForEach(members.prefix(5)) { m in
                                AvatarView(member: m, size: 26)
                                    .overlay(Circle().stroke(Color(hex: "#0F0C29")!, lineWidth: 1.5))
                            }
                            if members.count > 5 {
                                ZStack {
                                    Circle().fill(Color.white.opacity(0.1)).frame(width: 26, height: 26)
                                    Text("+\(members.count - 5)")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            Text("\(members.count) member\(members.count == 1 ? "" : "s")")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.4))
                                .padding(.leading, 14)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.25))
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(18)
            .overlay(RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.07), lineWidth: 1))
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Group Detail Sheet
struct GroupDetailSheet: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.dismiss) var dismiss
    let group: SystemGroup
    @State private var showEdit = false
    @State private var members: [Member] = []

    var body: some View {
        ZStack {
            Color(hex: "#0F0C29")!.ignoresSafeArea()

            VStack(spacing: 0) {
                Capsule().fill(Color.white.opacity(0.2)).frame(width: 40, height: 4).padding(.top, 12)

                HStack {
                    Button("Close") { dismiss() }.foregroundColor(.white.opacity(0.5))
                    Spacer()
                    Button("Edit") { showEdit = true }
                        .foregroundColor(Color(hex: "#A78BFA")!)
                        .font(.system(size: 16, weight: .semibold))
                }
                .padding(.horizontal, 24).padding(.top, 16)

                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(group.displayColor.opacity(0.2))
                                    .frame(width: 80, height: 80)
                                Image(systemName: "square.grid.2x2.fill")
                                    .font(.system(size: 34))
                                    .foregroundColor(group.displayColor)
                            }
                            Text(group.name)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            if let desc = group.description, !desc.isEmpty {
                                Text(desc)
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.6))
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.top, 20)

                        // Members
                        if members.isEmpty {
                            Text("No members in this group")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.35))
                                .padding(20)
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Members (\(members.count))")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.5))
                                    .textCase(.uppercase)
                                    .kerning(0.8)

                                ForEach(members) { member in
                                    HStack(spacing: 12) {
                                        AvatarView(member: member, size: 40)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(member.displayName ?? member.name)
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(.white)
                                            if let p = member.pronouns, !p.isEmpty {
                                                Text(p).font(.system(size: 12)).foregroundColor(.white.opacity(0.45))
                                            }
                                        }
                                        Spacer()
                                        if store.frontingMembers.contains(where: { $0.id == member.id }) {
                                            Circle().fill(Color(hex: "#4ADE80")!).frame(width: 8, height: 8)
                                        }
                                    }
                                    .padding(12)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(12)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 60)
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
}

// MARK: - Group Edit Sheet
struct GroupEditSheet: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.dismiss) var dismiss
    let group: SystemGroup?

    @State private var name = ""
    @State private var description = ""
    @State private var colorHex = "#6366F1"
    @State private var selectedMemberIDs: Set<String> = []
    @State private var isSaving = false

    var isNew: Bool { group == nil }

    var body: some View {
        ZStack {
            Color(hex: "#0F0C29")!.ignoresSafeArea()

            VStack(spacing: 0) {
                Capsule().fill(Color.white.opacity(0.2)).frame(width: 40, height: 4).padding(.top, 12)

                HStack {
                    Button("Cancel") { dismiss() }.foregroundColor(.white.opacity(0.5))
                    Spacer()
                    Text(isNew ? "New Group" : "Edit Group")
                        .font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
                    Spacer()
                    Button(isSaving ? "" : "Save") { save() }
                        .foregroundColor(Color(hex: "#A78BFA")!)
                        .font(.system(size: 16, weight: .semibold))
                        .overlay(isSaving ? AnyView(ProgressView().tint(Color(hex: "#A78BFA")!)) : AnyView(EmptyView()))
                        .disabled(name.isEmpty || isSaving)
                }
                .padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 8)

                ScrollView {
                    VStack(spacing: 16) {
                        fieldView("Group Name *", value: $name, placeholder: "e.g. Inner Circle")
                        fieldView("Description", value: $description, placeholder: "Optional description")

                        // Color
                        HStack {
                            Text("Color").font(.system(size: 14, weight: .medium)).foregroundColor(.white.opacity(0.7))
                            Spacer()
                            ColorPicker("", selection: Binding(
                                get: { Color(hex: colorHex) ?? .indigo },
                                set: { colorHex = $0.toHex() }
                            )).labelsHidden()
                        }
                        .padding(14).background(Color.white.opacity(0.06)).cornerRadius(12)

                        // Members
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Members")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.55))

                            ForEach(store.members) { member in
                                Button {
                                    if selectedMemberIDs.contains(member.id) {
                                        selectedMemberIDs.remove(member.id)
                                    } else {
                                        selectedMemberIDs.insert(member.id)
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        AvatarView(member: member, size: 36)
                                        Text(member.displayName ?? member.name)
                                            .font(.system(size: 15))
                                            .foregroundColor(.white)
                                        Spacer()
                                        Image(systemName: selectedMemberIDs.contains(member.id) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedMemberIDs.contains(member.id) ? Color(hex: "#A78BFA")! : Color.white.opacity(0.3))
                                            .font(.system(size: 20))
                                    }
                                    .padding(12)
                                    .background(selectedMemberIDs.contains(member.id) ? Color(hex: "#A78BFA")!.opacity(0.08) : Color.white.opacity(0.04))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(ScaleButtonStyle())
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

    func fieldView(_ label: String, value: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 13, weight: .semibold)).foregroundColor(.white.opacity(0.55))
            TextField(placeholder, text: value)
                .autocorrectionDisabled().autocapitalization(.none)
                .padding(12).background(Color.white.opacity(0.06)).cornerRadius(12).foregroundColor(.white)
        }
    }

    func populateFields() {
        guard let g = group else { return }
        name = g.name
        description = g.description ?? ""
        colorHex = g.color ?? "#6366F1"
        // selectedMemberIDs loaded from API separately if needed
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
            // Update group members separately after group is saved
            if let savedGroup = store.groups.first(where: { $0.name == name }) {
                await store.setGroupMembers(groupID: savedGroup.id, memberIDs: Array(selectedMemberIDs))
            }
            isSaving = false
            dismiss()
        }
    }
}
