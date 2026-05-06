import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: SystemStore
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.theme) var theme
    @State private var showSwitchSheet = false

    var body: some View {
        ZStack {
            // Background
            theme.backgroundGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            if let name = store.systemProfile?.name {
                                Text("Welcome, \(name)")
                                    .font(.title2).fontWeight(.bold).fontDesign(.rounded)
                                    .foregroundColor(theme.textPrimary)
                            }
                            if let since = store.oldestCurrentFront?.startedAt {
                                Text("Since \(since.formatted(date: .omitted, time: .shortened))")
                                    .font(.footnote)
                                    .foregroundColor(theme.textSecondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                    // Pending deletion banner
                    if authManager.accountStatus == .pendingDeletion,
                       let deletionDate = authManager.deletionRequestedAt {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(theme.danger)
                                    .font(.subheadline)
                                Text("Account Deletion Pending")
                                    .font(.subheadline).fontWeight(.semibold)
                                    .foregroundColor(theme.danger)
                                Spacer()
                            }
                            if let days = authManager.deletionGraceDays {
                                let deadline = Calendar.current.date(byAdding: .day, value: days, to: deletionDate) ?? deletionDate
                                if deadline > Date() {
                                    Text("Your account will be permanently deleted in \(deadline, style: .relative). Go to Settings to cancel account deletion.")
                                        .font(.footnote)
                                        .foregroundColor(theme.textSecondary)
                                }
                            } else {
                                Text("Your account is scheduled for deletion. Go to Settings to cancel account deletion.")
                                    .font(.footnote)
                                    .foregroundColor(theme.textSecondary)
                            }
                        }
                        .padding(14)
                        .background(theme.danger.opacity(0.12))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(theme.danger.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal, 24)
                    }

                    // Announcements
                    ForEach(store.visibleAnnouncements) { announcement in
                        AnnouncementBanner(announcement: announcement) {
                            withAnimation {
                                store.dismissAnnouncement(announcement.id)
                            }
                        }
                        .padding(.horizontal, 24)
                    }

                    // System Safety pending items
                    ForEach(safetyBannerItems) { item in
                        SafetyPendingBanner(item: item)
                            .padding(.horizontal, 24)
                    }

                    // Fronting card(s)
                    if store.isLoading && store.currentFronts.isEmpty {
                        FrontingSkeletonView()
                    } else if store.frontingMembers.isEmpty {
                        NoOneFrontingCard()
                    } else {
                        ForEach(store.frontingMembers) { member in
                            FrontingMemberCard(member: member)
                                .padding(.horizontal, 24)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        Task { await removeMemberFromFront(member) }
                                    } label: {
                                        Label("Remove", systemImage: "person.fill.xmark")
                                    }
                                }
                        }
                    }



                    // Quick switch section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Switch")
                            .font(.headline)
                            .foregroundColor(theme.textPrimary.opacity(0.8))
                            .padding(.horizontal, 24)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                Spacer().frame(width: 12)
                                ForEach(store.membersByFrontFrequency.prefix(8)) { member in
                                    QuickSwitchChip(member: member) {
                                        Task { await store.switchFronting(to: [member.id]) }
                                    }
                                }
                                Button {
                                    showSwitchSheet = true
                                } label: {
                                    VStack(spacing: 6) {
                                        ZStack {
                                            Circle()
                                                .stroke(theme.inputBorder, style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                                                .frame(width: 52, height: 52)
                                            Image(systemName: "plus")
                                                .foregroundColor(theme.textSecondary)
                                                .font(.body)
                                        }
                                        Text("More")
                                            .font(.caption2)
                                            .foregroundColor(theme.textTertiary)
                                    }
                                }
                                Spacer().frame(width: 12)
                            }
                        }
                        .background(Color.clear)
                        .scrollContentBackground(.hidden)
                    }

                    Spacer().frame(height: 80)
                }
            }
            .refreshable {
                await refresh()
            }
        }
        .sheet(isPresented: $showSwitchSheet) {
            SwitchFrontingSheet()
                .environmentObject(store)
        }
        .task {
            await loadHistoryForFrequency()
        }
    }


    private var safetyBannerItems: [SafetyBannerItem] {
        var items: [SafetyBannerItem] = []
        if !store.pendingSafetyActions.isEmpty {
            let earliest = store.pendingSafetyActions.map(\.finalizeAfter).min()!
            items.append(SafetyBannerItem(
                id: "actions",
                count: store.pendingSafetyActions.count,
                kind: .actions,
                earliestFinalize: earliest
            ))
        }
        if !store.pendingSafetyChanges.isEmpty {
            let earliest = store.pendingSafetyChanges.map(\.finalizeAfter).min()!
            items.append(SafetyBannerItem(
                id: "changes",
                count: store.pendingSafetyChanges.count,
                kind: .changes,
                earliestFinalize: earliest
            ))
        }
        return items
    }

    func loadHistoryForFrequency() async {
        // Load history in background to power the frequency sort —
        // only fetch if we don't already have it
        if store.frontHistory.isEmpty {
            await store.loadFrontHistory()
        }
    }

    func removeMemberFromFront(_ member: Member) async {
        let remaining = store.frontingMembers
            .filter { $0.id != member.id }
            .map { $0.id }
        if remaining.isEmpty {
            await store.endAllFronts()
        } else {
            await store.switchFronting(to: remaining)
        }
    }

    func refresh() async {
        store.loadAll()
        // Wait briefly for the load to initiate
        try? await Task.sleep(nanoseconds: 500_000_000)
    }
}

// MARK: - Fronting Member Card
struct FrontingMemberCard: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    let member: Member

    private var activeFrontStatus: String? {
        store.currentFronts
            .first { $0.memberIDs.contains(member.id) && $0.endedAt == nil }?
            .customStatus
    }

    var body: some View {
        HStack(spacing: 16) {
            AvatarView(member: member, size: 64)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(member.displayName ?? member.name)
                        .font(.title3).fontWeight(.bold).fontDesign(.rounded)
                        .foregroundColor(theme.textPrimary)
                    if let emoji = member.emoji, !emoji.isEmpty {
                        Text(emoji)
                            .font(.callout)
                    }
                    if member.isCustomFront {
                        Text("CF")
                            .font(.caption2).fontWeight(.bold)
                            .foregroundColor(theme.textTertiary)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(theme.textTertiary.opacity(0.15))
                            .cornerRadius(4)
                    }
                }

                if let pronouns = member.pronouns, !pronouns.isEmpty {
                    Text(pronouns)
                        .font(.footnote)
                        .foregroundColor(theme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(member.displayColor.opacity(0.15))
                        .cornerRadius(8)
                }

                if let status = activeFrontStatus, !status.isEmpty {
                    Text(status)
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            VStack(spacing: 4) {
                Circle()
                    .fill(theme.success)
                    .frame(width: 10, height: 10)
                    .shadow(color: theme.success.opacity(0.8), radius: 4)
                    .accessibilityLabel("Currently fronting")
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [member.displayColor.opacity(0.18),
                         member.displayColor.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(member.displayColor.opacity(0.3), lineWidth: 1.5)
        )
        .contextMenu {
            Button {
                Task { await removeFromFront() }
            } label: {
                Label("Remove from Front", systemImage: "person.fill.xmark")
            }

            Divider()

            Button {
                Task { await store.switchFronting(to: [member.id]) }
            } label: {
                Label("Switch to \(member.displayName ?? member.name) as the only fronter", systemImage: "arrow.left.arrow.right")
            }
        }
    }

    private func removeFromFront() async {
        let remaining = store.frontingMembers
            .filter { $0.id != member.id }
            .map { $0.id }
        if remaining.isEmpty {
            await store.endAllFronts()
        } else {
            await store.switchFronting(to: remaining)
        }
    }
}

// MARK: - No One Fronting
struct NoOneFrontingCard: View {
    @Environment(\.theme) var theme
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.stars.fill")
                .font(.largeTitle)
                .foregroundColor(theme.textTertiary)
            Text("No one is fronting")
                .font(.body).fontWeight(.medium).fontDesign(.rounded)
                .foregroundColor(theme.textSecondary)
            Text("Use Quick Switch below to set who's fronting")
                .font(.footnote)
                .foregroundColor(theme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(theme.backgroundCard)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(theme.border, lineWidth: 1))
        .padding(.horizontal, 24)
    }
}

// MARK: - Quick Switch Chip
struct QuickSwitchChip: View {
    @Environment(\.theme) var theme
    let member: Member
    let onTap: () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                AvatarView(member: member, size: 52)
                HStack(spacing: 2) {
                    if let emoji = member.emoji, !emoji.isEmpty {
                        Text(emoji).font(.caption2)
                    }
                    Text(member.displayName ?? member.name)
                        .font(.caption2).fontWeight(.medium)
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(1)
                }
                .frame(width: 64)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("Switch to \(member.displayName ?? member.name)")
    }
}

// MARK: - Announcement Banner

struct AnnouncementBanner: View {
    @Environment(\.theme) var theme
    let announcement: Announcement
    var onDismiss: (() -> Void)?

    private var severityIcon: String {
        switch announcement.severity {
        case .info:     return "info.circle.fill"
        case .warning:  return "exclamationmark.triangle.fill"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }

    private var severityColor: Color {
        switch announcement.severity {
        case .info:     return theme.accentLight
        case .warning:  return theme.warning
        case .critical: return theme.danger
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: severityIcon)
                    .foregroundColor(severityColor)
                    .font(.subheadline)

                Text(announcement.title)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(theme.textPrimary)

                Spacer()

                if announcement.dismissible, let onDismiss {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.caption).fontWeight(.medium)
                            .foregroundColor(theme.textTertiary)
                    }
                    .accessibilityLabel("Dismiss announcement")
                }
            }

            Text(announcement.body)
                .font(.footnote)
                .foregroundColor(theme.textSecondary)
        }
        .padding(14)
        .background(severityColor.opacity(0.12))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(severityColor.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Safety Pending Banner

enum SafetyBannerKind {
    case actions
    case changes
}

struct SafetyBannerItem: Identifiable {
    let id: String
    let count: Int
    let kind: SafetyBannerKind
    let earliestFinalize: Date
}

private func timeRemaining(until date: Date) -> String {
    let seconds = date.timeIntervalSinceNow
    if seconds <= 0 {
        return String(localized: "any moment")
    }
    let hours = seconds / 3600
    if hours < 24 {
        let h = Int(hours.rounded(.up))
        return String(localized: "in \(h)h")
    }
    let days = Int((seconds / 86400).rounded(.up))
    return days == 1
        ? String(localized: "in 1 day")
        : String(localized: "in \(days) days")
}

struct SafetyPendingBanner: View {
    @Environment(\.theme) var theme
    let item: SafetyBannerItem

    private var isCritical: Bool {
        item.earliestFinalize.timeIntervalSinceNow < 24 * 3600
    }

    private var severityColor: Color {
        isCritical ? theme.danger : theme.warning
    }

    private var severityIcon: String {
        isCritical ? "exclamationmark.octagon.fill" : "exclamationmark.triangle.fill"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: severityIcon)
                    .foregroundColor(severityColor)
                    .font(.subheadline)

                Text(message)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(theme.textPrimary)

                Spacer()
            }
        }
        .padding(14)
        .background(severityColor.opacity(0.12))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(severityColor.opacity(0.3), lineWidth: 1)
        )
    }

    private var message: String {
        let time = timeRemaining(until: item.earliestFinalize)
        switch item.kind {
        case .actions:
            if item.count == 1 {
                return String(localized: "1 pending destructive action finalizes \(time).")
            } else {
                return String(localized: "\(item.count) pending destructive actions — next finalizes \(time).")
            }
        case .changes:
            if item.count == 1 {
                return String(localized: "Safety settings change pending — finalizes \(time).")
            } else {
                return String(localized: "\(item.count) safety settings changes pending — next finalizes \(time).")
            }
        }
    }
}

// MARK: - Skeleton
struct FrontingSkeletonView: View {
    @Environment(\.theme) var theme
    @State private var shimmer = false

    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(theme.backgroundCard)
            .frame(height: 110)
            .padding(.horizontal, 24)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0),
                                     theme.backgroundCard,
                                     Color.white.opacity(0)],
                            startPoint: shimmer ? .topLeading : .bottomTrailing,
                            endPoint: shimmer ? .bottomTrailing : .topLeading
                        )
                    )
                    .padding(.horizontal, 24)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    shimmer = true
                }
            }
    }
}

// MARK: - Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Switch Sheet
struct SwitchFrontingSheet: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @State private var selectedIDs: Set<String> = []
    @State private var isSwitching = false
    @State private var searchText = ""

    private var filteredMembers: [Member] {
        if searchText.isEmpty { return store.members }
        return store.members.filter {
            ($0.displayName ?? $0.name).localizedCaseInsensitiveContains(searchText)
        }
    }

    private var currentlyFronting: [Member] {
        filteredMembers.filter { m in store.frontingMembers.contains(where: { $0.id == m.id }) }
    }

    private var notFronting: [Member] {
        filteredMembers.filter { m in !store.frontingMembers.contains(where: { f in f.id == m.id }) }
    }

    var body: some View {
        NavigationStack {
            List {
                if !currentlyFronting.isEmpty {
                    Section("Currently Fronting") {
                        ForEach(currentlyFronting) { member in
                            memberRow(member)
                        }
                    }
                }

                Section(currentlyFronting.isEmpty ? "Select Members" : "Other Members") {
                    ForEach(notFronting) { member in
                        memberRow(member)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Switch")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search members")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            isSwitching = true
                            await store.switchFronting(to: Array(selectedIDs))
                            isSwitching = false
                            dismiss()
                        }
                    } label: {
                        if isSwitching {
                            ProgressView()
                        } else {
                            Text(selectedIDs.count > 1
                                 ? "Co-front (\(selectedIDs.count))"
                                 : "Switch")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(selectedIDs.isEmpty || isSwitching)
                }
            }
        }
        .onAppear {
            selectedIDs = Set(store.frontingMembers.map { $0.id })
        }
    }

    private func memberRow(_ member: Member) -> some View {
        Button {
            if selectedIDs.contains(member.id) {
                selectedIDs.remove(member.id)
            } else {
                selectedIDs.insert(member.id)
            }
        } label: {
            HStack(spacing: 12) {
                AvatarView(member: member, size: 40)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(member.displayName ?? member.name)
                            .font(.subheadline).fontWeight(.medium)
                        if let emoji = member.emoji, !emoji.isEmpty {
                            Text(emoji).font(.caption)
                        }
                    }
                    if let p = member.pronouns, !p.isEmpty {
                        Text(p)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Image(systemName: selectedIDs.contains(member.id)
                      ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selectedIDs.contains(member.id)
                        ? .accentColor : .secondary)
                    .font(.title3)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
