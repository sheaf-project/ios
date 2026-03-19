import SwiftUI
import UniformTypeIdentifiers

// MARK: - Simply Plural Import Sheet
struct SimplyPluralImportSheet: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss

    enum Step { case pick, preview, options, importing, done, failed }

    @State private var step: Step = .pick
    @State private var fileData: Data?
    @State private var fileName: String = ""
    @State private var preview: SPPreviewSummary?
    @State private var result: SPImportResult?
    @State private var errorMessage: String = ""
    @State private var isLoading = false
    @State private var showFilePicker = false

    // Import options
    @State private var importSystemProfile = true
    @State private var importCustomFronts  = true
    @State private var importCustomFields  = true
    @State private var importGroups        = true
    @State private var importFrontHistory  = false
    @State private var importNotes         = false

    // Member selection for selective import
    @State private var selectedMemberIDs: Set<String> = []
    @State private var selectAllMembers = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    switch step {
                    case .pick:      pickStep
                    case .preview:   previewStep
                    case .options:   optionsStep
                    case .importing: importingStep
                    case .done:      doneStep
                    case .failed:    failedStep
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 48)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .background(theme.backgroundPrimary)
            .navigationTitle(headerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if step != .done {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                            .foregroundColor(theme.accentLight)
                    }
                }
            }
        }
        .presentationDetents([.large])
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleFilePick(result)
        }
    }

    // MARK: - Steps

    var pickStep: some View {
        VStack(spacing: 24) {
            // SP logo area
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(theme.accentSoft)
                        .frame(width: 72, height: 72)
                    Image(systemName: "square.and.arrow.down.fill")
                        .font(.system(size: 30))
                        .foregroundColor(theme.accentLight)
                }
                Text("Import from Simply Plural")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textPrimary)
                Text("Select your Simply Plural export.json file to preview and import your data.")
                    .font(.system(size: 14))
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)

            // Instructions card
            VStack(alignment: .leading, spacing: 12) {
                instructionRow(number: "1", text: "Open Simply Plural and go to Settings")
                instructionRow(number: "2", text: "Tap \"Export Data\" and save the JSON file")
                instructionRow(number: "3", text: "Come back here and select that file")
            }
            .padding(16)
            .background(theme.backgroundCard)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.border, lineWidth: 1))

            primaryButton(label: "Choose export.json", icon: "doc.badge.plus") {
                showFilePicker = true
            }
        }
    }

    var previewStep: some View {
        VStack(spacing: 20) {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView().tint(theme.accentLight).scaleEffect(1.3)
                    Text("Reading file…")
                        .font(.system(size: 14))
                        .foregroundColor(theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            } else if let preview {
                // System name
                if let name = preview.systemName {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .foregroundColor(theme.accentLight)
                        Text(name)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(theme.textPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Summary counts
                VStack(spacing: 0) {
                    summaryRow(icon: "person.2.fill",     label: "Members",        count: preview.memberCount)
                    Divider().background(theme.divider)
                    summaryRow(icon: "person.fill.badge.plus", label: "Custom Fronts", count: preview.customFrontCount)
                    Divider().background(theme.divider)
                    summaryRow(icon: "arrow.left.arrow.right", label: "Front History", count: preview.frontHistoryCount)
                    Divider().background(theme.divider)
                    summaryRow(icon: "square.grid.2x2.fill",  label: "Groups",         count: preview.groupCount)
                    Divider().background(theme.divider)
                    summaryRow(icon: "list.bullet",            label: "Custom Fields",  count: preview.customFieldCount)
                    Divider().background(theme.divider)
                    summaryRow(icon: "note.text",              label: "Notes",          count: preview.noteCount)
                }
                .background(theme.backgroundCard)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.border, lineWidth: 1))

                // Member list preview
                if !preview.members.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Members in this export")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(theme.textTertiary)
                            .textCase(.uppercase)
                            .kerning(0.8)

                        ForEach(preview.members.prefix(5)) { member in
                            HStack {
                                Circle()
                                    .fill(theme.accentSoft)
                                    .frame(width: 8, height: 8)
                                Text(member.name)
                                    .font(.system(size: 14))
                                    .foregroundColor(theme.textPrimary)
                            }
                        }
                        if preview.members.count > 5 {
                            Text("and \(preview.members.count - 5) more…")
                                .font(.system(size: 13))
                                .foregroundColor(theme.textTertiary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                primaryButton(label: "Configure Import", icon: "slider.horizontal.3") {
                    // Pre-select all members
                    selectedMemberIDs = Set(preview.members.map { $0.id })
                    withAnimation { step = .options }
                }

                Button {
                    step = .pick
                    self.preview = nil
                    fileData = nil
                } label: {
                    Text("Choose a different file")
                        .font(.system(size: 14))
                        .foregroundColor(theme.textTertiary)
                }
            }
        }
    }

    var optionsStep: some View {
        VStack(spacing: 20) {
            // What to import
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader("What to import")
                toggleRow(label: "System Profile",  icon: "sparkles",                  value: $importSystemProfile)
                Divider().background(theme.divider).padding(.leading, 52)
                toggleRow(label: "Members",          icon: "person.2.fill",             value: .constant(true), disabled: true)
                Divider().background(theme.divider).padding(.leading, 52)
                toggleRow(label: "Custom Fronts",   icon: "person.fill.badge.plus",    value: $importCustomFronts)
                Divider().background(theme.divider).padding(.leading, 52)
                toggleRow(label: "Custom Fields",   icon: "list.bullet",               value: $importCustomFields)
                Divider().background(theme.divider).padding(.leading, 52)
                toggleRow(label: "Groups",           icon: "square.grid.2x2.fill",      value: $importGroups)
                Divider().background(theme.divider).padding(.leading, 52)
                toggleRow(label: "Front History",   icon: "clock.fill",                value: $importFrontHistory)
                Divider().background(theme.divider).padding(.leading, 52)
                toggleRow(label: "Notes",            icon: "note.text",                 value: $importNotes)
            }
            .background(theme.backgroundCard)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.border, lineWidth: 1))

            // Member selection
            if let preview, !preview.members.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        sectionHeader("Members to import")
                        Spacer()
                        Button {
                            if selectedMemberIDs.count == preview.members.count {
                                selectedMemberIDs.removeAll()
                            } else {
                                selectedMemberIDs = Set(preview.members.map { $0.id })
                            }
                        } label: {
                            Text(selectedMemberIDs.count == preview.members.count ? "Deselect All" : "Select All")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(theme.accentLight)
                        }
                        .padding(.trailing, 16)
                    }
                    ForEach(preview.members) { member in
                        Button {
                            if selectedMemberIDs.contains(member.id) {
                                selectedMemberIDs.remove(member.id)
                            } else {
                                selectedMemberIDs.insert(member.id)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: selectedMemberIDs.contains(member.id)
                                      ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedMemberIDs.contains(member.id)
                                        ? theme.accentLight : theme.textTertiary)
                                    .font(.system(size: 20))
                                Text(member.name)
                                    .font(.system(size: 15))
                                    .foregroundColor(theme.textPrimary)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        if member.id != preview.members.last?.id {
                            Divider().background(theme.divider).padding(.leading, 52)
                        }
                    }
                }
                .background(theme.backgroundCard)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.border, lineWidth: 1))
            }

            primaryButton(
                label: "Start Import",
                icon: "square.and.arrow.down.fill",
                disabled: selectedMemberIDs.isEmpty
            ) {
                Task { await runImport() }
            }

            Button { withAnimation { step = .preview } } label: {
                Text("Back")
                    .font(.system(size: 14))
                    .foregroundColor(theme.textTertiary)
            }
        }
    }

    var importingStep: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 40)
            ProgressView()
                .tint(theme.accentLight)
                .scaleEffect(1.5)
            Text("Importing your data…")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(theme.textPrimary)
            Text("This may take a moment")
                .font(.system(size: 13))
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    var doneStep: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 20)

            ZStack {
                Circle()
                    .fill(theme.success.opacity(0.15))
                    .frame(width: 88, height: 88)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(theme.success)
            }
            .shadow(color: theme.success.opacity(0.3), radius: 16)

            Text("Import Complete!")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(theme.textPrimary)

            if let result {
                VStack(spacing: 0) {
                    resultRow(icon: "person.2.fill",          label: "Members imported",       count: result.membersImported)
                    Divider().background(theme.divider)
                    resultRow(icon: "person.fill.badge.plus", label: "Custom fronts imported", count: result.customFrontsImported)
                    Divider().background(theme.divider)
                    resultRow(icon: "clock.fill",             label: "Fronts imported",        count: result.frontsImported)
                    Divider().background(theme.divider)
                    resultRow(icon: "square.grid.2x2.fill",   label: "Groups imported",        count: result.groupsImported)
                    Divider().background(theme.divider)
                    resultRow(icon: "list.bullet",            label: "Custom fields imported", count: result.customFieldsImported)
                }
                .background(theme.backgroundCard)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.border, lineWidth: 1))

                if !result.warnings.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Warnings", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(theme.warning)
                        ForEach(result.warnings, id: \.self) { warning in
                            Text("• \(warning)")
                                .font(.system(size: 12))
                                .foregroundColor(theme.textSecondary)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.warning.opacity(0.08))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.warning.opacity(0.2), lineWidth: 1))
                }
            }

            primaryButton(label: "Done", icon: "checkmark") {
                store.loadAll()
                dismiss()
            }
        }
    }

    var failedStep: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 20)

            ZStack {
                Circle()
                    .fill(theme.danger.opacity(0.12))
                    .frame(width: 88, height: 88)
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(theme.danger)
            }

            Text("Import Failed")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(theme.textPrimary)

            Text(errorMessage)
                .font(.system(size: 14))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            primaryButton(label: "Try Again", icon: "arrow.clockwise") {
                withAnimation { step = .pick }
                fileData = nil
                preview = nil
                errorMessage = ""
            }

            Button { dismiss() } label: {
                Text("Cancel")
                    .font(.system(size: 14))
                    .foregroundColor(theme.textTertiary)
            }
        }
    }

    // MARK: - Actions

    private func handleFilePick(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let e):
            errorMessage = e.localizedDescription
            step = .failed
        case .success(let urls):
            guard let url = urls.first else { return }
            // Access security-scoped resource
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                errorMessage = "Could not read the file. Make sure it's a valid JSON file."
                step = .failed
                return
            }
            fileData = data
            fileName = url.lastPathComponent
            step = .preview
            isLoading = true
            Task { await loadPreview(data: data, filename: url.lastPathComponent) }
        }
    }

    private func loadPreview(data: Data, filename: String) async {
        guard let api = store.api else { return }
        do {
            let summary = try await api.previewSimplyPluralImport(fileData: data, filename: filename)
            await MainActor.run {
                preview = summary
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
                step = .failed
            }
        }
    }

    private func runImport() async {
        guard let api = store.api, let data = fileData else { return }
        withAnimation { step = .importing }
        do {
            let ids = selectAllMembers ? nil : Array(selectedMemberIDs)
            let importResult = try await api.doSimplyPluralImport(
                fileData: data,
                filename: fileName,
                systemProfile: importSystemProfile,
                memberIDs: ids,
                customFronts: importCustomFronts,
                customFields: importCustomFields,
                groups: importGroups,
                frontHistory: importFrontHistory,
                notes: importNotes
            )
            await MainActor.run {
                result = importResult
                withAnimation { step = .done }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                withAnimation { step = .failed }
            }
        }
    }

    // MARK: - Helpers

    var headerTitle: String {
        switch step {
        case .pick:      return "Import from Simply Plural"
        case .preview:   return "Preview"
        case .options:   return "Import Options"
        case .importing: return "Importing…"
        case .done:      return "All Done"
        case .failed:    return "Error"
        }
    }

    func instructionRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(theme.accentSoft)
                    .frame(width: 24, height: 24)
                Text(number)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(theme.accentLight)
            }
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(theme.textSecondary)
            Spacer()
        }
    }

    func summaryRow(icon: String, label: String, count: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(theme.accentLight)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(theme.textPrimary)
            Spacer()
            Text("\(count)")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(count > 0 ? theme.accentLight : theme.textTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    func resultRow(icon: String, label: String, count: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(count > 0 ? theme.success : theme.textTertiary)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(theme.textPrimary)
            Spacer()
            Text("\(count)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(count > 0 ? theme.success : theme.textTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(theme.textTertiary)
            .textCase(.uppercase)
            .kerning(0.8)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    func toggleRow(label: String, icon: String, value: Binding<Bool>, disabled: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(disabled ? theme.textTertiary : theme.accentLight)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(disabled ? theme.textTertiary : theme.textPrimary)
            Spacer()
            if disabled {
                Text("Always")
                    .font(.system(size: 13))
                    .foregroundColor(theme.textTertiary)
            } else {
                Toggle("", isOn: value)
                    .labelsHidden()
                    .tint(theme.accentLight)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    func primaryButton(label: String, icon: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label).font(.system(size: 16, weight: .semibold))
                Image(systemName: icon)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(Group {
                if disabled {
                    theme.backgroundElevated
                } else {
                    LinearGradient(colors: [theme.accentLight, theme.accent],
                                   startPoint: .leading, endPoint: .trailing)
                }
            })
            .cornerRadius(14)
        }
        .disabled(disabled)
    }
}
