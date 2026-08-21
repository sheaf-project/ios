import SwiftUI

struct TagsView: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    @State private var showAddTag = false
    @State private var selectedTag: Tag?
    @State private var tagToDelete: Tag?
    @State private var showDeleteConfirm = false
    @State private var showDeleteQueued = false
    @State private var deleteQueuedInfo: DeleteQueued?

    var body: some View {
        List {
            if store.tags.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "tag")
                        .font(.title)
                        .foregroundColor(theme.textTertiary)
                    Text("No tags yet")
                        .font(.subheadline)
                        .foregroundColor(theme.textTertiary)
                    Text("Tags let you label and categorize members.")
                        .font(.footnote)
                        .foregroundColor(theme.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .listRowBackground(Color.clear)
            } else {
                ForEach(store.tags) { tag in
                    Button { selectedTag = tag } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(tag.displayColor)
                                .frame(width: 28, height: 28)
                                .overlay {
                                    Image(systemName: "tag.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white)
                                }
                            Text(tag.name)
                                .font(.subheadline).fontWeight(.medium)
                                .foregroundColor(theme.textPrimary)
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
                            tagToDelete = tag
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            selectedTag = tag
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
        .navigationTitle("Tags")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAddTag = true } label: {
                    Image(systemName: "plus").foregroundColor(theme.accentLight)
                }
            }
        }
        .sheet(isPresented: $showAddTag) {
            TagEditSheet(tag: nil)
                .environmentObject(store)
        }
        .sheet(item: $selectedTag) { tag in
            TagEditSheet(tag: tag)
                .environmentObject(store)
        }
        .confirmationDialog("Delete this tag?", isPresented: $showDeleteConfirm, presenting: tagToDelete) { tag in
            Button("Delete", role: .destructive) {
                Task {
                    let queued = await store.deleteTag(id: tag.id)
                    if let queued {
                        deleteQueuedInfo = queued
                        showDeleteQueued = true
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { tag in
            Text("This will permanently delete \"\(tag.name)\" and cannot be undone.")
        }
        .alert("Deletion Queued", isPresented: $showDeleteQueued) {
            Button("OK", role: .cancel) { deleteQueuedInfo = nil }
        } message: {
            if let info = deleteQueuedInfo {
                Text("This deletion has been queued and will finalize \(info.finalizeAfter, style: .relative). You can cancel it from System Safety settings.")
            }
        }
    }
}

// MARK: - Tag Edit Sheet

struct TagEditSheet: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var store: SystemStore
    @Environment(\.dismiss) var dismiss
    let tag: Tag?

    @State private var name = ""
    @State private var colorHex = "#F59E0B"
    @State private var isSaving = false

    var isNew: Bool { tag == nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Tag Name", text: $name)
                        .foregroundColor(theme.textPrimary)
                        .autocorrectionDisabled()
                        .listRowBackground(theme.backgroundCard)

                    HStack {
                        Text("Color").foregroundColor(theme.textPrimary)
                        Spacer()
                        ColorPicker("", selection: Binding(
                            get: { Color(hex: colorHex) ?? .orange },
                            set: { colorHex = $0.toHex() }
                        )).labelsHidden()
                    }
                    .listRowBackground(theme.backgroundCard)
                }

                Section {
                    HStack {
                        Text("Preview")
                            .foregroundColor(theme.textSecondary)
                        Spacer()
                        TagPill(name: name.isEmpty ? "Tag" : name, color: Color(hex: colorHex) ?? .orange)
                    }
                    .listRowBackground(theme.backgroundCard)
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.backgroundPrimary)
            .navigationTitle(isNew ? "New Tag" : "Edit Tag")
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
        .task { populateFields() }
    }

    func populateFields() {
        guard let t = tag else { return }
        name     = t.name
        colorHex = t.color ?? "#F59E0B"
    }

    func save() {
        isSaving = true
        Task {
            if let tag {
                let update = TagUpdate(name: name, color: colorHex.isEmpty ? nil : colorHex)
                await store.updateTag(id: tag.id, update: update)
            } else {
                let create = TagCreate(name: name, color: colorHex.isEmpty ? nil : colorHex)
                _ = await store.createTag(create)
            }
            isSaving = false
            dismiss()
        }
    }
}

// MARK: - Tag Pill

struct TagPill: View {
    @Environment(\.theme) var theme
    let name: String
    let color: Color

    var body: some View {
        Text(name)
            .font(.caption).fontWeight(.medium)
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .cornerRadius(12)
    }
}
