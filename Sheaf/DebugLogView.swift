import SwiftUI

struct DebugLogView: View {
    @Environment(\.theme) private var theme
    @ObservedObject private var logger = AppLogger.shared
    @State private var searchText = ""
    @State private var selectedCategory: LogCategory?
    @State private var minimumLevel: LogLevel = .debug
    @State private var showClearConfirm = false

    private var filteredEntries: [LogEntry] {
        logger.entries.reversed().filter { entry in
            if let cat = selectedCategory, entry.category != cat { return false }
            if entry.level < minimumLevel { return false }
            if !searchText.isEmpty,
               !entry.message.localizedCaseInsensitiveContains(searchText) {
                return false
            }
            return true
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    var body: some View {
        ZStack {
            theme.backgroundPrimary.ignoresSafeArea()

            if logger.entries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundColor(theme.textTertiary)
                    Text("No logs yet")
                        .font(.subheadline)
                        .foregroundColor(theme.textSecondary)
                    Text("Logs will appear here as the app runs.")
                        .font(.caption)
                        .foregroundColor(theme.textTertiary)
                }
            } else if filteredEntries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 36))
                        .foregroundColor(theme.textTertiary)
                    Text("No matching logs")
                        .font(.subheadline)
                        .foregroundColor(theme.textSecondary)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(filteredEntries) { entry in
                            logRow(entry)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle("Debug Logs")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search logs")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Section("Category") {
                        Button {
                            selectedCategory = nil
                        } label: {
                            Label("All Categories", systemImage: selectedCategory == nil ? "checkmark" : "")
                        }
                        ForEach(LogCategory.allCases) { cat in
                            Button {
                                selectedCategory = cat
                            } label: {
                                Label(cat.rawValue, systemImage: selectedCategory == cat ? "checkmark" : cat.icon)
                            }
                        }
                    }

                    Section("Minimum Level") {
                        ForEach(LogLevel.allCases) { level in
                            Button {
                                minimumLevel = level
                            } label: {
                                Label(level.label, systemImage: minimumLevel == level ? "checkmark" : "")
                            }
                        }
                    }

                    Section {
                        Button(role: .destructive) {
                            showClearConfirm = true
                        } label: {
                            Label("Clear Logs", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundColor(theme.accentLight)
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: logger.exportText) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(theme.accentLight)
                }
            }
        }
        .confirmationDialog("Clear all logs?", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Clear", role: .destructive) { logger.clear() }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Row

    private func logRow(_ entry: LogEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: entry.category.icon)
                    .font(.caption2)
                    .foregroundColor(categoryColor(entry.category))

                Text(entry.category.rawValue)
                    .font(.caption2).fontWeight(.semibold)
                    .foregroundColor(categoryColor(entry.category))

                levelBadge(entry.level)

                Spacer()

                Text(Self.timeFormatter.string(from: entry.timestamp))
                    .font(.caption2).monospacedDigit()
                    .foregroundColor(theme.textTertiary)
            }

            Text(entry.message)
                .font(.caption).fontDesign(.monospaced)
                .foregroundColor(theme.textPrimary)
                .textSelection(.enabled)
                .lineLimit(6)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(theme.backgroundCard)
        .cornerRadius(8)
    }

    private func levelBadge(_ level: LogLevel) -> some View {
        Text(level.label)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .foregroundColor(levelColor(level))
            .background(levelColor(level).opacity(0.15))
            .cornerRadius(4)
    }

    // MARK: - Colors

    private func categoryColor(_ category: LogCategory) -> Color {
        switch category {
        case .auth: return theme.warning
        case .keychain: return theme.accent
        case .sync: return theme.accentLight
        case .api: return theme.success
        case .app: return theme.textSecondary
        }
    }

    private func levelColor(_ level: LogLevel) -> Color {
        switch level {
        case .debug: return theme.textTertiary
        case .info: return theme.accentLight
        case .warning: return theme.warning
        case .error: return theme.danger
        }
    }
}
