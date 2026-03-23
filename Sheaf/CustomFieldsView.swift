import SwiftUI

// MARK: - Custom Fields Management
struct CustomFieldsView: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    @State private var showAddField  = false
    @State private var fieldToEdit: CustomField?

    var body: some View {
        List {
            if store.fields.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 36))
                        .foregroundColor(theme.textTertiary)
                    Text("No custom fields yet")
                        .font(.system(size: 15))
                        .foregroundColor(theme.textTertiary)
                    Text("Custom fields let you store extra info on each member.")
                        .font(.system(size: 13))
                        .foregroundColor(theme.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .listRowBackground(Color.clear)
            } else {
                ForEach(store.fields) { field in
                    Button { fieldToEdit = field } label: {
                        HStack(spacing: 12) {
                            Image(systemName: fieldTypeIcon(field.fieldType))
                                .foregroundColor(theme.accentLight)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(field.name)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(theme.textPrimary)
                                Text(field.fieldType.rawValue.capitalized)
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.textSecondary)
                            }
                            Spacer()
                            Text(field.privacy.rawValue.capitalized)
                                .font(.system(size: 11))
                                .foregroundColor(theme.textTertiary)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(theme.backgroundCard)
                                .cornerRadius(6)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11))
                                .foregroundColor(theme.textTertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(theme.backgroundCard)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task { await deleteField(field) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            fieldToEdit = field
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
        .navigationTitle("Custom Fields")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAddField = true } label: {
                    Image(systemName: "plus").foregroundColor(theme.accentLight)
                }
            }
        }
        .sheet(isPresented: $showAddField, onDismiss: {
            Task { await refreshFields() }
        }) {
            AddCustomFieldSheet()
                .environmentObject(store)
        }
        .sheet(item: $fieldToEdit) { field in
            EditCustomFieldSheet(field: field)
                .environmentObject(store)
        }
    }

    private func deleteField(_ field: CustomField) async {
        await store.deleteField(id: field.id)
    }

    private func refreshFields() async {
        await store.reloadFields()
    }

    private func fieldTypeIcon(_ type: FieldType) -> String {
        switch type {
        case .text:        return "textformat"
        case .number:      return "number"
        case .date:        return "calendar"
        case .boolean:     return "togglepower"
        case .select:      return "list.bullet"
        case .multiselect: return "checklist"
        }
    }
}

// MARK: - Edit Custom Field Sheet
struct EditCustomFieldSheet: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss

    let field: CustomField
    @State private var name    = ""
    @State private var privacy: PrivacyLevel = .private
    @State private var isSaving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Field Details") {
                    TextField("Name", text: $name)
                        .foregroundColor(theme.textPrimary)
                        .autocorrectionDisabled()
                        .listRowBackground(theme.backgroundCard)

                    // Type is read-only — can't change type after creation
                    HStack {
                        Text("Type")
                            .foregroundColor(theme.textPrimary)
                        Spacer()
                        Text(field.fieldType.rawValue.capitalized)
                            .foregroundColor(theme.textSecondary)
                    }
                    .listRowBackground(theme.backgroundCard)

                    Picker("Privacy", selection: $privacy) {
                        ForEach(PrivacyLevel.allCases, id: \.self) { level in
                            Text(level.rawValue.capitalized).tag(level)
                        }
                    }
                    .foregroundColor(theme.textPrimary)
                    .listRowBackground(theme.backgroundCard)
                }

                if let error {
                    Section {
                        Text(error)
                            .foregroundColor(theme.danger)
                            .font(.system(size: 13))
                            .listRowBackground(theme.backgroundCard)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.backgroundPrimary)
            .navigationTitle("Edit Field")
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
                                .foregroundColor(name.isEmpty ? theme.textTertiary : theme.accentLight)
                        }
                    }
                    .disabled(name.isEmpty || isSaving)
                }
            }
        }
        .onAppear {
            name    = field.name
            privacy = field.privacy
        }
    }

    private func save() async {
        isSaving = true
        error = nil
        await store.updateField(id: field.id, name: name, privacy: privacy)
        isSaving = false
        dismiss()
    }
}

// MARK: - Add Custom Field Sheet
struct AddCustomFieldSheet: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var fieldType: FieldType = .text
    @State private var privacy: PrivacyLevel = .private
    @State private var isSaving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Field Details") {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("e.g. Age, Occupation", text: $name)
                            .autocorrectionDisabled()
                    }
                    .listRowBackground(theme.backgroundCard)

                    Picker("Type", selection: $fieldType) {
                        ForEach(FieldType.allCases, id: \.self) { type in
                            Text(type.rawValue.capitalized).tag(type)
                        }
                    }
                    .listRowBackground(theme.backgroundCard)
                    .foregroundColor(theme.textPrimary)

                    Picker("Privacy", selection: $privacy) {
                        ForEach(PrivacyLevel.allCases, id: \.self) { level in
                            Text(level.rawValue.capitalized).tag(level)
                        }
                    }
                    .listRowBackground(theme.backgroundCard)
                    .foregroundColor(theme.textPrimary)
                }

                if let error {
                    Section {
                        Text(error)
                            .foregroundColor(theme.danger)
                            .font(.system(size: 13))
                            .listRowBackground(theme.backgroundCard)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.backgroundPrimary)
            .navigationTitle("New Field")
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
                                .foregroundColor(name.isEmpty ? theme.textTertiary : theme.accentLight)
                        }
                    }
                    .disabled(name.isEmpty || isSaving)
                }
            }
        }
    }

    private func save() async {
        guard !name.isEmpty else { return }
        isSaving = true
        error = nil
        _ = await store.createField(CustomFieldCreate(
            name: name,
            fieldType: fieldType,
            options: nil,
            order: store.fields.count,
            privacy: privacy
        ))
        isSaving = false
        dismiss()
    }
}
