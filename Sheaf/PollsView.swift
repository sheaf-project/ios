import SwiftUI

// MARK: - Polls List View

struct PollsView: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    @State private var isLoading = false
    @State private var showNewPoll = false
    @State private var selectedPoll: Poll?
    @State private var pollToDelete: Poll?
    @State private var showDeleteConfirm = false
    @State private var showDeleteAuthSheet = false
    @State private var showDeleteQueued = false
    @State private var deleteQueuedInfo: DeleteQueued?

    private var openPolls: [Poll] { store.polls.filter { !$0.isClosed } }
    private var closedPolls: [Poll] { store.polls.filter { $0.isClosed } }

    private func requestDelete(_ poll: Poll) {
        pollToDelete = poll
        let level = store.systemProfile?.deleteConfirmation ?? .none
        if level == .none {
            showDeleteConfirm = true
        } else {
            showDeleteAuthSheet = true
        }
    }

    var body: some View {
        ZStack {
            theme.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("Polls")
                        .font(.title2).fontWeight(.bold).fontDesign(.rounded)
                        .foregroundColor(theme.textPrimary)
                    Spacer()
                    HStack(spacing: 16) {
                        Button {
                            showNewPoll = true
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

                if isLoading && store.polls.isEmpty {
                    Spacer()
                    ProgressView().tint(theme.accentLight)
                    Spacer()
                } else if store.polls.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.largeTitle)
                            .foregroundColor(theme.textTertiary)
                        Text("No polls yet")
                            .font(.body).fontWeight(.medium).fontDesign(.rounded)
                            .foregroundColor(theme.textTertiary)
                        Text("Tap + to create your first poll.")
                            .font(.footnote)
                            .foregroundColor(theme.textTertiary)
                    }
                    Spacer()
                } else {
                    List {
                        if !openPolls.isEmpty {
                            Section {
                                ForEach(openPolls) { poll in
                                    pollRow(poll)
                                }
                            } header: {
                                Text("Open")
                                    .font(.caption).fontWeight(.semibold)
                                    .foregroundColor(theme.textTertiary)
                                    .textCase(nil)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }

                        if !closedPolls.isEmpty {
                            Section {
                                ForEach(closedPolls) { poll in
                                    pollRow(poll)
                                }
                            } header: {
                                Text("Closed")
                                    .font(.caption).fontWeight(.semibold)
                                    .foregroundColor(theme.textTertiary)
                                    .textCase(nil)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(theme.backgroundPrimary)
                    .refreshable {
                        await reload()
                    }
                }
            }
        }
        .task { await reload() }
        .sheet(isPresented: $showNewPoll, onDismiss: { Task { await reload() } }) {
            CreatePollSheet()
                .environmentObject(store)
        }
        .sheet(item: $selectedPoll, onDismiss: { Task { await reload() } }) { poll in
            PollDetailSheet(poll: poll)
                .environmentObject(store)
        }
        .confirmationDialog("Delete this poll?", isPresented: $showDeleteConfirm, presenting: pollToDelete) { poll in
            Button("Delete", role: .destructive) {
                Task {
                    let queued = await store.deletePoll(id: poll.id)
                    if let queued {
                        deleteQueuedInfo = queued
                        showDeleteQueued = true
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("This will permanently delete this poll and all votes.")
        }
        .sheet(isPresented: $showDeleteAuthSheet) {
            if let poll = pollToDelete {
                DeleteConfirmSheet(resourceName: poll.question, actionLabel: "Delete Poll") { confirmation in
                    Task {
                        let queued = await store.deletePoll(id: poll.id, confirmation: confirmation)
                        if let queued {
                            deleteQueuedInfo = queued
                            showDeleteQueued = true
                        }
                    }
                }
                .environmentObject(store)
            }
        }
        .alert("Deletion Queued", isPresented: $showDeleteQueued) {
            Button("OK", role: .cancel) { deleteQueuedInfo = nil }
        } message: {
            if let info = deleteQueuedInfo {
                Text("This deletion has been queued and will finalize \(info.finalizeAfter, style: .relative). You can cancel it from System Safety settings.")
            }
        }
    }

    @ViewBuilder
    private func pollRow(_ poll: Poll) -> some View {
        Button { selectedPoll = poll } label: {
            PollRowView(poll: poll)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                requestDelete(poll)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .listRowInsets(EdgeInsets(top: 5, leading: 24, bottom: 5, trailing: 24))
    }

    func reload() async {
        isLoading = true
        await store.loadPolls()
        isLoading = false
    }
}

// MARK: - Poll Row

struct PollRowView: View {
    @Environment(\.theme) var theme
    let poll: Poll

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(poll.question)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(2)
                Spacer()
                if poll.isClosed {
                    Text("Closed")
                        .font(.caption2).fontWeight(.medium)
                        .foregroundColor(theme.textTertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(theme.textTertiary.opacity(0.15))
                        .cornerRadius(6)
                } else {
                    Text("Open")
                        .font(.caption2).fontWeight(.medium)
                        .foregroundColor(theme.accentLight)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(theme.accentLight.opacity(0.15))
                        .cornerRadius(6)
                }
            }

            if let desc = poll.description, !desc.isEmpty {
                Text(desc)
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(2)
            }

            HStack(spacing: 12) {
                Label(poll.kind.label, systemImage: poll.kind == .singleChoice ? "1.circle" : "checklist")
                    .font(.caption2)
                    .foregroundColor(theme.textTertiary)

                Label("\(poll.totalVotes) vote\(poll.totalVotes == 1 ? "" : "s")", systemImage: "hand.raised")
                    .font(.caption2)
                    .foregroundColor(theme.textTertiary)

                Spacer()

                if poll.isClosed {
                    Text("Closed \(poll.closedSince ?? poll.closesAt, style: .relative) ago")
                        .font(.caption2)
                        .foregroundColor(theme.textTertiary)
                } else {
                    Text("Closes \(poll.closesAt, style: .relative)")
                        .font(.caption2)
                        .foregroundColor(theme.textTertiary)
                }
            }
        }
        .padding(14)
        .background(theme.backgroundCard)
        .cornerRadius(14)
    }
}

// MARK: - Poll Detail Sheet

struct PollDetailSheet: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var store: SystemStore
    @Environment(\.dismiss) var dismiss
    let poll: Poll
    @State private var livePoll: Poll?
    @State private var isLoading = true
    @State private var selectedOptionIDs: Set<String> = []
    @State private var votingAsMemberID: String?
    @State private var isVoting = false
    @State private var voteError: String?
    @State private var showDeleteConfirm = false
    @State private var showDeleteAuthSheet = false
    @State private var showDeleteQueued = false
    @State private var deleteQueuedInfo: DeleteQueued?
    @State private var showAudit = false

    private var activePoll: Poll { livePoll ?? poll }

    private func requestDelete() {
        let level = store.systemProfile?.deleteConfirmation ?? .none
        if level == .none {
            showDeleteConfirm = true
        } else {
            showDeleteAuthSheet = true
        }
    }

    private var frontingMemberIDs: [String] {
        let ids = store.currentFronts.flatMap { $0.memberIDs }
        if activePoll.includeCustomFronts {
            return ids
        }
        return ids.filter { id in
            store.members.first(where: { $0.id == id })?.isCustomFront != true
        }
    }

    private var myVote: PollVote? {
        guard let memberID = votingAsMemberID else { return nil }
        return activePoll.votes?.first(where: { $0.votedAsMemberID == memberID })
    }

    private var resultsVisible: Bool {
        activePoll.tally != nil
    }

    private var maxVoteCount: Int {
        activePoll.tally?.map(\.count).max() ?? 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if isLoading {
                        HStack { Spacer(); ProgressView().tint(theme.accentLight); Spacer() }
                            .padding(.top, 40)
                    } else {
                        questionSection
                        if !activePoll.isClosed && !frontingMemberIDs.isEmpty {
                            votingSection
                        }
                        resultsSection
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(theme.backgroundPrimary)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(theme.accentLight)
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        showAudit = true
                    } label: {
                        Image(systemName: "list.bullet.clipboard")
                            .foregroundColor(theme.accentLight)
                    }
                    .accessibilityLabel("Audit Log")

                    Button(role: .destructive) {
                        requestDelete()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(theme.danger)
                    }
                    .accessibilityLabel("Delete")
                }
            }
        }
        .task { await refresh() }
        .sheet(isPresented: $showAudit) {
            PollAuditSheet(pollID: activePoll.id)
                .environmentObject(store)
        }
        .confirmationDialog("Delete this poll?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                Task {
                    let queued = await store.deletePoll(id: activePoll.id)
                    if let queued {
                        deleteQueuedInfo = queued
                        showDeleteQueued = true
                    } else {
                        dismiss()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete this poll and all votes.")
        }
        .sheet(isPresented: $showDeleteAuthSheet) {
            DeleteConfirmSheet(resourceName: activePoll.question, actionLabel: "Delete Poll") { confirmation in
                Task {
                    let queued = await store.deletePoll(id: activePoll.id, confirmation: confirmation)
                    if let queued {
                        deleteQueuedInfo = queued
                        showDeleteQueued = true
                    } else {
                        dismiss()
                    }
                }
            }
            .environmentObject(store)
        }
        .alert("Deletion Queued", isPresented: $showDeleteQueued) {
            Button("OK", role: .cancel) {
                deleteQueuedInfo = nil
                dismiss()
            }
        } message: {
            if let info = deleteQueuedInfo {
                Text("This deletion has been queued and will finalize \(info.finalizeAfter, style: .relative). You can cancel it from System Safety settings.")
            }
        }
    }

    // MARK: - Question Section

    @ViewBuilder
    private var questionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(activePoll.question)
                .font(.title3).fontWeight(.bold).fontDesign(.rounded)
                .foregroundColor(theme.textPrimary)

            if let desc = activePoll.description, !desc.isEmpty {
                Text(desc)
                    .font(.subheadline)
                    .foregroundColor(theme.textSecondary)
            }

            HStack(spacing: 16) {
                Label(activePoll.kind.label, systemImage: activePoll.kind == .singleChoice ? "1.circle" : "checklist")
                    .font(.caption)
                    .foregroundColor(theme.textTertiary)

                Label(activePoll.resultsVisibility.label, systemImage: activePoll.resultsVisibility == .live ? "eye" : "eye.slash")
                    .font(.caption)
                    .foregroundColor(theme.textTertiary)
            }

            HStack(spacing: 16) {
                if activePoll.isClosed {
                    Label("Closed \(activePoll.closedSince ?? activePoll.closesAt, style: .relative) ago", systemImage: "lock.fill")
                        .font(.caption)
                        .foregroundColor(theme.textTertiary)
                } else {
                    Label("Closes \(activePoll.closesAt, style: .relative)", systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(theme.textTertiary)
                }

                Label("\(activePoll.totalVotes) vote\(activePoll.totalVotes == 1 ? "" : "s")", systemImage: "hand.raised")
                    .font(.caption)
                    .foregroundColor(theme.textTertiary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.backgroundCard)
        .cornerRadius(14)
    }

    // MARK: - Voting Section

    @ViewBuilder
    private var votingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cast Your Vote")
                .font(.subheadline).fontWeight(.semibold)
                .foregroundColor(theme.textPrimary)

            if frontingMemberIDs.count > 1 {
                Text("Voting as:")
                    .font(.caption)
                    .foregroundColor(theme.textTertiary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(frontingMemberIDs, id: \.self) { memberID in
                            if let member = store.members.first(where: { $0.id == memberID }) {
                                Button {
                                    selectVoter(memberID)
                                } label: {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(member.displayColor)
                                            .frame(width: 10, height: 10)
                                        Text(member.displayName ?? member.name)
                                            .font(.caption).fontWeight(.medium)
                                        if activePoll.votes?.contains(where: { $0.votedAsMemberID == memberID }) == true {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.caption2)
                                                .foregroundColor(theme.accentLight)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(votingAsMemberID == memberID ? theme.accentLight.opacity(0.2) : theme.backgroundCard)
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(votingAsMemberID == memberID ? theme.accentLight : Color.clear, lineWidth: 1.5)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            ForEach(activePoll.options.sorted(by: { $0.position < $1.position })) { option in
                Button {
                    toggleOption(option.id)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: selectedOptionIDs.contains(option.id)
                              ? (activePoll.kind == .singleChoice ? "circle.inset.filled" : "checkmark.circle.fill")
                              : (activePoll.kind == .singleChoice ? "circle" : "circle"))
                            .foregroundColor(selectedOptionIDs.contains(option.id) ? theme.accentLight : theme.textTertiary)
                            .font(.title3)
                        Text(option.text)
                            .font(.subheadline)
                            .foregroundColor(theme.textPrimary)
                        Spacer()
                    }
                    .padding(12)
                    .background(selectedOptionIDs.contains(option.id) ? theme.accentLight.opacity(0.08) : theme.backgroundCard)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(selectedOptionIDs.contains(option.id) ? theme.accentLight.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            if let error = voteError {
                Text(error)
                    .font(.footnote)
                    .foregroundColor(.red)
            }

            HStack(spacing: 12) {
                Button {
                    Task { await submitVote() }
                } label: {
                    Text(myVote != nil ? "Update Vote" : "Vote")
                        .fontWeight(.semibold)
                        .opacity(isVoting ? 0 : 1)
                        .frame(maxWidth: .infinity)
                        .overlay {
                            if isVoting {
                                ProgressView().tint(.white)
                            }
                        }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(theme.accentLight)
                .disabled(selectedOptionIDs.isEmpty || votingAsMemberID == nil || isVoting)

                if myVote != nil {
                    Button {
                        Task { await retractVote() }
                    } label: {
                        Text("Withdraw")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(theme.danger)
                    .disabled(isVoting)
                }
            }
        }
        .padding(16)
        .background(theme.backgroundCard.opacity(0.5))
        .cornerRadius(14)
    }

    // MARK: - Results Section

    @ViewBuilder
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Results")
                .font(.subheadline).fontWeight(.semibold)
                .foregroundColor(theme.textPrimary)

            if !resultsVisible {
                HStack(spacing: 8) {
                    Image(systemName: "eye.slash")
                        .foregroundColor(theme.textTertiary)
                    Text("Results will be visible after the poll closes.")
                        .font(.footnote)
                        .foregroundColor(theme.textTertiary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.backgroundCard)
                .cornerRadius(10)
            } else if let tally = activePoll.tally {
                ForEach(activePoll.options.sorted(by: { $0.position < $1.position })) { option in
                    let count = tally.first(where: { $0.optionID == option.id })?.count ?? 0
                    let pct = activePoll.totalVotes > 0 ? min(Double(count) / Double(activePoll.totalVotes), 1.0) : 0

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(option.text)
                                .font(.subheadline)
                                .foregroundColor(theme.textPrimary)
                            Spacer()
                            Text("\(count)")
                                .font(.subheadline).fontWeight(.semibold)
                                .foregroundColor(theme.textPrimary)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(theme.textTertiary.opacity(0.15))
                                    .frame(height: 8)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(theme.accentLight)
                                    .frame(width: max(geo.size.width * pct, pct > 0 ? 4 : 0), height: 8)
                            }
                        }
                        .frame(height: 8)

                        Text(String(format: "%.0f%%", pct * 100))
                            .font(.caption2)
                            .foregroundColor(theme.textTertiary)
                    }
                    .padding(12)
                    .background(theme.backgroundCard)
                    .cornerRadius(10)
                }
            }
        }
    }

    // MARK: - Actions

    private func selectVoter(_ memberID: String) {
        votingAsMemberID = memberID
        if let vote = activePoll.votes?.first(where: { $0.votedAsMemberID == memberID }) {
            selectedOptionIDs = Set(vote.optionIDs)
        } else {
            selectedOptionIDs = []
        }
    }

    private func toggleOption(_ optionID: String) {
        if activePoll.kind == .singleChoice {
            selectedOptionIDs = [optionID]
        } else {
            if selectedOptionIDs.contains(optionID) {
                selectedOptionIDs.remove(optionID)
            } else {
                selectedOptionIDs.insert(optionID)
            }
        }
    }

    private func refresh() async {
        let firstLoad = livePoll == nil
        if firstLoad { isLoading = true }
        if let refreshed = await store.refreshPoll(id: poll.id) {
            livePoll = refreshed
        }
        if let firstFronting = frontingMemberIDs.first, votingAsMemberID == nil {
            selectVoter(firstFronting)
        }
        if firstLoad { isLoading = false }
    }

    private func submitVote() async {
        guard let memberID = votingAsMemberID, !selectedOptionIDs.isEmpty else { return }
        isVoting = true
        voteError = nil
        let vote = VoteCast(votedAsMemberID: memberID, optionIDs: Array(selectedOptionIDs))
        if await store.castVote(pollID: activePoll.id, vote: vote) != nil {
            await refresh()
        } else if let err = store.errorMessage {
            voteError = err
        }
        isVoting = false
    }

    private func retractVote() async {
        guard let memberID = votingAsMemberID else { return }
        isVoting = true
        voteError = nil
        if await store.withdrawVote(pollID: activePoll.id, memberID: memberID) {
            selectedOptionIDs = []
            await refresh()
        } else if let err = store.errorMessage {
            voteError = err
        }
        isVoting = false
    }
}

// MARK: - Poll Audit Sheet

struct PollAuditSheet: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var store: SystemStore
    @Environment(\.dismiss) var dismiss
    let pollID: String
    @State private var audit: PollAuditRead?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView().tint(theme.accentLight)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let audit, !audit.isVisible {
                    VStack(spacing: 12) {
                        Image(systemName: "eye.slash")
                            .font(.largeTitle)
                            .foregroundColor(theme.textTertiary)
                        Text("Audit log hidden")
                            .font(.body).fontWeight(.medium).fontDesign(.rounded)
                            .foregroundColor(theme.textTertiary)
                        Text("The audit log will be visible after the poll closes.")
                            .font(.footnote)
                            .foregroundColor(theme.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let audit, audit.events.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "list.bullet.clipboard")
                            .font(.largeTitle)
                            .foregroundColor(theme.textTertiary)
                        Text("No votes yet")
                            .font(.body).fontWeight(.medium).fontDesign(.rounded)
                            .foregroundColor(theme.textTertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let audit {
                    List {
                        ForEach(audit.events) { event in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(auditActionLabel(event.action))
                                        .font(.subheadline).fontWeight(.medium)
                                        .foregroundColor(auditActionColor(event.action))
                                    Spacer()
                                    Text(event.createdAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                                        .font(.caption2)
                                        .foregroundColor(theme.textTertiary)
                                }
                                if let memberID = event.votedAsMemberID,
                                   let member = store.members.first(where: { $0.id == memberID }) {
                                    Text(member.displayName ?? member.name)
                                        .font(.caption)
                                        .foregroundColor(theme.textSecondary)
                                }
                            }
                            .padding(12)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 24, bottom: 4, trailing: 24))
                            .background(theme.backgroundCard)
                            .cornerRadius(10)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(theme.backgroundPrimary)
            .navigationTitle("Audit Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(theme.accentLight)
                }
            }
        }
        .task {
            isLoading = true
            audit = try? await store.api?.getPollAudit(pollID: pollID)
            isLoading = false
        }
    }

    private func auditActionLabel(_ action: PollAuditAction) -> String {
        switch action {
        case .cast: return "Voted"
        case .change: return "Changed vote"
        case .withdraw: return "Withdrew vote"
        }
    }

    private func auditActionColor(_ action: PollAuditAction) -> Color {
        switch action {
        case .cast: return theme.accentLight
        case .change: return theme.warning
        case .withdraw: return theme.danger
        }
    }
}

// MARK: - Create Poll Sheet

struct CreatePollSheet: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var store: SystemStore
    @Environment(\.dismiss) var dismiss
    @State private var question = ""
    @State private var description = ""
    @State private var kind: PollKind = .singleChoice
    @State private var resultsVisibility: PollResultsVisibility = .live
    @State private var closesIn: TimeInterval = 24 * 3600
    @State private var includeCustomFronts = false
    @State private var optionTexts: [String] = ["", ""]
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var serverConfig: PollServerConfig?

    private let durationOptions: [(String, TimeInterval)] = [
        ("1 hour", 3600),
        ("6 hours", 6 * 3600),
        ("12 hours", 12 * 3600),
        ("1 day", 24 * 3600),
        ("2 days", 2 * 24 * 3600),
        ("3 days", 3 * 24 * 3600),
        ("1 week", 7 * 24 * 3600),
        ("2 weeks", 14 * 24 * 3600),
        ("1 month", 30 * 24 * 3600),
    ]

    private var validOptions: [String] {
        optionTexts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var canSave: Bool {
        !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && validOptions.count >= 2
        && !isSaving
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Question") {
                    TextField("What should we decide?", text: $question)
                        .foregroundColor(theme.textPrimary)
                        .listRowBackground(theme.backgroundCard)
                }

                Section("Description (optional)") {
                    TextField("Add more context...", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                        .foregroundColor(theme.textPrimary)
                        .listRowBackground(theme.backgroundCard)
                }

                Section("Options") {
                    ForEach(optionTexts.indices, id: \.self) { idx in
                        HStack {
                            TextField("Option \(idx + 1)", text: $optionTexts[idx])
                                .foregroundColor(theme.textPrimary)
                            if optionTexts.count > 2 {
                                Button {
                                    optionTexts.remove(at: idx)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(theme.danger)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .listRowBackground(theme.backgroundCard)
                    }

                    if optionTexts.count < 20 {
                        Button {
                            optionTexts.append("")
                        } label: {
                            Label("Add Option", systemImage: "plus.circle")
                                .foregroundColor(theme.accentLight)
                        }
                        .listRowBackground(theme.backgroundCard)
                    }
                }

                Section("Settings") {
                    Picker("Type", selection: $kind) {
                        ForEach(PollKind.allCases, id: \.self) { k in
                            Text(k.label).tag(k)
                        }
                    }
                    .listRowBackground(theme.backgroundCard)

                    Picker("Results", selection: $resultsVisibility) {
                        ForEach(PollResultsVisibility.allCases, id: \.self) { v in
                            VStack(alignment: .leading) {
                                Text(v.label)
                            }
                            .tag(v)
                        }
                    }
                    .listRowBackground(theme.backgroundCard)

                    Picker("Duration", selection: $closesIn) {
                        ForEach(durationOptions, id: \.1) { label, value in
                            Text(label).tag(value)
                        }
                    }
                    .listRowBackground(theme.backgroundCard)

                    Toggle("Include custom fronts", isOn: $includeCustomFronts)
                        .tint(theme.accentLight)
                        .listRowBackground(theme.backgroundCard)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .listRowBackground(Color.clear)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.backgroundPrimary)
            .navigationTitle("New Poll")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(theme.accentLight)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: save) {
                        if isSaving { ProgressView().tint(theme.accentLight) }
                        else {
                            Text("Create")
                                .fontWeight(.semibold)
                                .foregroundColor(canSave ? theme.accentLight : theme.textTertiary)
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
        .task {
            serverConfig = try? await store.api?.getPollServerConfig()
        }
    }

    func save() {
        isSaving = true
        errorMessage = nil
        Task {
            let create = PollCreate(
                question: question.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines),
                kind: kind,
                resultsVisibility: resultsVisibility,
                closesAt: Date().addingTimeInterval(closesIn),
                includeCustomFronts: includeCustomFronts,
                options: validOptions.map { PollOptionCreate(text: $0) }
            )
            if await store.createPoll(create) != nil {
                dismiss()
            } else {
                errorMessage = store.errorMessage ?? "Failed to create poll."
            }
            isSaving = false
        }
    }
}
