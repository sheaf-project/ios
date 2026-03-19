import SwiftUI

// MARK: - Custom Fields Management
struct CustomFieldsView: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    @State private var showAddField = false

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
                    Text("Custom fields let you store extra information on each member.")
                        .font(.system(size: 13))
                        .foregroundColor(theme.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .listRowBackground(Color.clear)
            } else {
                ForEach(store.fields) { field in
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
                    }
                    .listRowBackground(theme.backgroundCard)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task { await deleteField(field) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
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
                Button {
                    showAddField = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(theme.accentLight)
                }
            }
        }
        .sheet(isPresented: $showAddField, onDismiss: {
            Task { await refreshFields() }
        }) {
            AddCustomFieldSheet()
                .environmentObject(store)
        }
    }

    private func deleteField(_ field: CustomField) async {
        guard let api = store.api else { return }
        do {
            try await api.deleteField(id: field.id)
            await MainActor.run {
                store.fields.removeAll { $0.id == field.id }
            }
        } catch {
            store.errorMessage = error.localizedDescription
        }
    }

    private func refreshFields() async {
        guard let api = store.api else { return }
        store.fields = (try? await api.getFields()) ?? store.fields
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
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Name")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(theme.textSecondary)
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
        guard !name.isEmpty, let api = store.api else { return }
        isSaving = true
        error = nil
        do {
            let created = try await api.createField(CustomFieldCreate(
                name: name,
                fieldType: fieldType,
                options: nil,
                order: store.fields.count,
                privacy: privacy
            ))
            await MainActor.run {
                store.fields.append(created)
                isSaving = false
            }
            dismiss()
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isSaving = false
            }
        }
    }
}
