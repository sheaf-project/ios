import SwiftUI

// MARK: - Display helpers

private func importSourceLabel(_ source: String) -> String {
    switch source {
    case "simplyplural_file": return "Simply Plural"
    case "sheaf_file":        return "Sheaf"
    case "pluralkit_file":    return "PluralKit"
    case "pluralkit_api":     return "PluralKit (API)"
    case "tupperbox_file":    return "Tupperbox"
    case "pluralspace_file":  return "PluralSpace"
    case "prism_file":        return "Prism"
    default:
        return source.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

private func importSourceIcon(_ source: String) -> String {
    switch source {
    case "pluralkit_api": return "key.fill"
    case "prism_file":    return "lock.doc.fill"
    default:              return "square.and.arrow.down.fill"
    }
}

private func statusText(_ status: ImportJobStatus) -> String {
    switch status {
    case .pending:   return "Pending"
    case .running:   return "Running"
    case .complete:  return "Complete"
    case .failed:    return "Failed"
    case .cancelled: return "Cancelled"
    }
}

private func statusColor(_ status: ImportJobStatus, _ theme: Theme) -> Color {
    switch status {
    case .pending:   return theme.textTertiary
    case .running:   return theme.accentLight
    case .complete:  return theme.success
    case .failed:    return theme.danger
    case .cancelled: return theme.textTertiary
    }
}

/// A short headline summary of the most relevant counts for a list row.
private func primaryCountSummary(_ counts: [String: Int]) -> String {
    func phrase(_ n: Int, _ singular: String, _ plural: String) -> String {
        "\(n) \(n == 1 ? singular : plural)"
    }
    var parts: [String] = []
    if let m = counts["members_imported"], m > 0 { parts.append(phrase(m, "member", "members")) }
    if let f = counts["fronts_imported"],  f > 0 { parts.append(phrase(f, "front", "fronts")) }
    if let g = counts["groups_imported"],  g > 0 { parts.append(phrase(g, "group", "groups")) }
    return parts.isEmpty ? "No items imported" : parts.joined(separator: ", ")
}

private func formatCountKey(_ key: String) -> String {
    key.replacingOccurrences(of: "_", with: " ").capitalized
}

// MARK: - Import History List

struct ImportHistoryView: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss

    @State private var jobs: [ImportJobSummary] = []
    @State private var nextCursor: String?
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var errorMessage: String?

    // 409 (job running) feedback
    @State private var showRunningAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundPrimary.ignoresSafeArea()

                if isLoading {
                    ProgressView().tint(theme.accentLight)
                } else if let errorMessage, jobs.isEmpty {
                    emptyState(
                        icon: "exclamationmark.triangle",
                        title: "Couldn't Load History",
                        subtitle: errorMessage
                    )
                } else if jobs.isEmpty {
                    emptyState(
                        icon: "clock.arrow.circlepath",
                        title: "No Imports Yet",
                        subtitle: "Imports you run will show up here so you can check their progress and results."
                    )
                } else {
                    list
                }
            }
            .navigationTitle("Import History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(theme.accentLight)
                }
            }
            .alert("Import In Progress", isPresented: $showRunningAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("This import is still running. Wait for it to finish before cancelling or archiving it.")
            }
        }
        .task { await load() }
    }

    private var list: some View {
        List {
            ForEach(jobs) { job in
                NavigationLink {
                    ImportJobDetailView(jobID: job.id) { await load() }
                        .environmentObject(store)
                } label: {
                    jobRow(job)
                }
                .listRowBackground(theme.backgroundPrimary)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 5, leading: 24, bottom: 5, trailing: 24))
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    swipeAction(for: job)
                }
            }

            if nextCursor != nil {
                HStack {
                    Spacer()
                    if isLoadingMore {
                        ProgressView().tint(theme.accentLight)
                    } else {
                        Button("Load More") { Task { await loadMore() } }
                            .font(.subheadline)
                            .foregroundColor(theme.accentLight)
                    }
                    Spacer()
                }
                .listRowBackground(theme.backgroundPrimary)
                .listRowSeparator(.hidden)
                .onAppear { Task { await loadMore() } }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable { await load() }
    }

    @ViewBuilder
    private func swipeAction(for job: ImportJobSummary) -> some View {
        if job.status == .pending {
            Button(role: .destructive) {
                Task { await delete(job) }
            } label: {
                Label("Cancel", systemImage: "xmark.circle")
            }
        } else if job.status.isTerminal && job.archivedAt == nil {
            Button {
                Task { await delete(job) }
            } label: {
                Label("Archive", systemImage: "archivebox")
            }
            .tint(theme.textTertiary)
        }
    }

    private func jobRow(_ job: ImportJobSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: importSourceIcon(job.source))
                    .font(.callout)
                    .foregroundColor(theme.accentLight)
                    .frame(width: 24)

                Text(importSourceLabel(job.source))
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)

                Spacer()

                statusBadge(job.status)
            }

            Text(primaryCountSummary(job.counts))
                .font(.caption)
                .foregroundColor(theme.textSecondary)
                .lineLimit(1)

            Text(job.createdAt.formatted(.relative(presentation: .named)))
                .font(.caption2)
                .foregroundColor(theme.textTertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.backgroundCard)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.border, lineWidth: 1))
    }

    private func statusBadge(_ status: ImportJobStatus) -> some View {
        HStack(spacing: 4) {
            if status == .running || status == .pending {
                ProgressView()
                    .controlSize(.mini)
                    .tint(statusColor(status, theme))
            }
            Text(statusText(status))
                .font(.caption2).fontWeight(.bold)
                .foregroundColor(statusColor(status, theme))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(statusColor(status, theme).opacity(0.15))
        .cornerRadius(6)
    }

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundColor(theme.textTertiary)
            Text(title)
                .font(.body).fontWeight(.semibold).fontDesign(.rounded)
                .foregroundColor(theme.textSecondary)
            Text(subtitle)
                .font(.footnote)
                .foregroundColor(theme.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: Actions

    private func load() async {
        guard let api = store.api else { return }
        do {
            let page = try await api.listImportJobs()
            await MainActor.run {
                jobs = page.items
                nextCursor = page.nextCursor
                errorMessage = nil
                isLoading = false
            }
        } catch is CancellationError {
            await MainActor.run { isLoading = false }
        } catch {
            await MainActor.run {
                errorMessage = error.userFacingMessage ?? ""
                isLoading = false
            }
        }
    }

    private func loadMore() async {
        guard let api = store.api, let cursor = nextCursor, !isLoadingMore else { return }
        await MainActor.run { isLoadingMore = true }
        do {
            let page = try await api.listImportJobs(cursor: cursor)
            await MainActor.run {
                jobs.append(contentsOf: page.items)
                nextCursor = page.nextCursor
                isLoadingMore = false
            }
        } catch is CancellationError {
            await MainActor.run { isLoadingMore = false }
        } catch {
            await MainActor.run { isLoadingMore = false }
        }
    }

    private func delete(_ job: ImportJobSummary) async {
        guard let api = store.api else { return }
        do {
            try await api.deleteImportJob(id: job.id)
            await load()
        } catch {
            await MainActor.run {
                if (error as NSError).code == 409 {
                    showRunningAlert = true
                } else {
                    errorMessage = error.userFacingMessage ?? ""
                }
            }
        }
    }
}

// MARK: - Import Job Detail

struct ImportJobDetailView: View {
    let jobID: String
    /// Called after a successful cancel/archive so the parent list can refresh.
    var onChange: (() async -> Void)?

    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss

    @State private var job: ImportJobRead?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showRunningAlert = false

    var body: some View {
        ZStack {
            theme.backgroundPrimary.ignoresSafeArea()

            if isLoading {
                ProgressView().tint(theme.accentLight)
            } else if let job {
                ScrollView {
                    VStack(spacing: 20) {
                        header(job)
                        if !job.counts.isEmpty { countsCard(job) }
                        if let lastError = job.lastError, !lastError.isEmpty { errorCard(lastError) }
                        eventsCard(job, level: "error", title: "Errors", color: theme.danger)
                        eventsCard(job, level: "warning", title: "Warnings", color: theme.warning)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                }
            } else if let errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(theme.textTertiary)
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(theme.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
        }
        .navigationTitle("Import Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let job, canModify(job) {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        if job.status == .pending {
                            Button(role: .destructive) {
                                Task { await delete(job) }
                            } label: {
                                Label("Cancel Import", systemImage: "xmark.circle")
                            }
                        } else if job.status.isTerminal && job.archivedAt == nil {
                            Button {
                                Task { await delete(job) }
                            } label: {
                                Label("Archive", systemImage: "archivebox")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundColor(theme.accentLight)
                    }
                }
            }
        }
        .alert("Import In Progress", isPresented: $showRunningAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This import is still running. Wait for it to finish before cancelling or archiving it.")
        }
        // Loads on appear and keeps polling while the job is still running.
        .task { await pollIfNeeded() }
    }

    private func canModify(_ job: ImportJobRead) -> Bool {
        job.status == .pending || (job.status.isTerminal && job.archivedAt == nil)
    }

    private func header(_ job: ImportJobRead) -> some View {
        VStack(spacing: 10) {
            Image(systemName: importSourceIcon(job.source))
                .font(.title)
                .foregroundColor(theme.accentLight)
            Text(importSourceLabel(job.source))
                .font(.title3).fontWeight(.bold).fontDesign(.rounded)
                .foregroundColor(theme.textPrimary)
            HStack(spacing: 6) {
                if job.status == .running || job.status == .pending {
                    ProgressView().controlSize(.mini).tint(statusColor(job.status, theme))
                }
                Text(statusText(job.status))
                    .font(.caption).fontWeight(.bold)
                    .foregroundColor(statusColor(job.status, theme))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(statusColor(job.status, theme).opacity(0.15))
            .cornerRadius(8)

            Text("Started \(job.createdAt.formatted(.relative(presentation: .named)))")
                .font(.caption2)
                .foregroundColor(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private func countsCard(_ job: ImportJobRead) -> some View {
        let keys = job.counts.keys.sorted()
        return VStack(spacing: 0) {
            ForEach(Array(keys.enumerated()), id: \.element) { index, key in
                HStack {
                    Text(formatCountKey(key))
                        .font(.subheadline)
                        .foregroundColor(theme.textPrimary)
                    Spacer()
                    Text("\(job.counts[key] ?? 0)")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundColor((job.counts[key] ?? 0) > 0 ? theme.accentLight : theme.textTertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                if index < keys.count - 1 {
                    Divider().background(theme.divider)
                }
            }
        }
        .background(theme.backgroundCard)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.border, lineWidth: 1))
    }

    private func errorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Error", systemImage: "xmark.octagon.fill")
                .font(.footnote).fontWeight(.semibold)
                .foregroundColor(theme.danger)
            Text(message)
                .font(.caption)
                .foregroundColor(theme.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.danger.opacity(0.08))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.danger.opacity(0.2), lineWidth: 1))
    }

    @ViewBuilder
    private func eventsCard(_ job: ImportJobRead, level: String, title: String, color: Color) -> some View {
        let events = job.events.filter { $0.level == level }
        if !events.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label("\(title) (\(events.count))", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote).fontWeight(.semibold)
                    .foregroundColor(color)
                ForEach(events) { event in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.message)
                            .font(.caption)
                            .foregroundColor(theme.textSecondary)
                        if let ref = event.recordRef, !ref.isEmpty {
                            Text(ref)
                                .font(.caption2)
                                .foregroundColor(theme.textTertiary)
                        }
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.08))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.2), lineWidth: 1))
        }
    }

    // MARK: Actions

    /// Loads the job, then polls every 1.5s while it is still running.
    private func pollIfNeeded() async {
        guard let api = store.api else { return }
        do {
            repeat {
                let fresh = try await api.getImportJob(id: jobID)
                await MainActor.run {
                    job = fresh
                    isLoading = false
                }
                if fresh.status.isTerminal { break }
                try await Task.sleep(nanoseconds: 1_500_000_000)
            } while !Task.isCancelled
        } catch is CancellationError {
        } catch {
            await MainActor.run {
                if job == nil { errorMessage = error.userFacingMessage ?? "" }
                isLoading = false
            }
        }
    }

    private func delete(_ job: ImportJobRead) async {
        guard let api = store.api else { return }
        do {
            try await api.deleteImportJob(id: job.id)
            await onChange?()
            await MainActor.run { dismiss() }
        } catch {
            await MainActor.run {
                if (error as NSError).code == 409 {
                    showRunningAlert = true
                } else {
                    errorMessage = error.userFacingMessage ?? ""
                }
            }
        }
    }
}
