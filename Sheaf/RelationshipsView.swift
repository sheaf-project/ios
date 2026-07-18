import SwiftUI

// MARK: - Relationship Types Management
struct RelationshipTypesView: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    @State private var showAddType = false
    @State private var typeToEdit: RelationshipType?
    @State private var typeToDelete: RelationshipType?

    var body: some View {
        List {
            if store.relationshipTypes.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "person.line.dotted.person")
                        .font(.title)
                        .foregroundColor(theme.textTertiary)
                    Text("No relationship types yet")
                        .font(.subheadline)
                        .foregroundColor(theme.textTertiary)
                    Text("Relationship types define how members or groups can be linked, like partner or protector. Tap + to create one, or start from a preset.")
                        .font(.footnote)
                        .foregroundColor(theme.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .listRowBackground(Color.clear)
            } else {
                ForEach(store.relationshipTypes) { type in
                    Button { typeToEdit = type } label: {
                        HStack(spacing: 12) {
                            Image(systemName: symmetryIcon(type.symmetry))
                                .foregroundColor(theme.accentLight)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(type.name)
                                    .font(.subheadline).fontWeight(.medium)
                                    .foregroundColor(theme.textPrimary)
                                Text(labelSummary(type))
                                    .font(.caption)
                                    .foregroundColor(theme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(theme.textTertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(theme.backgroundCard)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            typeToDelete = type
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            typeToEdit = type
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(theme.accentLight)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.backgroundPrimary)
        .navigationTitle("Relationships")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                NavigationLink {
                    RelationshipGraphView()
                        .environmentObject(store)
                } label: {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .foregroundColor(theme.accentLight)
                }
                .accessibilityLabel("Relationship Graph")

                Button { showAddType = true } label: {
                    Image(systemName: "plus").foregroundColor(theme.accentLight)
                }
            }
        }
        .sheet(isPresented: $showAddType) {
            AddRelationshipTypeSheet()
                .environmentObject(store)
        }
        .sheet(item: $typeToEdit) { type in
            EditRelationshipTypeSheet(type: type)
                .environmentObject(store)
        }
        .alert(
            "Delete \"\(typeToDelete?.name ?? "")\"?",
            isPresented: Binding(
                get: { typeToDelete != nil },
                set: { if !$0 { typeToDelete = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                if let type = typeToDelete {
                    Task { await store.deleteRelationshipType(id: type.id) }
                }
                typeToDelete = nil
            }
            Button("Cancel", role: .cancel) { typeToDelete = nil }
        } message: {
            Text("This also removes every relationship between members or groups that uses this type. This cannot be undone.")
        }
        .task {
            await store.reloadRelationshipTypes()
        }
    }

    private func symmetryIcon(_ symmetry: RelationshipSymmetry) -> String {
        switch symmetry {
        case .symmetric:   return "arrow.left.arrow.right"
        case .directional: return "arrow.right"
        case .either:      return "arrow.left.and.right.circle"
        }
    }

    private func labelSummary(_ type: RelationshipType) -> String {
        if type.symmetry == .symmetric { return type.forwardLabel }
        if let reverse = type.reverseLabel, !reverse.isEmpty {
            return "\(type.forwardLabel) / \(reverse)"
        }
        return type.forwardLabel
    }
}

// MARK: - Add Relationship Type Sheet
struct AddRelationshipTypeSheet: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var symmetry: RelationshipSymmetry = .symmetric
    @State private var forwardLabel = ""
    @State private var reverseLabel = ""
    @State private var isSaving = false

    private var needsReverseLabel: Bool { symmetry != .symmetric }

    private var canSave: Bool {
        !name.isEmpty && !forwardLabel.isEmpty && (!needsReverseLabel || !reverseLabel.isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Menu {
                        ForEach(relationshipPresets, id: \.label) { preset in
                            Button(preset.label) {
                                name         = preset.name
                                symmetry     = preset.symmetry
                                forwardLabel = preset.forwardLabel
                                reverseLabel = preset.reverseLabel ?? ""
                            }
                        }
                    } label: {
                        HStack {
                            Text("Start from a preset")
                                .foregroundColor(theme.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption)
                                .foregroundColor(theme.textTertiary)
                        }
                    }
                    .listRowBackground(theme.backgroundCard)

                    TextField("Name, e.g. Partner", text: $name)
                        .autocorrectionDisabled()
                        .listRowBackground(theme.backgroundCard)

                    Picker("Direction", selection: $symmetry) {
                        Text("Same both ways").tag(RelationshipSymmetry.symmetric)
                        Text("One-way").tag(RelationshipSymmetry.directional)
                        Text("Either").tag(RelationshipSymmetry.either)
                    }
                    .listRowBackground(theme.backgroundCard)
                    .foregroundColor(theme.textPrimary)
                } header: {
                    Text("Type Details")
                } footer: {
                    Text(symmetryHint)
                        .font(.caption)
                        .foregroundColor(theme.textTertiary)
                }

                Section("Labels") {
                    TextField(needsReverseLabel ? "Label, e.g. parent" : "Label, e.g. partner", text: $forwardLabel)
                        .autocorrectionDisabled()
                        .listRowBackground(theme.backgroundCard)
                    if needsReverseLabel {
                        TextField("Reverse label, e.g. child", text: $reverseLabel)
                            .autocorrectionDisabled()
                            .listRowBackground(theme.backgroundCard)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.backgroundPrimary)
            .navigationTitle("New Relationship Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(theme.accentLight)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving { ProgressView().tint(theme.accentLight) }
                        else {
                            Text("Add")
                                .fontWeight(.semibold)
                                .foregroundColor(canSave ? theme.accentLight : theme.textTertiary)
                        }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
        }
    }

    private var symmetryHint: String {
        switch symmetry {
        case .symmetric:
            return "Both members share one label, like partner or sibling."
        case .directional:
            return "Each side reads differently, like parent and child."
        case .either:
            return "Works one-way like protector and protectee, but a link can also be marked mutual."
        }
    }

    private func save() async {
        guard canSave else { return }
        isSaving = true
        _ = await store.createRelationshipType(RelationshipTypeCreate(
            name: name.trimmingCharacters(in: .whitespaces),
            symmetry: symmetry,
            forwardLabel: forwardLabel.trimmingCharacters(in: .whitespaces),
            reverseLabel: needsReverseLabel ? reverseLabel.trimmingCharacters(in: .whitespaces) : nil
        ))
        isSaving = false
        dismiss()
    }
}

// MARK: - Edit Relationship Type Sheet
struct EditRelationshipTypeSheet: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss

    let type: RelationshipType
    @State private var name = ""
    @State private var forwardLabel = ""
    @State private var reverseLabel = ""
    @State private var isSaving = false

    private var needsReverseLabel: Bool { type.symmetry != .symmetric }

    private var canSave: Bool {
        !name.isEmpty && !forwardLabel.isEmpty && (!needsReverseLabel || !reverseLabel.isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Type Details") {
                    TextField("Name", text: $name)
                        .autocorrectionDisabled()
                        .listRowBackground(theme.backgroundCard)

                    // Direction is read-only, it can't change after creation
                    HStack {
                        Text("Direction")
                            .foregroundColor(theme.textPrimary)
                        Spacer()
                        Text(symmetryLabel)
                            .foregroundColor(theme.textSecondary)
                    }
                    .listRowBackground(theme.backgroundCard)
                }

                Section("Labels") {
                    TextField("Label", text: $forwardLabel)
                        .autocorrectionDisabled()
                        .listRowBackground(theme.backgroundCard)
                    if needsReverseLabel {
                        TextField("Reverse label", text: $reverseLabel)
                            .autocorrectionDisabled()
                            .listRowBackground(theme.backgroundCard)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.backgroundPrimary)
            .navigationTitle("Edit Relationship Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(theme.accentLight)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving { ProgressView().tint(theme.accentLight) }
                        else {
                            Text("Save")
                                .fontWeight(.semibold)
                                .foregroundColor(canSave ? theme.accentLight : theme.textTertiary)
                        }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
        }
        .onAppear {
            name         = type.name
            forwardLabel = type.forwardLabel
            reverseLabel = type.reverseLabel ?? ""
        }
    }

    private var symmetryLabel: String {
        switch type.symmetry {
        case .symmetric:   return "Same both ways"
        case .directional: return "One-way"
        case .either:      return "Either"
        }
    }

    private func save() async {
        guard canSave else { return }
        isSaving = true
        _ = await store.updateRelationshipType(id: type.id, update: RelationshipTypeUpdate(
            name: name.trimmingCharacters(in: .whitespaces),
            forwardLabel: forwardLabel.trimmingCharacters(in: .whitespaces),
            reverseLabel: needsReverseLabel ? reverseLabel.trimmingCharacters(in: .whitespaces) : nil
        ))
        isSaving = false
        dismiss()
    }
}

// MARK: - Add Relationship Sheet
struct AddRelationshipSheet: View {
    enum Scope {
        case member
        case group
    }

    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss

    var scope: Scope = .member
    let nodeID: String
    let nodeName: String
    var onAdded: () -> Void

    @State private var typeID: String = ""
    @State private var otherID: String = ""
    @State private var nodeIsSource = true
    @State private var mutual = false
    @State private var isSaving = false

    private var selectedType: RelationshipType? {
        store.relationshipTypes.first { $0.id == typeID }
    }

    private var candidates: [(id: String, name: String)] {
        let all: [(id: String, name: String)]
        switch scope {
        case .member:
            all = store.members
                .filter { $0.id != nodeID && !$0.isArchived }
                .map { (id: $0.id, name: $0.displayName ?? $0.name) }
        case .group:
            all = store.groups
                .filter { $0.id != nodeID }
                .map { (id: $0.id, name: $0.name) }
        }
        return all.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    private var canSave: Bool {
        selectedType != nil && !otherID.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $typeID) {
                        Text("Choose").tag("")
                        ForEach(store.relationshipTypes) { type in
                            Text(type.name).tag(type.id)
                        }
                    }
                    .listRowBackground(theme.backgroundCard)
                    .foregroundColor(theme.textPrimary)

                    Picker("With", selection: $otherID) {
                        Text("Choose").tag("")
                        ForEach(candidates, id: \.id) { c in
                            Text(c.name).tag(c.id)
                        }
                    }
                    .listRowBackground(theme.backgroundCard)
                    .foregroundColor(theme.textPrimary)
                }

                if let type = selectedType, type.symmetry != .symmetric {
                    Section {
                        if type.symmetry == .either {
                            Toggle("Mutual (both are \(type.forwardLabel))", isOn: $mutual)
                                .listRowBackground(theme.backgroundCard)
                                .foregroundColor(theme.textPrimary)
                        }
                        if !mutual {
                            Picker("\(nodeName) is", selection: $nodeIsSource) {
                                Text(type.forwardLabel).tag(true)
                                Text(type.reverseLabel ?? "").tag(false)
                            }
                            .listRowBackground(theme.backgroundCard)
                            .foregroundColor(theme.textPrimary)
                        }
                    }
                }
            }
            .onChange(of: typeID) { _, _ in
                nodeIsSource = true
                mutual = false
            }
            .scrollContentBackground(.hidden)
            .background(theme.backgroundPrimary)
            .navigationTitle("Add Relationship")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(theme.accentLight)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving { ProgressView().tint(theme.accentLight) }
                        else {
                            Text("Add")
                                .fontWeight(.semibold)
                                .foregroundColor(canSave ? theme.accentLight : theme.textTertiary)
                        }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
        }
    }

    private func save() async {
        guard let type = selectedType, canSave else { return }
        isSaving = true
        let effectiveMutual = mutual && type.symmetry == .either
        let create = RelationshipEdgeCreate(
            sourceID: nodeIsSource || effectiveMutual || type.symmetry == .symmetric ? nodeID : otherID,
            targetID: nodeIsSource || effectiveMutual || type.symmetry == .symmetric ? otherID : nodeID,
            relationshipTypeID: typeID,
            mutual: effectiveMutual
        )
        let created: RelationshipEdge?
        switch scope {
        case .member: created = await store.createMemberRelationship(create)
        case .group:  created = await store.createGroupRelationship(create)
        }
        isSaving = false
        if created != nil {
            onAdded()
            dismiss()
        }
    }
}
