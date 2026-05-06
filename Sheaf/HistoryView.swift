import SwiftUI

// MARK: - HistoryView
enum GraphTimeRange: String, CaseIterable {
    case week = "7D"
    case twoWeeks = "14D"
    case month = "30D"
    case threeMonths = "90D"

    var days: Int {
        switch self {
        case .week: return 7
        case .twoWeeks: return 14
        case .month: return 30
        case .threeMonths: return 90
        }
    }

    var label: String {
        switch self {
        case .week: return "Last 7 Days"
        case .twoWeeks: return "Last 14 Days"
        case .month: return "Last 30 Days"
        case .threeMonths: return "Last 90 Days"
        }
    }
}

struct HistoryView: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var entryToEdit: FrontEntry?
    @State private var showAddEntry = false
    @State private var entryToDelete: FrontEntry?
    @State private var showDeleteConfirm = false
    @State private var showDeleteQueued = false
    @State private var deleteQueuedInfo: DeleteQueued?
    @State private var graphTimeRange: GraphTimeRange = .week
    @State private var showGraph = true
    @State private var showAnalytics = false

    var body: some View {
        ZStack {
            theme.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("History")
                        .font(.title2).fontWeight(.bold).fontDesign(.rounded)
                        .foregroundColor(theme.textPrimary)
                    Spacer()
                    HStack(spacing: 16) {
                        Button {
                            showAnalytics = true
                        } label: {
                            Image(systemName: "chart.pie.fill")
                                .font(.title3)
                                .foregroundColor(theme.accentLight)
                        }
                        Button {
                            showAddEntry = true
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

                if isLoading && store.frontHistory.isEmpty {
                    Spacer()
                    ProgressView().tint(theme.accentLight)
                    Spacer()
                } else if store.frontHistory.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "clock")
                            .font(.largeTitle)
                            .foregroundColor(theme.textTertiary)
                        Text("No front history yet")
                            .font(.body).fontWeight(.medium).fontDesign(.rounded)
                            .foregroundColor(theme.textTertiary)
                    }
                    Spacer()
                } else {
                    List {
                        // Collapsible time graph
                        Section {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showGraph.toggle()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "chart.bar.fill")
                                        .font(.footnote)
                                        .foregroundColor(theme.accentLight)
                                    Text("Timeline")
                                        .font(.subheadline).fontWeight(.semibold)
                                        .foregroundColor(theme.textSecondary)
                                    Spacer()
                                    Image(systemName: showGraph ? "chevron.up" : "chevron.down")
                                        .font(.caption).fontWeight(.medium)
                                        .foregroundColor(theme.textTertiary)
                                }
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 24, bottom: 0, trailing: 24))

                            if showGraph {
                                FrontTimelineGraph(entries: store.frontHistory, members: store.members, timeRange: $graphTimeRange)
                                    .padding(.vertical, 4)
                                    .listRowBackground(Color.clear)
                                    .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24))
                            }
                        }
                        .listSectionSeparator(.hidden)

                        // Log entries
                        Section("Log") {
                            ForEach(store.frontHistory) { entry in
                                Button {
                                    entryToEdit = entry
                                } label: {
                                    FrontHistoryRow(
                                        entry: entry,
                                        members: membersFor(entry)
                                    )
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
                                .id(entry.id)
                                .onAppear {
                                    if entry.id == store.frontHistory.last?.id {
                                        Task { await loadMore() }
                                    }
                                }
                            }

                            if store.hasMoreHistory {
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
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(theme.backgroundPrimary)
                    .refreshable {
                        await reload()
                    }
                    .alert("Delete this front entry?", isPresented: $showDeleteConfirm, presenting: entryToDelete) { entry in
                        Button("Delete", role: .destructive) {
                            Task { await deleteFrontEntry(entry) }
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: { _ in
                        Text("This will permanently delete this front history entry and cannot be undone.")
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
        }
        .task { await reload() }
        .sheet(isPresented: $showAddEntry, onDismiss: { Task { await reload() } }) {
            AddFrontEntrySheet()
                .environmentObject(store)
        }
        .sheet(item: $entryToEdit, onDismiss: { Task { await reload() } }) { entry in
            EditFrontEntrySheet(entry: entry)
                .environmentObject(store)
        }
        .sheet(isPresented: $showAnalytics) {
            AnalyticsView()
                .environmentObject(store)
        }
    }


    func deleteFrontEntry(_ entry: FrontEntry) async {
        let queued = await store.deleteFront(id: entry.id)
        if let queued {
            deleteQueuedInfo = queued
            showDeleteQueued = true
        }
    }

    func reload() async {
        isLoading = true
        await store.loadFrontHistory()
        isLoading = false
    }

    func loadMore() async {
        guard !isLoadingMore else { return }
        isLoadingMore = true
        await store.loadMoreFrontHistory()
        isLoadingMore = false
    }

    func membersFor(_ entry: FrontEntry) -> [Member] {
        entry.memberIDs.compactMap { id in store.members.first { $0.id == id } }
    }
}

// MARK: - Front Timeline Graph
struct FrontTimelineGraph: View {
    @Environment(\.theme) var theme
    let entries: [FrontEntry]
    let members: [Member]
    @Binding var timeRange: GraphTimeRange

    private var windowStart: Date {
        Calendar.current.date(byAdding: .day, value: -timeRange.days, to: Date()) ?? Date()
    }
    private var windowEnd: Date { Date() }
    private var windowDuration: TimeInterval { windowEnd.timeIntervalSince(windowStart) }

    // Unique members who appear in this window
    private var activeMembers: [Member] {
        let windowEntries = entries.filter { entry in
            let end = entry.endedAt ?? Date()
            return end > windowStart && entry.startedAt < windowEnd
        }
        let ids = Set(windowEntries.flatMap { $0.memberIDs })
        return members.filter { ids.contains($0.id) }
    }

    // Day labels to show — adapt count based on range
    private var dayLabelCount: Int {
        min(timeRange.days, 7)
    }

    private var dayLabelIndices: [Int] {
        let total = timeRange.days
        if total <= 7 {
            return Array(0..<total)
        }
        let step = total / dayLabelCount
        return (0..<dayLabelCount).map { $0 * step }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title + range picker
            HStack {
                Text(timeRange.label)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(theme.textSecondary)
                Spacer()
                HStack(spacing: 0) {
                    ForEach(GraphTimeRange.allCases, id: \.self) { range in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                timeRange = range
                            }
                        } label: {
                            Text(range.rawValue)
                                .font(.caption2).fontWeight(timeRange == range ? .bold : .medium)
                                .foregroundColor(timeRange == range ? theme.accentLight : theme.textTertiary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    timeRange == range
                                        ? theme.accentLight.opacity(0.15)
                                        : Color.clear
                                )
                                .cornerRadius(6)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }

            // Legend
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(activeMembers.prefix(6)) { member in
                        HStack(spacing: 5) {
                            Circle()
                                .fill(member.displayColor)
                                .frame(width: 7, height: 7)
                            if let emoji = member.emoji, !emoji.isEmpty {
                                Text(emoji).font(.caption2)
                            }
                            Text(member.displayName ?? member.name)
                                .font(.caption2)
                                .foregroundColor(theme.textSecondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }

            // Graph
            VStack(spacing: 6) {
                // Day labels
                HStack(spacing: 0) {
                    ForEach(dayLabelIndices, id: \.self) { i in
                        let day = Calendar.current.date(byAdding: .day, value: i - (timeRange.days - 1), to: Date()) ?? Date()
                        Text(timeRange.days <= 14
                             ? day.formatted(.dateTime.weekday(.abbreviated))
                             : day.formatted(.dateTime.month(.abbreviated).day()))
                            .font(.caption2).fontWeight(.medium)
                            .foregroundColor(theme.textTertiary)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Swim lanes — one per member
                VStack(spacing: 4) {
                    ForEach(activeMembers) { member in
                        SwimLane(
                            member: member,
                            entries: entries.filter { $0.memberIDs.contains(member.id) },
                            windowStart: windowStart,
                            windowEnd: windowEnd
                        )
                    }
                }
            }
            .padding(16)
            .background(theme.backgroundCard)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.backgroundCard, lineWidth: 1))
        }
    }
}

// MARK: - Swim Lane (one row per member)
struct SwimLane: View {
    @Environment(\.theme) var theme
    let member: Member
    let entries: [FrontEntry]
    let windowStart: Date
    let windowEnd: Date

    var windowDuration: TimeInterval { windowEnd.timeIntervalSince(windowStart) }

    var body: some View {
        HStack(spacing: 4) {
            // Member initial label
            Text(member.initials)
                .font(.caption2).fontWeight(.bold)
                .foregroundColor(member.displayColor)
                .frame(width: 20, alignment: .center)

            // Track
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(member.displayColor.opacity(0.08))
                        .frame(height: 18)

                    // Blocks for each front entry
                    ForEach(entries) { entry in
                        let start = max(entry.startedAt, windowStart)
                        let end   = min(entry.endedAt ?? windowEnd, windowEnd)
                        let startRatio = start.timeIntervalSince(windowStart) / windowDuration
                        let endRatio   = end.timeIntervalSince(windowStart)   / windowDuration

                        if endRatio > startRatio {
                            let x = geo.size.width * CGFloat(max(0, startRatio))
                            let w = geo.size.width * CGFloat(min(1, endRatio) - max(0, startRatio))

                            RoundedRectangle(cornerRadius: 3)
                                .fill(member.displayColor)
                                .frame(width: max(2, w), height: 18)
                                .offset(x: x)
                        }
                    }
                }
                .clipped()
            }
            .frame(height: 18)
        }
    }
}

// MARK: - Front History Row
struct FrontHistoryRow: View {
    @Environment(\.theme) var theme
    let entry: FrontEntry
    let members: [Member]

    var duration: String {
        let end = entry.endedAt ?? Date()
        let secs = Int(end.timeIntervalSince(entry.startedAt))
        let h = secs / 3600
        let m = (secs % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m" }
        return "<1m"
    }

    var isActive: Bool { entry.endedAt == nil }

    var body: some View {
        HStack(spacing: 14) {
            // Stacked avatars
            ZStack {
                ForEach(Array(members.prefix(3).enumerated()), id: \.offset) { i, member in
                    AvatarView(member: member, size: 36)
                        .overlay(Circle().stroke(theme.backgroundPrimary, lineWidth: 1.5))
                        .offset(x: CGFloat(i) * 14)
                }
            }
            .frame(width: members.isEmpty ? 36 : min(36 + CGFloat(members.count - 1) * 14, 36 + 2 * 14), height: 36, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                // Names
                Text(members.isEmpty ? "Unknown" : members.map { $0.displayName ?? $0.name }.joined(separator: ", "))
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)

                // Custom status
                if let status = entry.customStatus, !status.isEmpty {
                    Text(status)
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(1)
                }

                // Time range
                HStack(spacing: 6) {
                    Text(entry.startedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(theme.textTertiary)

                    if isActive {
                        Text("· now")
                            .font(.caption2).fontWeight(.semibold)
                            .foregroundColor(theme.success)
                    } else if let end = entry.endedAt {
                        Text("→ \(end.formatted(date: .omitted, time: .shortened))")
                            .font(.caption2)
                            .foregroundColor(theme.textTertiary)
                    }
                }
            }

            Spacer()

            // Duration badge
            VStack(alignment: .trailing, spacing: 3) {
                if isActive {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(theme.success)
                            .frame(width: 6, height: 6)
                            .shadow(color: theme.success.opacity(0.8), radius: 3)
                        Text("Active")
                            .font(.caption2).fontWeight(.semibold)
                            .foregroundColor(theme.success)
                    }
                }
                Text(duration)
                    .font(.caption).fontWeight(.medium)
                    .foregroundColor(theme.textTertiary)
            }
        }
        .padding(14)
        .background(theme.backgroundCard)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(isActive ? theme.success.opacity(0.2) : theme.backgroundCard, lineWidth: 1))
    }
}

