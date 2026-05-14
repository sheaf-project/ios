import SwiftUI
import UniformTypeIdentifiers

struct TupperboxImportSheet: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss

    enum Step { case pick, preview, options, importing, done, failed }

    @State private var step: Step = .pick
    @State private var fileData: Data?
    @State private var fileName: String = ""
    @State private var preview: TBPreviewSummary?
    @State private var result: TBImportResult?
    @State private var errorMessage: String = ""
    @State private var isLoading = false
    @State private var showFilePicker = false

    @State private var importGroups = true
    @State private var selectedMemberIDs: Set<String> = []

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
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(theme.accentSoft)
                        .frame(width: 72, height: 72)
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.title)
                        .foregroundColor(theme.accentLight)
                }
                Text("Import from Tupperbox")
                    .font(.title3).fontWeight(.bold).fontDesign(.rounded)
                    .foregroundColor(theme.textPrimary)
                Text("Upload a Tupperbox export to bring across your tuppers and groups.")
                    .font(.subheadline)
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 12) {
                instructionRow(number: "1", text: "Open Discord and DM Tupperbox")
                instructionRow(number: "2", text: "Send the command: tul!export")
                instructionRow(number: "3", text: "Save the JSON file Tupperbox sends you")
                instructionRow(number: "4", text: "Come back here and select that file")
            }
            .padding(16)
            .background(theme.backgroundCard)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.border, lineWidth: 1))

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                        .foregroundColor(theme.textTertiary)
                    Text("What's not imported")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundColor(theme.textTertiary)
                }
                Text("Tupperbox doesn't track fronting or system metadata. Proxy brackets, banners, and per-tupper tags are dropped since Sheaf doesn't proxy Discord messages.")
                    .font(.caption)
                    .foregroundColor(theme.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            primaryButton(label: "Choose Export File", icon: "doc.badge.plus") {
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
                        .font(.subheadline)
                        .foregroundColor(theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            } else if let preview {
                VStack(spacing: 0) {
                    summaryRow(icon: "person.2.fill", label: "Members", count: preview.memberCount)
                    Divider().background(theme.divider)
                    summaryRow(icon: "square.grid.2x2.fill", label: "Groups", count: preview.groupCount)
                }
                .background(theme.backgroundCard)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.border, lineWidth: 1))

                if !preview.members.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Members in this export")
                            .font(.footnote).fontWeight(.semibold)
                            .foregroundColor(theme.textTertiary)
                            .textCase(.uppercase)
                            .kerning(0.8)

                        ForEach(preview.members.prefix(5)) { member in
                            HStack {
                                Circle()
                                    .fill(theme.accentSoft)
                                    .frame(width: 8, height: 8)
                                Text(member.name)
                                    .font(.subheadline)
                                    .foregroundColor(theme.textPrimary)
                            }
                        }
                        if preview.members.count > 5 {
                            Text("and \(preview.members.count - 5) more…")
                                .font(.footnote)
                                .foregroundColor(theme.textTertiary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                primaryButton(label: "Configure Import", icon: "slider.horizontal.3") {
                    selectedMemberIDs = Set(preview.members.map { $0.id })
                    withAnimation { step = .options }
                }

                Button {
                    self.preview = nil
                    fileData = nil
                    withAnimation { step = .pick }
                } label: {
                    Text("Choose a different file")
                        .font(.subheadline)
                        .foregroundColor(theme.textTertiary)
                }
            }
        }
    }

    var optionsStep: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader("What to import")
                toggleRow(label: "Members", icon: "person.2.fill", value: .constant(true), disabled: true)
                Divider().background(theme.divider).padding(.leading, 52)
                toggleRow(label: "Groups", icon: "square.grid.2x2.fill", value: $importGroups)
            }
            .background(theme.backgroundCard)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.border, lineWidth: 1))

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
                                .font(.caption).fontWeight(.semibold)
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
                                    .font(.title3)
                                Text(member.name)
                                    .font(.subheadline)
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
                    .font(.subheadline)
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
                .font(.body).fontWeight(.medium)
                .foregroundColor(theme.textPrimary)
            Text("This may take a moment")
                .font(.footnote)
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
                    .font(.largeTitle)
                    .foregroundColor(theme.success)
            }
            .shadow(color: theme.success.opacity(0.3), radius: 16)

            Text("Import Complete!")
                .font(.title3).fontWeight(.bold).fontDesign(.rounded)
                .foregroundColor(theme.textPrimary)

            if let result {
                VStack(spacing: 0) {
                    resultRow(icon: "person.2.fill", label: "Members imported", count: result.membersImported)
                    Divider().background(theme.divider)
                    resultRow(icon: "square.grid.2x2.fill", label: "Groups imported", count: result.groupsImported)
                }
                .background(theme.backgroundCard)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.border, lineWidth: 1))

                if !result.warnings.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Warnings", systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote).fontWeight(.semibold)
                            .foregroundColor(theme.warning)
                        ForEach(result.warnings, id: \.self) { warning in
                            Text("• \(warning)")
                                .font(.caption)
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
                    .font(.largeTitle)
                    .foregroundColor(theme.danger)
            }

            Text("Import Failed")
                .font(.title3).fontWeight(.bold).fontDesign(.rounded)
                .foregroundColor(theme.textPrimary)

            Text(errorMessage)
                .font(.subheadline)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            primaryButton(label: "Try Again", icon: "arrow.clockwise") {
                withAnimation { step = .pick }
                fileData = nil
                preview = nil
                result = nil
                errorMessage = ""
            }

            Button { dismiss() } label: {
                Text("Cancel")
                    .font(.subheadline)
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
            let summary = try await api.previewTupperboxImport(fileData: data, filename: filename)
            await MainActor.run {
                preview = summary
                isLoading = false
            }
        } catch is CancellationError {
            await MainActor.run { isLoading = false }
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

        let allSelected = preview.map { selectedMemberIDs.count == $0.members.count } ?? true
        let ids: [String]? = allSelected ? nil : Array(selectedMemberIDs)

        do {
            let importResult = try await api.doTupperboxImport(
                fileData: data,
                filename: fileName,
                memberIDs: ids,
                groups: importGroups
            )
            await MainActor.run {
                result = importResult
                withAnimation { step = .done }
            }
        } catch is CancellationError {
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
        case .pick:      return "Import from Tupperbox"
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
                    .font(.caption).fontWeight(.bold)
                    .foregroundColor(theme.accentLight)
            }
            Text(text)
                .font(.subheadline)
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
                .font(.subheadline)
                .foregroundColor(theme.textPrimary)
            Spacer()
            Text("\(count)")
                .font(.subheadline).fontWeight(.semibold)
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
                .font(.subheadline)
                .foregroundColor(theme.textPrimary)
            Spacer()
            Text("\(count)")
                .font(.subheadline).fontWeight(.semibold)
                .foregroundColor(count > 0 ? theme.success : theme.textTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption).fontWeight(.semibold)
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
                .font(.subheadline)
                .foregroundColor(disabled ? theme.textTertiary : theme.textPrimary)
            Spacer()
            if disabled {
                Text("Always")
                    .font(.footnote)
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
                Text(label)
                Image(systemName: icon)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(theme.accentLight)
        .disabled(disabled)
    }
}
