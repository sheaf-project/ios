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

    var body: some View {
        HStack(spacing: 16) {
            AvatarView(member: member, size: 64)

            VStack(alignment: .leading, spacing: 6) {
                Text(member.displayName ?? member.name)
                    .font(.title3).fontWeight(.bold).fontDesign(.rounded)
                    .foregroundColor(theme.textPrimary)

                if let pronouns = member.pronouns, !pronouns.isEmpty {
                    Text(pronouns)
                        .font(.footnote)
                        .foregroundColor(theme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(member.displayColor.opacity(0.15))
                        .cornerRadius(8)
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
                Text(member.displayName ?? member.name)
                    .font(.caption2).fontWeight(.medium)
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(1)
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

// MARK: - Switch Fronting Sheet
struct SwitchFrontingSheet: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @State private var selectedIDs: Set<String> = []
    @State private var note = ""
    @State private var isSwitching = false

    var body: some View {
        ZStack {
            theme.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("Switch Fronting")
                        .font(.title3).fontWeight(.bold).fontDesign(.rounded)
                        .foregroundColor(theme.textPrimary)
                    Spacer()
                    Button("Cancel") { dismiss() }
                        .foregroundColor(theme.textSecondary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                HStack(spacing: 6) {
                    Text(selectedIDs.isEmpty
                         ? "Select one or more"
                         : "\(selectedIDs.count) selected")
                        .font(.subheadline)
                        .foregroundColor(selectedIDs.isEmpty
                            ? .white.opacity(0.5)
                            : theme.accentLight)

                    Spacer()

                    // Select all / clear toggle
                    Button {
                        if selectedIDs.count == store.members.count {
                            selectedIDs.removeAll()
                        } else {
                            selectedIDs = Set(store.members.map { $0.id })
                        }
                    } label: {
                        Text(selectedIDs.count == store.members.count ? "Clear All" : "Select All")
                            .font(.caption).fontWeight(.semibold)
                            .foregroundColor(theme.accentLight)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(theme.accentLight.opacity(0.12))
                            .cornerRadius(8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 4)

                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(store.members) { member in
                            MemberSelectRow(member: member, isSelected: selectedIDs.contains(member.id)) {
                                if selectedIDs.contains(member.id) {
                                    selectedIDs.remove(member.id)
                                } else {
                                    selectedIDs.insert(member.id)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                }



                // Confirm
                Button {
                    Task {
                        isSwitching = true
                        await store.switchFronting(to: Array(selectedIDs))
                        isSwitching = false
                        dismiss()
                    }
                } label: {
                    HStack {
                        if isSwitching { ProgressView().tint(.white) }
                        else {
                            Image(systemName: "arrow.left.arrow.right")
                            Text(selectedIDs.count > 1
                                 ? "Co-front (\(selectedIDs.count))"
                                 : "Switch Now")
                                .font(.headline)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(Group {
                        if selectedIDs.isEmpty {
                            theme.backgroundElevated
                        } else {
                            LinearGradient(colors: [theme.accentLight, theme.accent],
                                           startPoint: .leading, endPoint: .trailing)
                        }
                    })
                    .cornerRadius(14)
                }
                .disabled(selectedIDs.isEmpty || isSwitching)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .presentationDragIndicator(.visible)
        .onAppear {
            selectedIDs = Set(store.frontingMembers.map { $0.id })
        }
    }
}

struct MemberSelectRow: View {
    @Environment(\.theme) var theme
    let member: Member
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                AvatarView(member: member, size: 44)
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
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? theme.accentLight : theme.textTertiary)
                    .font(.title3)
            }
            .padding(14)
            .background(isSelected ? theme.accentLight.opacity(0.1) : theme.backgroundCard)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? theme.accentLight.opacity(0.4) : theme.border, lineWidth: 1.5))
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
