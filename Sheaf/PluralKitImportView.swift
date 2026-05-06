import SwiftUI
import UniformTypeIdentifiers

struct PluralKitImportSheet: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss

    enum Source { case choose, file, api }
    enum Step { case source, pick, preview, options, importing, done, failed }

    @State private var source: Source = .choose
    @State private var step: Step = .source
    @State private var fileData: Data?
    @State private var fileName: String = ""
    @State private var apiToken: String = ""
    @State private var preview: PKPreviewSummary?
    @State private var result: PKImportResult?
    @State private var errorMessage: String = ""
    @State private var isLoading = false
    @State private var showFilePicker = false

    @State private var importSystemProfile = true
    @State private var importGroups        = true
    @State private var importFrontHistory  = false

    @State private var selectedMemberIDs: Set<String> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    switch step {
                    case .source:    sourceStep
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

    // MARK: - Source Selection

    var sourceStep: some View {
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
                Text("Import from PluralKit")
                    .font(.title3).fontWeight(.bold).fontDesign(.rounded)
                    .foregroundColor(theme.textPrimary)
                Text("Choose how you'd like to import your PluralKit data.")
                    .font(.subheadline)
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)

            VStack(spacing: 12) {
                sourceOptionCard(
                    icon: "key.fill",
                    title: "Connect with Token",
                    subtitle: "Import directly from PluralKit using your system token. Nothing is stored."
                ) {
                    source = .api
                    withAnimation { step = .pick }
                }

                sourceOptionCard(
                    icon: "doc.fill",
                    title: "Upload Export File",
                    subtitle: "Import from a PluralKit data export JSON file."
                ) {
                    source = .file
                    withAnimation { step = .pick }
                }
            }
        }
    }

    // MARK: - Pick Step

    var pickStep: some View {
        VStack(spacing: 24) {
            if source == .api {
                apiTokenEntry
            } else {
                filePickEntry
            }
        }
    }

    var apiTokenEntry: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(theme.accentSoft)
                        .frame(width: 72, height: 72)
                    Image(systemName: "key.fill")
                        .font(.title)
                        .foregroundColor(theme.accentLight)
                }
                Text("Enter Your PluralKit Token")
                    .font(.title3).fontWeight(.bold).fontDesign(.rounded)
                    .foregroundColor(theme.textPrimary)
                Text("Your token is used once to fetch your data and is never stored.")
                    .font(.subheadline)
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 12) {
                instructionRow(number: "1", text: "Open Discord and DM PluralKit")
                instructionRow(number: "2", text: "Send the command: pk;token")
                instructionRow(number: "3", text: "Copy the token and paste it below")
            }
            .padding(16)
            .background(theme.backgroundCard)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.border, lineWidth: 1))

            SecureField("Paste your PluralKit token", text: $apiToken)
                .textContentType(.password)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(14)
                .background(theme.backgroundCard)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.border, lineWidth: 1))

            primaryButton(
                label: "Connect & Preview",
                icon: "arrow.right.circle.fill",
                disabled: apiToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ) {
                step = .preview
                isLoading = true
                Task { await loadAPIPreview() }
            }

            Button {
                apiToken = ""
                withAnimation { step = .source }
            } label: {
                Text("Back")
                    .font(.subheadline)
                    .foregroundColor(theme.textTertiary)
            }
        }
    }

    var filePickEntry: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(theme.accentSoft)
                        .frame(width: 72, height: 72)
                    Image(systemName: "doc.fill")
                        .font(.title)
                        .foregroundColor(theme.accentLight)
                }
                Text("Upload PluralKit Export")
                    .font(.title3).fontWeight(.bold).fontDesign(.rounded)
                    .foregroundColor(theme.textPrimary)
                Text("Select your PluralKit data export JSON file.")
                    .font(.subheadline)
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 12) {
                instructionRow(number: "1", text: "Open Discord and DM PluralKit")
                instructionRow(number: "2", text: "Send the command: pk;export")
                instructionRow(number: "3", text: "Save the attached JSON file to your device")
                instructionRow(number: "4", text: "Come back here and select that file")
            }
            .padding(16)
            .background(theme.backgroundCard)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.border, lineWidth: 1))

            primaryButton(label: "Choose Export File", icon: "doc.badge.plus") {
                showFilePicker = true
            }

            Button { withAnimation { step = .source } } label: {
                Text("Back")
                    .font(.subheadline)
                    .foregroundColor(theme.textTertiary)
            }
        }
    }

    // MARK: - Preview

    var previewStep: some View {
        VStack(spacing: 20) {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView().tint(theme.accentLight).scaleEffect(1.3)
                    Text(source == .api ? "Fetching from PluralKit…" : "Reading file…")
                        .font(.subheadline)
                        .foregroundColor(theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            } else if let preview {
                if let name = preview.systemName {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .foregroundColor(theme.accentLight)
                        Text(name)
                            .font(.headline)
                            .foregroundColor(theme.textPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(spacing: 0) {
                    summaryRow(icon: "person.2.fill", label: "Members", count: preview.memberCount)
                    Divider().background(theme.divider)
                    summaryRow(icon: "square.grid.2x2.fill", label: "Groups", count: preview.groupCount)
                    Divider().background(theme.divider)
                    summaryRow(icon: "arrow.left.arrow.right", label: "Switches", count: preview.switchCount)
                }
                .background(theme.backgroundCard)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.border, lineWidth: 1))

                if let earliest = preview.earliestSwitch, let latest = preview.latestSwitch {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundColor(theme.textTertiary)
                        Text("Switches from \(earliest.formatted(date: .abbreviated, time: .omitted)) to \(latest.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundColor(theme.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

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
                    if source == .api {
                        withAnimation { step = .pick }
                    } else {
                        fileData = nil
                        withAnimation { step = .pick }
                    }
                } label: {
                    Text(source == .api ? "Use a different token" : "Choose a different file")
                        .font(.subheadline)
                        .foregroundColor(theme.textTertiary)
                }
            }
        }
    }

    // MARK: - Options

    var optionsStep: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader("What to import")
                toggleRow(label: "System Profile", icon: "sparkles", value: $importSystemProfile)
                Divider().background(theme.divider).padding(.leading, 52)
                toggleRow(label: "Members", icon: "person.2.fill", value: .constant(true), disabled: true)
                Divider().background(theme.divider).padding(.leading, 52)
                toggleRow(label: "Groups", icon: "square.grid.2x2.fill", value: $importGroups)
                Divider().background(theme.divider).padding(.leading, 52)
                toggleRow(label: "Front History", icon: "clock.fill", value: $importFrontHistory)
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

    // MARK: - Importing / Done / Failed

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
                    Divider().background(theme.divider)
                    resultRow(icon: "clock.fill", label: "Fronts imported", count: result.frontsImported)
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
                withAnimation { step = .source }
                fileData = nil
                preview = nil
                result = nil
                apiToken = ""
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
            Task { await loadFilePreview(data: data, filename: url.lastPathComponent) }
        }
    }

    private func loadFilePreview(data: Data, filename: String) async {
        guard let api = store.api else { return }
        do {
            let summary = try await api.previewPluralKitFileImport(fileData: data, filename: filename)
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

    private func loadAPIPreview() async {
        guard let api = store.api else { return }
        do {
            let summary = try await api.previewPluralKitAPIImport(token: apiToken.trimmingCharacters(in: .whitespacesAndNewlines))
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
        guard let api = store.api else { return }
        withAnimation { step = .importing }

        let allSelected = preview.map { selectedMemberIDs.count == $0.members.count } ?? true
        let ids: [String]? = allSelected ? nil : Array(selectedMemberIDs)

        do {
            let importResult: PKImportResult
            if source == .api {
                importResult = try await api.doPluralKitAPIImport(
                    token: apiToken.trimmingCharacters(in: .whitespacesAndNewlines),
                    systemProfile: importSystemProfile,
                    memberIDs: ids,
                    groups: importGroups,
                    frontHistory: importFrontHistory
                )
            } else {
                guard let data = fileData else { return }
                importResult = try await api.doPluralKitFileImport(
                    fileData: data,
                    filename: fileName,
                    systemProfile: importSystemProfile,
                    memberIDs: ids,
                    groups: importGroups,
                    frontHistory: importFrontHistory
                )
            }
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
        case .source:    return "Import from PluralKit"
        case .pick:      return source == .api ? "PluralKit Token" : "PluralKit Export"
        case .preview:   return "Preview"
        case .options:   return "Import Options"
        case .importing: return "Importing…"
        case .done:      return "All Done"
        case .failed:    return "Error"
        }
    }

    func sourceOptionCard(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(theme.accentSoft)
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.body)
                        .foregroundColor(theme.accentLight)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundColor(theme.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(theme.textTertiary)
            }
            .padding(14)
            .background(theme.backgroundCard)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
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
