import SwiftUI

// MARK: - Members list page
struct WatchMembersView: View {
    @EnvironmentObject var store: WatchStore
    @State private var showAddMember = false

    var body: some View {
        List {
            if store.isLoading && store.members.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if store.members.isEmpty {
                Text("No members")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            } else {
                ForEach(store.members) { member in
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
                    Text(member.displayName ?? member.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)

                    if let pronouns = member.pronouns, !pronouns.isEmpty {
                        Text(pronouns)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    if isFronting {
                        Label("Fronting", systemImage: "checkmark.seal.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.green)
                            .padding(.top, 2)
                    }
                }

                // Description
                if let desc = member.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 11))
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
                            .font(.system(size: 13))
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
                            .font(.system(size: 13))
                    }
                    .tint(.purple)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle)

                    Button {
                        Task { await store.switchFronting(to: [member.id]) }
                    } label: {
                        Label("Switch to Only Fronter", systemImage: "arrow.left.arrow.right")
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle)
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle(member.displayName ?? member.name)
        .navigationBarTitleDisplayMode(.inline)
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
                Text(member.displayName ?? member.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                if let pronouns = member.pronouns, !pronouns.isEmpty {
                    Text(pronouns)
                        .font(.system(size: 10))
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
