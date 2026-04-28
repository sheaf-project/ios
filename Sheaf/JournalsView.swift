import SwiftUI

struct JournalsView: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var selectedEntry: JournalEntry?
    @State private var showNewEntry = false
    @State private var entryToDelete: JournalEntry?
    @State private var showDeleteConfirm = false
    @State private var showDeleteQueued = false
    @State private var deleteQueuedInfo: DeleteQueued?

    var body: some View {
        ZStack {
            theme.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("Journal")
                        .font(.title2).fontWeight(.bold).fontDesign(.rounded)
                        .foregroundColor(theme.textPrimary)
                    Spacer()
                    HStack(spacing: 16) {
                        Button {
                            showNewEntry = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundColor(theme.accentLight)
                        }
                        Button {
                            Task { await reload() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.subheadline).fontWeight(.semibold)
                                .foregroundColor(theme.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 20)

                if isLoading && store.journalEntries.isEmpty {
                    Spacer()
                    ProgressView().tint(theme.accentLight)
                    Spacer()
                } else if store.journalEntries.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "book")
                            .font(.largeTitle)
                            .foregroundColor(theme.textTertiary)
                        Text("No journal entries yet")
                            .font(.body).fontWeight(.medium).fontDesign(.rounded)
                            .foregroundColor(theme.textTertiary)
                        Text("Tap + to write your first entry.")
                            .font(.footnote)
                            .foregroundColor(theme.textTertiary)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(store.journalEntries) { entry in
                            Button { selectedEntry = entry } label: {
                                JournalEntryRow(entry: entry, members: store.members)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    entryToDelete = entry
                                    showDeleteConfirm = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 5, leading: 24, bottom: 5, trailing: 24))
                            .onAppear {
                                if entry.id == store.journalEntries.last?.id {
                                    Task { await loadMore() }
                                }
                            }
                        }

                        if store.hasMoreJournals {
                            HStack {
                                Spacer()
                                if isLoadingMore {
                                    ProgressView().tint(theme.accentLight)
                                } else {
                                    Button("Load More") {
                                        Task { await loadMore() }
                                    }
                                    .font(.subheadline).fontWeight(.medium)
                                    .foregroundColor(theme.accentLight)
                                }
                                Spacer()
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .padding(.vertical, 8)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(theme.backgroundPrimary)
                    .refreshable {
                        await reload()
                    }
                }
            }
        }
        .task { await reload() }
        .sheet(isPresented: $showNewEntry, onDismiss: { Task { await reload() } }) {
            JournalEditSheet(entry: nil)
                .environmentObject(store)
        }
        .sheet(item: $selectedEntry, onDismiss: { Task { await reload() } }) { entry in
            JournalDetailSheet(entry: entry)
                .environmentObject(store)
        }
        .confirmationDialog("Delete this journal entry?", isPresented: $showDeleteConfirm, presenting: entryToDelete) { entry in
            Button("Delete", role: .destructive) {
                Task {
                    let queued = await store.deleteJournal(id: entry.id)
                    if let queued {
                        deleteQueuedInfo = queued
                        showDeleteQueued = true
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("This will permanently delete this journal entry and cannot be undone.")
        }
        .alert("Deletion Queued", isPresented: $showDeleteQueued) {
            Button("OK", role: .cancel) { deleteQueuedInfo = nil }
        } message: {
            if let info = deleteQueuedInfo {
                Text("This deletion has been queued and will finalize \(info.finalizeAfter, style: .relative). You can cancel it from System Safety settings.")
            }
        }
    }

    func reload() async {
        isLoading = true
        await store.loadJournals()
        isLoading = false
    }

    func loadMore() async {
        guard !isLoadingMore else { return }
        isLoadingMore = true
        await store.loadMoreJournals()
        isLoadingMore = false
    }
}

// MARK: - Journal Entry Row

struct JournalEntryRow: View {
    @Environment(\.theme) var theme
    let entry: JournalEntry
    let members: [Member]

    private var authorNames: String {
        if !entry.authorMemberNames.isEmpty {
            return entry.authorMemberNames.joined(separator: ", ")
        }
        return "System"
    }

    private var displayTitle: String {
        if let title = entry.title, !title.isEmpty {
            return title
        }
        let firstLine = entry.body.components(separatedBy: .newlines).first ?? entry.body
        return String(firstLine.prefix(60))
    }

    private var bodyPreview: String {
        let text = entry.body.trimmingCharacters(in: .whitespacesAndNewlines)
        if entry.title != nil && !entry.title!.isEmpty {
            return String(text.prefix(120))
        }
        let lines = text.components(separatedBy: .newlines).dropFirst()
        let remaining = lines.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        return String(remaining.prefix(120))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(displayTitle)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
                Spacer()
                Text(entry.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundColor(theme.textTertiary)
            }

            if !bodyPreview.isEmpty {
                Text(bodyPreview)
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(2)
            }

            HStack(spacing: 6) {
                Image(systemName: "person.fill")
                    .font(.system(size: 9))
                    .foregroundColor(theme.textTertiary)
                Text(authorNames)
                    .font(.caption2)
                    .foregroundColor(theme.textTertiary)

                if let memberID = entry.memberID,
                   let member = members.first(where: { $0.id == memberID }) {
                    Text("\u{00B7}")
                        .foregroundColor(theme.textTertiary)
                    Circle()
                        .fill(member.displayColor)
                        .frame(width: 8, height: 8)
                    Text(member.displayName ?? member.name)
                        .font(.caption2)
                        .foregroundColor(theme.textTertiary)
                }
            }
        }
        .padding(14)
        .background(theme.backgroundCard)
        .cornerRadius(14)
    }
}

// MARK: - Journal Detail Sheet

struct JournalDetailSheet: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var store: SystemStore
    @Environment(\.dismiss) var dismiss
    let entry: JournalEntry
    @State private var showEdit = false
    @State private var showRevisions = false
    @State private var showDeleteConfirm = false
    @State private var showDeleteQueued = false
    @State private var deleteQueuedInfo: DeleteQueued?

    private var authorNames: String {
        if !entry.authorMemberNames.isEmpty {
            return entry.authorMemberNames.joined(separator: ", ")
        }
        return "System"
    }

    private var scopeLabel: String {
        if let memberID = entry.memberID,
           let member = store.members.first(where: { $0.id == memberID }) {
            return member.displayName ?? member.name
        }
        return "System-wide"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Title
                    if let title = entry.title, !title.isEmpty {
                        Text(title)
                            .font(.title2).fontWeight(.bold).fontDesign(.rounded)
                            .foregroundColor(theme.textPrimary)
                    }

                    // Metadata
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "person.fill")
                                .font(.caption)
                                .foregroundColor(theme.textTertiary)
                            Text(authorNames)
                                .font(.subheadline)
                                .foregroundColor(theme.textSecondary)
                        }

                        HStack(spacing: 8) {
                            Image(systemName: entry.memberID != nil ? "person.crop.circle" : "globe")
                                .font(.caption)
                                .foregroundColor(theme.textTertiary)
                            Text(scopeLabel)
                                .font(.subheadline)
                                .foregroundColor(theme.textSecondary)
                        }

                        HStack(spacing: 8) {
                            Image(systemName: "calendar")
                                .font(.caption)
                                .foregroundColor(theme.textTertiary)
                            Text(entry.createdAt, format: .dateTime.month(.wide).day().year().hour().minute())
                                .font(.subheadline)
                                .foregroundColor(theme.textSecondary)
                        }

                        if entry.updatedAt != entry.createdAt {
                            HStack(spacing: 8) {
                                Image(systemName: "pencil")
                                    .font(.caption)
                                    .foregroundColor(theme.textTertiary)
                                Text("Edited \(entry.updatedAt, style: .relative) ago")
                                    .font(.subheadline)
                                    .foregroundColor(theme.textSecondary)
                            }
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.backgroundCard)
                    .cornerRadius(14)

                    // Body
                    MarkdownText(entry.body, color: theme.textPrimary)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(theme.backgroundPrimary)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(theme.accentLight)
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        showRevisions = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(theme.accentLight)
                    }
                    .accessibilityLabel("Revisions")

                    Button {
                        showEdit = true
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundColor(theme.accentLight)
                    }
                    .accessibilityLabel("Edit")

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(theme.danger)
                    }
                    .accessibilityLabel("Delete")
                }
            }
        }
        .sheet(isPresented: $showEdit, onDismiss: { dismiss() }) {
            JournalEditSheet(entry: entry)
                .environmentObject(store)
        }
        .sheet(isPresented: $showRevisions) {
            JournalRevisionsView(entry: entry)
                .environmentObject(store)
        }
        .confirmationDialog("Delete this journal entry?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                Task {
                    let queued = await store.deleteJournal(id: entry.id)
                    if let queued {
                        deleteQueuedInfo = queued
                        showDeleteQueued = true
                    } else {
                        dismiss()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete this journal entry and cannot be undone.")
        }
        .alert("Deletion Queued", isPresented: $showDeleteQueued) {
            Button("OK", role: .cancel) {
                deleteQueuedInfo = nil
                dismiss()
            }
        } message: {
            if let info = deleteQueuedInfo {
                Text("This deletion has been queued and will finalize \(info.finalizeAfter, style: .relative). You can cancel it from System Safety settings.")
            }
        }
    }
}

// MARK: - Journal Revisions View

struct JournalRevisionsView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var store: SystemStore
    @Environment(\.dismiss) var dismiss
    let entry: JournalEntry
    @State private var revisions: [ContentRevision] = []
    @State private var isLoading = true
    @State private var selectedRevision: ContentRevision?
    @State private var showRestoreConfirm = false
    @State private var isRestoring = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView().tint(theme.accentLight)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if revisions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.largeTitle)
                            .foregroundColor(theme.textTertiary)
                        Text("No revisions")
                            .font(.body).fontWeight(.medium).fontDesign(.rounded)
                            .foregroundColor(theme.textTertiary)
                        Text("Revisions are created when an entry is edited.")
                            .font(.footnote)
                            .foregroundColor(theme.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(revisions) { revision in
                            Button {
                                selectedRevision = revision
                            } label: {
                                RevisionRow(revision: revision)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 5, leading: 24, bottom: 5, trailing: 24))
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(theme.backgroundPrimary)
            .navigationTitle("Revisions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(theme.accentLight)
                }
            }
        }
        .sheet(item: $selectedRevision) { revision in
            RevisionDetailView(entry: entry, revision: revision) {
                dismiss()
            }
            .environmentObject(store)
        }
        .task { await loadRevisions() }
    }

    func loadRevisions() async {
        isLoading = true
        if let fetched = try? await store.api?.getJournalRevisions(entryID: entry.id) {
            revisions = fetched
        }
        isLoading = false
    }
}

// MARK: - Revision Row

struct RevisionRow: View {
    @Environment(\.theme) var theme
    let revision: ContentRevision

    private var editorNames: String {
        if !revision.editorMemberNames.isEmpty {
            return revision.editorMemberNames.joined(separator: ", ")
        }
        return "System"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let title = revision.title, !title.isEmpty {
                    Text(title)
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)
                } else {
                    Text("Untitled")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundColor(theme.textTertiary)
                        .italic()
                }
                Spacer()
                Text(revision.createdAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(.caption2)
                    .foregroundColor(theme.textTertiary)
            }

            Text(revision.body.prefix(120))
                .font(.caption)
                .foregroundColor(theme.textSecondary)
                .lineLimit(2)

            HStack(spacing: 6) {
                Image(systemName: "person.fill")
                    .font(.system(size: 9))
                    .foregroundColor(theme.textTertiary)
                Text(editorNames)
                    .font(.caption2)
                    .foregroundColor(theme.textTertiary)
            }
        }
        .padding(14)
        .background(theme.backgroundCard)
        .cornerRadius(14)
    }
}

// MARK: - Revision Detail View

struct RevisionDetailView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var store: SystemStore
    @Environment(\.dismiss) var dismiss
    let entry: JournalEntry
    let revision: ContentRevision
    var onRestored: (() -> Void)?
    @State private var showRestoreConfirm = false
    @State private var isRestoring = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Revision metadata
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar")
                                .font(.caption)
                                .foregroundColor(theme.textTertiary)
                            Text(revision.createdAt, format: .dateTime.month(.wide).day().year().hour().minute())
                                .font(.subheadline)
                                .foregroundColor(theme.textSecondary)
                        }
                        if !revision.editorMemberNames.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "person.fill")
                                    .font(.caption)
                                    .foregroundColor(theme.textTertiary)
                                Text(revision.editorMemberNames.joined(separator: ", "))
                                    .font(.subheadline)
                                    .foregroundColor(theme.textSecondary)
                            }
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.backgroundCard)
                    .cornerRadius(14)

                    // Title
                    if let title = revision.title, !title.isEmpty {
                        Text(title)
                            .font(.title3).fontWeight(.bold)
                            .foregroundColor(theme.textPrimary)
                    }

                    // Body
                    MarkdownText(revision.body, color: theme.textPrimary)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Restore button
                    Button {
                        showRestoreConfirm = true
                    } label: {
                        HStack {
                            if isRestoring {
                                ProgressView().tint(.white).scaleEffect(0.8)
                            }
                            Label("Restore this version", systemImage: "arrow.uturn.backward")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(theme.accentLight)
                    .disabled(isRestoring)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(theme.backgroundPrimary)
            .navigationTitle("Revision")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(theme.accentLight)
                }
            }
        }
        .confirmationDialog("Restore this version?", isPresented: $showRestoreConfirm) {
            Button("Restore") {
                Task {
                    isRestoring = true
                    _ = try? await store.api?.restoreJournalRevision(entryID: entry.id, revisionID: revision.id)
                    isRestoring = false
                    dismiss()
                    onRestored?()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The current entry content will be saved as a revision, and this version will become the current content.")
        }
    }
}

// MARK: - Journal Edit Sheet

struct JournalEditSheet: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var store: SystemStore
    @Environment(\.dismiss) var dismiss
    let entry: JournalEntry?

    @State private var title = ""
    @State private var bodyText = ""
    @State private var selectedMemberID: String?
    @State private var selectedAuthorIDs: Set<String> = []
    @State private var isSaving = false
    @State private var showPreview = false

    var isNew: Bool { entry == nil }

    private var authorSummary: String {
        let names = store.members
            .filter { selectedAuthorIDs.contains($0.id) }
            .map { $0.displayName ?? $0.name }
        if names.isEmpty { return "None selected" }
        return names.joined(separator: ", ")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Entry title (optional)", text: $title)
                        .foregroundColor(theme.textPrimary)
                        .listRowBackground(theme.backgroundCard)
                }

                Section {
                    if showPreview {
                        if bodyText.isEmpty {
                            Text("Nothing to preview")
                                .foregroundColor(theme.textTertiary)
                                .italic()
                                .frame(maxWidth: .infinity, minHeight: 200, alignment: .topLeading)
                        } else {
                            ScrollView {
                                MarkdownText(bodyText, color: theme.textPrimary)
                                    .font(.body)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(minHeight: 200)
                        }
                    } else {
                        TextEditor(text: $bodyText)
                            .foregroundColor(theme.textPrimary)
                            .frame(minHeight: 200)
                    }
                } header: {
                    HStack {
                        Text("Content")
                        Spacer()
                        Button {
                            showPreview.toggle()
                        } label: {
                            Label(showPreview ? "Edit" : "Preview", systemImage: showPreview ? "pencil" : "eye")
                                .font(.caption)
                                .foregroundColor(theme.accentLight)
                        }
                    }
                }
                .listRowBackground(theme.backgroundCard)

                if !showPreview {
                    Section {
                        MarkdownToolbar(text: $bodyText)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                }

                if !store.members.isEmpty {
                    Section("Author") {
                        NavigationLink {
                            JournalAuthorPicker(
                                selectedAuthorIDs: $selectedAuthorIDs,
                                members: store.members
                            )
                        } label: {
                            HStack {
                                Text(authorSummary)
                                    .foregroundColor(selectedAuthorIDs.isEmpty ? theme.textTertiary : theme.textPrimary)
                                Spacer()
                                Text("\(selectedAuthorIDs.count)")
                                    .foregroundColor(theme.textSecondary)
                                    .font(.subheadline)
                            }
                        }
                        .listRowBackground(theme.backgroundCard)
                    }

                    Section("Scope") {
                        Button {
                            selectedMemberID = nil
                        } label: {
                            HStack {
                                Label("System-wide", systemImage: "globe")
                                    .foregroundColor(theme.textPrimary)
                                Spacer()
                                if selectedMemberID == nil {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(theme.accentLight)
                                }
                            }
                        }
                        .listRowBackground(theme.backgroundCard)

                        NavigationLink {
                            JournalMemberPicker(
                                selectedMemberID: $selectedMemberID,
                                members: store.members
                            )
                        } label: {
                            HStack {
                                Label("Member", systemImage: "person.fill")
                                    .foregroundColor(theme.textPrimary)
                                Spacer()
                                if let memberID = selectedMemberID,
                                   let member = store.members.first(where: { $0.id == memberID }) {
                                    Text(member.displayName ?? member.name)
                                        .foregroundColor(theme.textSecondary)
                                        .font(.subheadline)
                                }
                            }
                        }
                        .listRowBackground(theme.backgroundCard)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.backgroundPrimary)
            .navigationTitle(isNew ? "New Entry" : "Edit Entry")
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
                                .foregroundColor(bodyText.isEmpty ? theme.textTertiary : theme.accentLight)
                        }
                    }
                    .disabled(bodyText.isEmpty || isSaving)
                }
            }
        }
        .task { populateFields() }
    }

    func populateFields() {
        guard let entry else {
            selectedAuthorIDs = Set(store.currentFronts.flatMap { $0.memberIDs })
            return
        }
        title = entry.title ?? ""
        bodyText = entry.body
        selectedMemberID = entry.memberID
        selectedAuthorIDs = Set(entry.authorMemberIDs)
    }

    func save() {
        isSaving = true
        Task {
            let authorIDs = selectedAuthorIDs.isEmpty ? nil : Array(selectedAuthorIDs)
            if let entry {
                let update = JournalEntryUpdate(
                    title: title.isEmpty ? nil : title,
                    body: bodyText,
                    authorMemberIDs: authorIDs
                )
                await store.updateJournal(id: entry.id, update: update)
            } else {
                let create = JournalEntryCreate(
                    memberID: selectedMemberID,
                    title: title.isEmpty ? nil : title,
                    body: bodyText,
                    authorMemberIDs: authorIDs
                )
                _ = await store.createJournal(create)
            }
            isSaving = false
            dismiss()
        }
    }
}

// MARK: - Journal Member Picker

struct JournalMemberPicker: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @Binding var selectedMemberID: String?
    let members: [Member]

    var body: some View {
        List {
            ForEach(members) { member in
                Button {
                    selectedMemberID = member.id
                    dismiss()
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
                        if selectedMemberID == member.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(theme.accentLight)
                        }
                    }
                }
                .listRowBackground(theme.backgroundCard)
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.backgroundPrimary)
        .navigationTitle("Select Member")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Journal Author Picker

struct JournalAuthorPicker: View {
    @Environment(\.theme) var theme
    @Binding var selectedAuthorIDs: Set<String>
    let members: [Member]

    var body: some View {
        List {
            ForEach(members) { member in
                Button {
                    if selectedAuthorIDs.contains(member.id) {
                        selectedAuthorIDs.remove(member.id)
                    } else {
                        selectedAuthorIDs.insert(member.id)
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
                        if selectedAuthorIDs.contains(member.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(theme.accentLight)
                                .font(.title3)
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(theme.textTertiary)
                                .font(.title3)
                        }
                    }
                }
                .buttonStyle(.plain)
                .listRowBackground(theme.backgroundCard)
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.backgroundPrimary)
        .navigationTitle("Select Authors")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Markdown Toolbar

struct MarkdownToolbar: View {
    @Environment(\.theme) var theme
    @Binding var text: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                toolbarButton("bold", icon: "bold") { wrap("**") }
                toolbarButton("italic", icon: "italic") { wrap("_") }
                toolbarButton("strikethrough", icon: "strikethrough") { wrap("~~") }
                Divider().frame(height: 20)
                toolbarButton("heading", icon: "number") { insertPrefix("## ") }
                toolbarButton("bullet list", icon: "list.bullet") { insertPrefix("- ") }
                toolbarButton("numbered list", icon: "list.number") { insertPrefix("1. ") }
                Divider().frame(height: 20)
                toolbarButton("link", icon: "link") { insertLink() }
                toolbarButton("quote", icon: "text.quote") { insertPrefix("> ") }
                toolbarButton("code", icon: "chevron.left.forwardslash.chevron.right") { wrap("`") }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
        }
    }

    private func toolbarButton(_ label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(theme.textSecondary)
                .frame(width: 32, height: 32)
                .background(theme.backgroundCard)
                .cornerRadius(8)
        }
        .accessibilityLabel(label)
    }

    private func wrap(_ marker: String) {
        text += "\(marker)text\(marker)"
    }

    private func insertPrefix(_ prefix: String) {
        if text.isEmpty || text.hasSuffix("\n") {
            text += prefix
        } else {
            text += "\n\(prefix)"
        }
    }

    private func insertLink() {
        text += "[link text](url)"
    }
}
