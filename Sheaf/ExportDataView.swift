import SwiftUI

// MARK: - Export Data Screen
//
// Two-channel export:
//
//   • Sync JSON export — GET /v1/export?format=… streamed straight to a temp
//     file then presented via the share sheet. Fast, metadata only.
//   • Async full backup with images — POST /v1/export/jobs after step-up auth
//     (password, plus TOTP when the account has 2FA). Polls the job list
//     until "done"; the user can then download the finished zip.

enum ExportFormat: String, CaseIterable, Identifiable {
    case sheaf
    case openplural

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sheaf:      return "Sheaf"
        case .openplural: return "OpenPlural"
        }
    }

    var description: String {
        switch self {
        case .sheaf:
            return "Full-fidelity backup, re-importable into another Sheaf instance."
        case .openplural:
            return "OpenPlural v0.1, for interchange with other compatible apps. JSON here is uri-only; the full backup zip carries image bytes."
        }
    }

    var syncParam: String { rawValue }

    var jobParam: String {
        switch self {
        case .sheaf:      return "sheaf_native"
        case .openplural: return "openplural"
        }
    }

    var fileExtensionJSON: String {
        switch self {
        case .sheaf:      return "json"
        case .openplural: return "openplural.json"
        }
    }

    var fileExtensionZip: String {
        switch self {
        case .sheaf:      return "zip"
        case .openplural: return "openplural.zip"
        }
    }
}

struct ExportDataView: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme

    @State private var format: ExportFormat = .sheaf
    @State private var jobs: [ExportJobRead] = []
    @State private var isLoadingJobs = false
    @State private var totpEnabled = false
    @State private var isExportingJSON = false
    @State private var isSubmittingJob = false
    @State private var downloadingJobID: String?
    @State private var showStepUp = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?
    @State private var pollTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let errorMessage {
                    banner(text: errorMessage, color: theme.danger, icon: "exclamationmark.triangle.fill")
                }
                if let infoMessage {
                    banner(text: infoMessage, color: theme.accentLight, icon: "info.circle.fill")
                }

                section(title: "Format") {
                    VStack(spacing: 0) {
                        ForEach(ExportFormat.allCases) { fmt in
                            formatRow(fmt: fmt)
                            if fmt != ExportFormat.allCases.last {
                                Divider().background(theme.divider).padding(.leading, 52)
                            }
                        }
                    }
                    .background(theme.backgroundCard)
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.border, lineWidth: 1))
                }

                section(title: "Download") {
                    VStack(spacing: 12) {
                        Button {
                            Task { await exportJSON() }
                        } label: {
                            HStack {
                                if isExportingJSON {
                                    ProgressView().tint(.white).scaleEffect(0.8)
                                }
                                Text("Export JSON only")
                                Image(systemName: "square.and.arrow.up.fill")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(theme.accentLight)
                        .disabled(isExportingJSON)

                        Text("A metadata-only JSON file. Fast, but does not include image files.")
                            .font(.footnote)
                            .foregroundColor(theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button {
                            showStepUp = true
                        } label: {
                            HStack {
                                Text("Build full backup (with images)")
                                Image(systemName: "shippingbox.fill")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .tint(theme.accentLight)
                        .disabled(isSubmittingJob)

                        Text("Builds a zip with your images in the background, then appears below to download. Requires your password.")
                            .font(.footnote)
                            .foregroundColor(theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if !jobs.isEmpty || isLoadingJobs {
                    section(title: "Recent Backups") {
                        VStack(spacing: 0) {
                            if jobs.isEmpty && isLoadingJobs {
                                HStack {
                                    Spacer()
                                    ProgressView().tint(theme.accentLight)
                                    Spacer()
                                }
                                .padding(.vertical, 20)
                            }
                            ForEach(Array(jobs.enumerated()), id: \.element.id) { idx, job in
                                backupRow(job: job)
                                if idx != jobs.count - 1 {
                                    Divider().background(theme.divider).padding(.leading, 16)
                                }
                            }
                        }
                        .background(theme.backgroundCard)
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.border, lineWidth: 1))
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(theme.backgroundPrimary)
        .navigationTitle("Export Data")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadTOTPStatus()
            await refreshJobs(pollIfActive: true)
        }
        .onDisappear { pollTask?.cancel() }
        .sheet(isPresented: $showStepUp) {
            ExportStepUpDialog(
                totpEnabled: totpEnabled,
                isSubmitting: isSubmittingJob,
                onConfirm: { password, totp in
                    Task { await requestFullBackup(password: password, totpCode: totp) }
                }
            )
            .environmentObject(store)
        }
    }

    // MARK: - Subviews

    private func formatRow(fmt: ExportFormat) -> some View {
        Button {
            format = fmt
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: format == fmt ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(format == fmt ? theme.accentLight : theme.textTertiary)
                    .font(.title3)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 4) {
                    Text(fmt.label)
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundColor(theme.textPrimary)
                    Text(fmt.description)
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func backupRow(job: ExportJobRead) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(statusLabel(job))
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundColor(statusColor(job))
                let subtitle = backupSubtitle(job)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                }
                if job.status == "failed", let err = job.error {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(theme.danger)
                        .lineLimit(3)
                }
            }
            Spacer()
            if job.status == "pending" || job.status == "running" {
                ProgressView().tint(theme.accentLight).scaleEffect(0.8)
            } else if job.isDownloadable {
                if downloadingJobID == job.id {
                    ProgressView().tint(theme.accentLight).scaleEffect(0.8)
                } else {
                    Button {
                        Task { await downloadJob(job) }
                    } label: {
                        Image(systemName: "icloud.and.arrow.down.fill")
                            .font(.title3)
                            .foregroundColor(theme.accentLight)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func banner(text: String, color: Color, icon: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(text)
                .font(.footnote)
                .foregroundColor(theme.textPrimary)
            Spacer()
        }
        .padding(12)
        .background(color.opacity(0.08))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.2), lineWidth: 1))
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption).fontWeight(.semibold)
                .foregroundColor(theme.textTertiary)
                .textCase(.uppercase)
                .kerning(0.8)
                .padding(.leading, 4)
            content()
        }
    }

    // MARK: - Actions

    private func loadTOTPStatus() async {
        guard let api = store.api else { return }
        if let me = try? await api.getMe() {
            await MainActor.run { totpEnabled = me.totpEnabled }
        }
    }

    private func exportJSON() async {
        guard let api = store.api else { return }
        await MainActor.run {
            isExportingJSON = true
            errorMessage = nil
            infoMessage = nil
        }
        do {
            let data = try await api.exportData(format: format.syncParam)
            let ts = ISO8601DateFormatter().string(from: Date())
                .replacingOccurrences(of: ":", with: "-")
            let filename = "sheaf-export-\(ts).\(format.fileExtensionJSON)"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: tempURL)
            await MainActor.run {
                isExportingJSON = false
                presentShareSheet(url: tempURL)
            }
        } catch is CancellationError {
            await MainActor.run { isExportingJSON = false }
        } catch {
            await MainActor.run {
                isExportingJSON = false
                errorMessage = error.userFacingMessage ?? "Export failed."
            }
        }
    }

    private func requestFullBackup(password: String, totpCode: String?) async {
        guard let api = store.api else { return }
        await MainActor.run { isSubmittingJob = true }
        do {
            _ = try await api.createExportJob(
                includeImages: true,
                format: format.jobParam,
                password: password,
                totpCode: totpCode
            )
            await MainActor.run {
                isSubmittingJob = false
                showStepUp = false
                infoMessage = "Backup queued. We'll build it in the background; check back here."
            }
            await refreshJobs(pollIfActive: true)
        } catch is CancellationError {
            await MainActor.run { isSubmittingJob = false }
        } catch {
            // Keep the dialog open on an auth failure so the user can retry.
            await MainActor.run {
                isSubmittingJob = false
                errorMessage = error.userFacingMessage ?? "Couldn't start the backup."
            }
        }
    }

    private func refreshJobs(pollIfActive: Bool) async {
        guard let api = store.api else { return }
        await MainActor.run { isLoadingJobs = jobs.isEmpty }
        do {
            let fetched = try await api.listExportJobs()
            await MainActor.run {
                jobs = fetched
                isLoadingJobs = false
            }
            if pollIfActive, fetched.contains(where: { $0.status == "pending" || $0.status == "running" }) {
                startPolling()
            }
        } catch {
            await MainActor.run { isLoadingJobs = false }
        }
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5s, matches Android
                if Task.isCancelled { break }
                guard let api = store.api else { break }
                guard let fetched = try? await api.listExportJobs() else { break }
                await MainActor.run { jobs = fetched }
                if !fetched.contains(where: { $0.status == "pending" || $0.status == "running" }) {
                    break
                }
            }
        }
    }

    private func downloadJob(_ job: ExportJobRead) async {
        guard let api = store.api else { return }
        await MainActor.run {
            downloadingJobID = job.id
            errorMessage = nil
            infoMessage = nil
        }
        do {
            let data = try await api.downloadExportJob(id: job.id)
            let filename = "sheaf-export-\(job.id).\(fileExtensionFor(job))"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: tempURL)
            await MainActor.run {
                downloadingJobID = nil
                presentShareSheet(url: tempURL)
            }
        } catch is CancellationError {
            await MainActor.run { downloadingJobID = nil }
        } catch {
            await MainActor.run {
                downloadingJobID = nil
                errorMessage = error.userFacingMessage ?? "Download failed."
            }
        }
    }

    private func fileExtensionFor(_ job: ExportJobRead) -> String {
        job.format == "openplural" ? "openplural.zip" : "zip"
    }

    // MARK: - Display helpers

    private func statusLabel(_ job: ExportJobRead) -> String {
        switch job.status {
        case "pending": return "Queued"
        case "running": return "Building…"
        case "done":    return "Ready to download"
        case "failed":  return "Failed"
        case "expired": return "Expired"
        default:        return job.status.capitalized
        }
    }

    private func statusColor(_ job: ExportJobRead) -> Color {
        switch job.status {
        case "failed", "expired": return theme.danger
        case "done":              return theme.success
        default:                  return theme.textPrimary
        }
    }

    private func backupSubtitle(_ job: ExportJobRead) -> String {
        var parts: [String] = []
        parts.append(job.format == "openplural" ? "OpenPlural" : "Sheaf")
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm"
        parts.append(formatter.string(from: job.requestedAt))
        if let size = job.fileSizeBytes {
            parts.append(formatSize(size))
        }
        return parts.joined(separator: " · ")
    }

    private func formatSize(_ bytes: Int64) -> String {
        if bytes >= 1_000_000 {
            return String(format: "%.1f MB", Double(bytes) / 1_000_000.0)
        } else if bytes >= 1_000 {
            return String(format: "%.0f KB", Double(bytes) / 1_000.0)
        } else {
            return "\(bytes) B"
        }
    }

    private func presentShareSheet(url: URL) {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        guard let windowScene = scene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first,
              let rootViewController = window.rootViewController else { return }

        var presenter = rootViewController
        while let presented = presenter.presentedViewController {
            presenter = presented
        }

        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(x: presenter.view.bounds.midX,
                                        y: presenter.view.bounds.midY,
                                        width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        presenter.present(activityVC, animated: true)
    }
}

// MARK: - Step-Up Dialog
//
// Step-up auth required by the backend for the async export job. The
// dialog stays open on submission failure so the user can correct the
// password / TOTP without re-entering everything else.

private struct ExportStepUpDialog: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss

    let totpEnabled: Bool
    let isSubmitting: Bool
    let onConfirm: (_ password: String, _ totp: String?) -> Void

    @State private var password: String = ""
    @State private var totp: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Building a full backup exports everything you have, including images. Enter your password to continue.")
                        .font(.subheadline)
                        .foregroundColor(theme.textSecondary)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Password")
                            .font(.caption).fontWeight(.semibold)
                            .foregroundColor(theme.textTertiary)
                        SecureField("Your account password", text: $password)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding(14)
                            .background(theme.backgroundCard)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.border, lineWidth: 1))
                    }

                    if totpEnabled {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Authenticator code")
                                .font(.caption).fontWeight(.semibold)
                                .foregroundColor(theme.textTertiary)
                            TextField("6-digit code", text: $totp)
                                .keyboardType(.numberPad)
                                .textContentType(.oneTimeCode)
                                .padding(14)
                                .background(theme.backgroundCard)
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.border, lineWidth: 1))
                        }
                    }

                    Button {
                        onConfirm(password, totpEnabled ? totp : nil)
                    } label: {
                        HStack {
                            if isSubmitting {
                                ProgressView().tint(.white).scaleEffect(0.8)
                            }
                            Text("Build backup")
                            Image(systemName: "shippingbox.fill")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(theme.accentLight)
                    .disabled(isSubmitting || password.isEmpty || (totpEnabled && totp.isEmpty))
                    .padding(.top, 8)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .background(theme.backgroundPrimary)
            .navigationTitle("Confirm It's You")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(theme.accentLight)
                        .disabled(isSubmitting)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
