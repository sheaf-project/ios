import SwiftUI

// MARK: - HistoryView
struct HistoryView: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    @State private var isLoading = false
    @State private var selectedEntry: FrontEntry?
    @State private var showAddEntry = false

    var body: some View {
        ZStack {
            theme.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("History")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textPrimary)
                    Spacer()
                    HStack(spacing: 16) {
                        Button {
                            showAddEntry = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(theme.accentLight)
                        }
                        Button {
                            Task { await reload() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .semibold))
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
                            .font(.system(size: 44))
                            .foregroundColor(theme.textTertiary)
                        Text("No front history yet")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundColor(theme.textTertiary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Time graph
                            FrontTimelineGraph(entries: store.frontHistory, members: store.members)
                                .padding(.horizontal, 24)

                            // Divider
                            Rectangle()
                                .fill(theme.backgroundCard)
                                .frame(height: 1)
                                .padding(.horizontal, 24)

                            // Log list
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Log")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(theme.textSecondary)
                                    .textCase(.uppercase)
                                    .kerning(0.8)
                                    .padding(.horizontal, 24)
                                    .padding(.bottom, 12)

                                LazyVStack(spacing: 10) {
                                    ForEach(store.frontHistory) { entry in
                                        FrontHistoryRow(entry: entry, members: membersFor(entry))
                                            .padding(.horizontal, 24)
                                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                                Button(role: .destructive) {
                                                    Task { await deleteFrontEntry(entry) }
                                                } label: {
                                                    Label("Delete", systemImage: "trash")
                                                }
                                            }
                                    }
                                }
                            }

                            Spacer().frame(height: 100)
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
        .task { await reload() }
        .sheet(isPresented: $showAddEntry, onDismiss: { Task { await reload() } }) {
            AddFrontEntrySheet()
                .environmentObject(store)
        }
    }


    func deleteFrontEntry(_ entry: FrontEntry) async {
        guard let api = store.api else { return }
        do {
            try await api.deleteFront(id: entry.id)
            await MainActor.run {
                store.frontHistory.removeAll { $0.id == entry.id }
                // Also remove from currentFronts if it was active
                store.currentFronts.removeAll { $0.id == entry.id }
            }
        } catch {
            store.errorMessage = error.localizedDescription
        }
    }

    func reload() async {
        isLoading = true
        await store.loadFrontHistory()
        isLoading = false
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

    // Show last 7 days
    private var windowStart: Date {
        Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    }
    private var windowEnd: Date { Date() }
    private var windowDuration: TimeInterval { windowEnd.timeIntervalSince(windowStart) }

    // Unique members who appear in this window
    private var activeMembers: [Member] {
        let ids = Set(entries.flatMap { $0.memberIDs })
        return members.filter { ids.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title + legend
            HStack {
                Text("Last 7 Days")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(theme.textSecondary)
                Spacer()
                // Mini legend
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(activeMembers.prefix(6)) { member in
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(member.displayColor)
                                    .frame(width: 7, height: 7)
                                Text(member.displayName ?? member.name)
                                    .font(.system(size: 10))
                                    .foregroundColor(theme.textSecondary)
                            }
                        }
                    }
                }
            }

            // Graph
            VStack(spacing: 6) {
                // Day labels
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { i in
                        let day = Calendar.current.date(byAdding: .day, value: i - 6, to: Date()) ?? Date()
                        Text(day.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.system(size: 9, weight: .medium))
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

                // Hour ticks at bottom
                HStack(spacing: 0) {
                    ForEach([0, 6, 12, 18, 24], id: \.self) { h in
                        Text(h == 0 ? "12am" : h == 24 ? "now" : "\(h < 12 ? h : h - 12)\(h < 12 ? "am" : "pm")")
                            .font(.system(size: 8))
                            .foregroundColor(theme.textTertiary)
                            .frame(maxWidth: .infinity, alignment: h == 0 ? .leading : h == 24 ? .trailing : .center)
                    }
                }
                .padding(.top, 2)
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

                // Member initial label on the left
                Text(member.initials)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(member.displayColor)
                    .frame(width: 16, alignment: .center)
                    .offset(x: -20)
            }
            .padding(.leading, 20)
        }
        .frame(height: 18)
        .padding(.leading, 20)
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
            .frame(width: members.isEmpty ? 36 : min(36 + CGFloat(members.count - 1) * 14, 36 + 2 * 14), height: 36)

            VStack(alignment: .leading, spacing: 3) {
                // Names
                Text(members.isEmpty ? "Unknown" : members.map { $0.displayName ?? $0.name }.joined(separator: ", "))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)

                // Time range
                HStack(spacing: 6) {
                    Text(entry.startedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 11))
                        .foregroundColor(theme.textTertiary)

                    if isActive {
                        Text("· now")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(theme.success)
                    } else if let end = entry.endedAt {
                        Text("→ \(end.formatted(date: .omitted, time: .shortened))")
                            .font(.system(size: 11))
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
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(theme.success)
                    }
                }
                Text(duration)
                    .font(.system(size: 12, weight: .medium))
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
