import SwiftUI

// MARK: - Board List

struct MessageBoardView: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @State private var isLoading = false
    @State private var refreshToken = 0
    @State private var searchText = ""

    private var callerMemberID: String? {
        store.frontingMembers.first?.id
    }

    private var systemBoards: [BoardSummary] {
        store.boardSummaries.filter { $0.boardKind == .system }
    }

    private var memberBoards: [BoardSummary] {
        let sorted = store.boardSummaries
            .filter { $0.boardKind == .member }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        if searchText.isEmpty { return sorted }
        return sorted.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundPrimary.ignoresSafeArea()

                if isLoading && store.boardSummaries.isEmpty {
                    ProgressView().tint(theme.accentLight)
                } else if store.boardSummaries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.largeTitle)
                            .foregroundColor(theme.textTertiary)
                        Text("No message boards yet")
                            .font(.body).fontWeight(.medium).fontDesign(.rounded)
                            .foregroundColor(theme.textTertiary)
                        Text("Messages will appear once members start posting.")
                            .font(.footnote)
                            .foregroundColor(theme.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                } else {
                    List {
                        if searchText.isEmpty {
                            ForEach(systemBoards) { board in
                                NavigationLink {
                                    BoardDetailView(board: board)
                                        .environmentObject(store)
                                } label: {
                                    BoardRow(board: board)
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 5, leading: 24, bottom: 5, trailing: 24))
                            }
                        }

                        ForEach(memberBoards) { board in
                            NavigationLink {
                                BoardDetailView(board: board)
                                    .environmentObject(store)
                            } label: {
                                BoardRow(board: board)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 5, leading: 24, bottom: 5, trailing: 24))
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .searchable(text: $searchText, prompt: "Search members")
                }
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear { refreshToken += 1 }
        .task(id: refreshToken) { await reload() }
    }

    private func reload() async {
        isLoading = true
        defer { isLoading = false }
        await store.loadBoards(callerMemberID: callerMemberID)
    }
}

// MARK: - Board Row

struct BoardRow: View {
    @Environment(\.theme) var theme
    let board: BoardSummary

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(board.boardKind == .system
                          ? theme.accentLight.opacity(0.15)
                          : theme.textTertiary.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: board.boardKind == .system
                      ? "megaphone.fill" : "person.crop.circle.fill")
                    .font(.body)
                    .foregroundColor(board.boardKind == .system
                                     ? theme.accentLight : theme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(board.displayName)
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundColor(theme.textPrimary)
                    Spacer()
                    if let date = board.lastMessageAt {
                        Text(date, style: .relative)
                            .font(.caption2)
                            .foregroundColor(theme.textTertiary)
                    }
                }

                HStack {
                    if let preview = board.lastMessagePreview, !preview.isEmpty {
                        Text(preview)
                            .font(.caption)
                            .foregroundColor(theme.textSecondary)
                            .lineLimit(1)
                    } else {
                        Text("\(board.messageCount) messages")
                            .font(.caption)
                            .foregroundColor(theme.textTertiary)
                    }

                    Spacer()

                    if board.unreadCount > 0 {
                        Text("\(board.unreadCount)")
                            .font(.caption2).fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(theme.accentLight)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(14)
        .background(theme.backgroundCard)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(theme.border, lineWidth: 1)
        )
    }
}

// MARK: - Board Detail

struct BoardDetailView: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    let board: BoardSummary

    @State private var messages: [BoardMessage] = []
    @State private var isLoading = false
    @State private var hasMore = true
    @State private var callerLastSeenAt: Date?
    @State private var composeText = ""
    @State private var isSending = false
    @State private var replyingTo: BoardMessage?
    @State private var editingMessage: BoardMessage?
    @State private var editText = ""
    @State private var messageToDelete: BoardMessage?
    @State private var showDeleteConfirm = false
    @State private var showDeleteAuthSheet = false
    @State private var showDeleteQueued = false
    @State private var deleteQueuedInfo: DeleteQueued?
    @State private var revisionsMessage: BoardMessage?
    @State private var selectedAuthorID: String?
    @State private var showAuthorPicker = false
    @FocusState private var composeIsFocused: Bool

    private var callerMemberID: String? {
        store.frontingMembers.first?.id
    }

    private var authorMember: Member? {
        if let id = selectedAuthorID {
            return store.members.first { $0.id == id }
        }
        return store.frontingMembers.first
    }

    private var authorMemberID: String? {
        authorMember?.id
    }

    private func requestDelete(_ message: BoardMessage) {
        messageToDelete = message
        let level = store.systemProfile?.deleteConfirmation ?? .none
        if level == .none {
            showDeleteConfirm = true
        } else {
            showDeleteAuthSheet = true
        }
    }

    private func performDelete(id: String, confirmation: MemberDeleteConfirm? = nil) {
        Task {
            let queued = await store.deleteMessage(id: id, confirmation: confirmation)
            if let queued {
                deleteQueuedInfo = queued
                showDeleteQueued = true
            } else {
                messages.removeAll { $0.id == id }
            }
            messageToDelete = nil
        }
    }

    var body: some View {
        ZStack {
            theme.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                if isLoading && messages.isEmpty {
                    Spacer()
                    ProgressView().tint(theme.accentLight)
                    Spacer()
                } else if messages.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "bubble.left")
                            .font(.largeTitle)
                            .foregroundColor(theme.textTertiary)
                        Text("No messages yet")
                            .font(.body).fontWeight(.medium).fontDesign(.rounded)
                            .foregroundColor(theme.textTertiary)
                        Text("Be the first to post!")
                            .font(.footnote)
                            .foregroundColor(theme.textTertiary)
                    }
                    Spacer()
                } else {
                    ScrollViewReader { proxy in
                        List {
                            if hasMore {
                                HStack {
                                    Spacer()
                                    Button("Load Earlier") {
                                        Task { await loadMore() }
                                    }
                                    .font(.subheadline).fontWeight(.medium)
                                    .foregroundColor(theme.accentLight)
                                    Spacer()
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            }

                            ForEach(messages) { message in
                                MessageBubble(
                                    message: message,
                                    isUnread: isUnread(message),
                                    onReply: { replyingTo = message },
                                    onEdit: {
                                        editingMessage = message
                                        editText = message.body
                                    },
                                    onDelete: {
                                        requestDelete(message)
                                    },
                                    onRevisions: {
                                        revisionsMessage = message
                                    }
                                )
                                .id(message.id)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .onChange(of: messages.count) {
                            if let last = messages.last {
                                withAnimation {
                                    proxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                }

                Spacer().frame(height: 60)
            }

            VStack(spacing: 0) {
                Spacer()
                composeBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }
        }
        .navigationTitle(board.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadMessages()
            await markSeen()
        }
        .sheet(item: $editingMessage) { message in
            EditMessageSheet(message: message, editText: $editText) { newBody in
                Task {
                    if let updated = await store.editMessage(id: message.id, body: newBody) {
                        if let idx = messages.firstIndex(where: { $0.id == updated.id }) {
                            messages[idx] = updated
                        }
                    }
                    editingMessage = nil
                }
            }
            .environmentObject(store)
        }
        .confirmationDialog("Delete Message", isPresented: $showDeleteConfirm, presenting: messageToDelete) { msg in
            Button("Delete Message", role: .destructive) {
                performDelete(id: msg.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("This message will be permanently deleted.")
        }
        .sheet(isPresented: $showDeleteAuthSheet) {
            if let msg = messageToDelete {
                DeleteConfirmSheet(resourceName: String(msg.body.prefix(40)), actionLabel: "Delete Message") { confirmation in
                    performDelete(id: msg.id, confirmation: confirmation)
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
        .sheet(item: $revisionsMessage) { message in
            MessageRevisionsView(message: message) { updatedMessage in
                if let idx = messages.firstIndex(where: { $0.id == updatedMessage.id }) {
                    messages[idx] = updatedMessage
                }
            }
            .environmentObject(store)
        }
        .sheet(isPresented: $showAuthorPicker) {
            AuthorPickerSheet(selectedID: $selectedAuthorID)
                .environmentObject(store)
        }
    }

    // MARK: Compose Bar

    private var composeBar: some View {
        VStack(spacing: 6) {
            if let reply = replyingTo {
                HStack(spacing: 6) {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(.system(size: 10))
                        .foregroundColor(theme.accentLight)
                    Text("Replying to \(reply.authorMemberName ?? "someone")")
                        .font(.caption2)
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(1)
                    Button {
                        replyingTo = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(theme.textTertiary)
                    }
                }
            }

            HStack(spacing: 8) {
                if let member = authorMember {
                    Button { showAuthorPicker = true } label: {
                        AvatarView(member: member, size: 26)
                            .id(member.id)
                    }
                }

                TextField("Message", text: $composeText, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .focused($composeIsFocused)

                Button {
                    Task { await send() }
                } label: {
                    if isSending {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(theme.accentLight)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title3)
                            .foregroundColor(composeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                             ? theme.textTertiary : theme.accentLight)
                    }
                }
                .disabled(composeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending || authorMemberID == nil)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .modifier(ComposeBarGlassModifier())
    }

    // MARK: Helpers

    private func isUnread(_ message: BoardMessage) -> Bool {
        guard let seen = callerLastSeenAt else { return false }
        return message.createdAt > seen
    }

    private func loadMessages() async {
        isLoading = true
        defer { isLoading = false }
        if let page = await store.loadMessages(
            boardKind: board.boardKind,
            boardMemberID: board.boardMemberID,
            callerMemberID: callerMemberID
        ) {
            messages = page.messages.reversed()
            callerLastSeenAt = page.callerLastSeenAt
            hasMore = page.messages.count >= 100
        }
    }

    private func loadMore() async {
        guard let oldest = messages.first else { return }
        if let page = await store.loadMessages(
            boardKind: board.boardKind,
            boardMemberID: board.boardMemberID,
            callerMemberID: callerMemberID,
            before: oldest.createdAt
        ) {
            let older = page.messages.reversed()
            messages.insert(contentsOf: older, at: 0)
            hasMore = page.messages.count >= 100
        }
    }

    private func send() async {
        let body = composeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty, let authorID = authorMemberID else { return }
        isSending = true
        defer { isSending = false }

        let create = MessageCreate(
            boardKind: board.boardKind,
            boardMemberID: board.boardMemberID,
            authorMemberID: authorID,
            parentMessageID: replyingTo?.id,
            body: body
        )
        if let sent = await store.sendMessage(create) {
            messages.append(sent)
            composeText = ""
            replyingTo = nil
            composeIsFocused = false
        }
    }

    private func markSeen() async {
        guard let memberID = callerMemberID else { return }
        await store.markBoardSeen(
            memberID: memberID,
            boardKind: board.boardKind,
            boardMemberID: board.boardMemberID
        )
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var store: SystemStore
    let message: BoardMessage
    let isUnread: Bool
    var onReply: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void
    var onRevisions: () -> Void

    @State private var swipeOffset: CGFloat = 0
    @State private var didTriggerReply = false
    private let replyThreshold: CGFloat = 60

    private var member: Member? {
        guard let id = message.authorMemberID else { return nil }
        return store.members.first { $0.id == id }
    }

    private var isOwnMessage: Bool {
        guard let authorID = message.authorMemberID else { return false }
        return store.frontingMembers.contains { $0.id == authorID }
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Image(systemName: "arrowshape.turn.up.left.fill")
                .font(.subheadline)
                .foregroundColor(theme.textTertiary)
                .opacity(swipeOffset > replyThreshold ? 1 : Double(swipeOffset / replyThreshold) * 0.5)
                .scaleEffect(swipeOffset > replyThreshold ? 1.2 : 1.0)
                .padding(.leading, 16)

        VStack(alignment: .leading, spacing: 6) {
            if let parentPreview = message.parentPreview {
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(theme.accentLight.opacity(0.5))
                        .frame(width: 2, height: 14)
                    Text(message.parentAuthorMemberName ?? "someone")
                        .fontWeight(.medium)
                    Text(parentPreview)
                        .lineLimit(1)
                }
                .font(.caption2)
                .foregroundColor(theme.textTertiary)
            }

            HStack(alignment: .top, spacing: 10) {
                if let member {
                    AvatarView(member: member, size: 32)
                } else {
                    Circle()
                        .fill(theme.textTertiary.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.caption)
                                .foregroundColor(theme.textTertiary)
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(message.authorMemberName ?? "[deleted member]")
                            .font(.caption).fontWeight(.semibold)
                            .foregroundColor(member?.displayColor ?? theme.textSecondary)

                        Text(message.createdAt, style: .relative)
                            .font(.caption2)
                            .foregroundColor(theme.textTertiary)

                        if message.isEdited {
                            Text("(edited)")
                                .font(.caption2)
                                .foregroundColor(theme.textTertiary)
                        }
                    }

                    Text(message.body)
                        .font(.subheadline)
                        .foregroundColor(theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(12)
        .modifier(MessageGlassModifier(isUnread: isUnread))
        .offset(x: swipeOffset)
        .gesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    let horizontal = value.translation.width
                    guard horizontal > 0 else { return }
                    swipeOffset = horizontal * 0.6
                    if horizontal > replyThreshold && !didTriggerReply {
                        didTriggerReply = true
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } else if horizontal <= replyThreshold {
                        didTriggerReply = false
                    }
                }
                .onEnded { _ in
                    if didTriggerReply {
                        onReply()
                    }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        swipeOffset = 0
                    }
                    didTriggerReply = false
                }
        )
        .contextMenu {
            Button { onReply() } label: {
                Label("Reply", systemImage: "arrowshape.turn.up.left")
            }

            if isOwnMessage {
                Button { onEdit() } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }

            if message.isEdited {
                Button { onRevisions() } label: {
                    Label("Revisions", systemImage: "clock.arrow.circlepath")
                }
            }

            Button(role: .destructive) { onDelete() } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        } // ZStack
    }
}

// MARK: - Glass Modifier

struct MessageGlassModifier: ViewModifier {
    @Environment(\.theme) var theme
    let isUnread: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isUnread ? theme.accentLight.opacity(0.3) : .clear, lineWidth: 1.5)
                )
        } else {
            content
                .background(
                    isUnread
                    ? theme.accentLight.opacity(0.06)
                    : theme.backgroundCard
                )
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isUnread ? theme.accentLight.opacity(0.2) : theme.border, lineWidth: 1)
                )
        }
    }
}

struct ComposeBarGlassModifier: ViewModifier {
    @Environment(\.theme) var theme

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: Capsule())
        } else {
            content
                .background(theme.backgroundCard)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(theme.border, lineWidth: 1))
        }
    }
}

// MARK: - Edit Message Sheet

struct EditMessageSheet: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    let message: BoardMessage
    @Binding var editText: String
    var onSave: (String) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundPrimary.ignoresSafeArea()

                VStack {
                    TextEditor(text: $editText)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .padding(16)
                        .background(theme.backgroundCard)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(theme.border, lineWidth: 1)
                        )
                        .padding(16)

                    Spacer()
                }
            }
            .navigationTitle("Edit Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(editText)
                    }
                    .fontWeight(.semibold)
                    .disabled(editText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Message Revisions View

struct MessageRevisionsView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var store: SystemStore
    @Environment(\.dismiss) var dismiss
    let message: BoardMessage
    var onRestored: ((BoardMessage) -> Void)?

    @State private var revisions: [ContentRevision] = []
    @State private var isLoading = true
    @State private var selectedRevision: ContentRevision?

    private var sortedRevisions: [ContentRevision] {
        revisions.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            return a.createdAt > b.createdAt
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView().tint(theme.accentLight)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if revisions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.largeTitle)
                            .foregroundColor(theme.textTertiary)
                        Text("No revisions")
                            .font(.body).fontWeight(.medium).fontDesign(.rounded)
                            .foregroundColor(theme.textTertiary)
                        Text("Revisions are created when a message is edited.")
                            .font(.footnote)
                            .foregroundColor(theme.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(sortedRevisions) { revision in
                            Button {
                                selectedRevision = revision
                            } label: {
                                MessageRevisionRow(revision: revision)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 5, leading: 24, bottom: 5, trailing: 24))
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(theme.backgroundPrimary)
            .navigationTitle("Revisions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(theme.accentLight)
                }
            }
        }
        .sheet(item: $selectedRevision) { revision in
            MessageRevisionDetailView(message: message, revision: revision, onPinChanged: { updated in
                if let idx = revisions.firstIndex(where: { $0.id == updated.id }) {
                    revisions[idx] = updated
                }
            }) { restored in
                onRestored?(restored)
                dismiss()
            }
            .environmentObject(store)
        }
        .task { await loadRevisions() }
    }

    func loadRevisions() async {
        isLoading = true
        if let fetched = try? await store.api?.getMessageRevisions(messageID: message.id) {
            revisions = fetched
        }
        isLoading = false
    }
}

// MARK: - Message Revision Row

struct MessageRevisionRow: View {
    @Environment(\.theme) var theme
    let revision: ContentRevision

    private var editorNames: String {
        if !revision.editorMemberNames.isEmpty {
            return revision.editorMemberNames.joined(separator: ", ")
        }
        return "System"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if revision.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 11))
                        .foregroundColor(theme.accentLight)
                }
                Text(String(revision.body.prefix(60)))
                    .font(.subheadline)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(2)
                Spacer()
            }

            if revision.body.count > 60 {
                Text(String(revision.body.dropFirst(60).prefix(120)))
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(2)
            }

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 9))
                        .foregroundColor(theme.textTertiary)
                    Text(revision.createdAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                        .font(.caption2)
                        .foregroundColor(theme.textTertiary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 9))
                        .foregroundColor(theme.textTertiary)
                    Text(editorNames)
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

// MARK: - Message Revision Detail View

struct MessageRevisionDetailView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var store: SystemStore
    @Environment(\.dismiss) var dismiss
    let message: BoardMessage
    let revision: ContentRevision
    var onPinChanged: ((ContentRevision) -> Void)?
    var onRestored: ((BoardMessage) -> Void)?

    @State private var showRestoreConfirm = false
    @State private var isRestoring = false
    @State private var isPinned = false
    @State private var isPinLoading = false
    @State private var pinError: String?
    @State private var showUnpinConfirm = false
    @State private var showUnpinAuth = false
    @State private var unpinQueued: DeleteQueued?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar")
                                .font(.caption)
                                .foregroundColor(theme.textTertiary)
                            Text(revision.createdAt, format: .dateTime.month(.wide).day().year().hour().minute())
                                .font(.subheadline)
                                .foregroundColor(theme.textSecondary)
                        }
                        if !revision.editorMemberNames.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "person.fill")
                                    .font(.caption)
                                    .foregroundColor(theme.textTertiary)
                                Text(revision.editorMemberNames.joined(separator: ", "))
                                    .font(.subheadline)
                                    .foregroundColor(theme.textSecondary)
                            }
                        }
                        if isPinned {
                            HStack(spacing: 8) {
                                Image(systemName: "pin.fill")
                                    .font(.caption)
                                    .foregroundColor(theme.accentLight)
                                Text("Pinned")
                                    .font(.subheadline).fontWeight(.medium)
                                    .foregroundColor(theme.accentLight)
                            }
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.backgroundCard)
                    .cornerRadius(14)

                    Text(revision.body)
                        .font(.body)
                        .foregroundColor(theme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let error = pinError {
                        Text(error)
                            .font(.footnote)
                            .foregroundColor(.red)
                    }

                    if let info = unpinQueued {
                        Label("Unpin queued — finalizes \(info.finalizeAfter, style: .relative). Cancel from System Safety settings.", systemImage: "clock")
                            .font(.footnote)
                            .foregroundColor(theme.textSecondary)
                    }

                    HStack(spacing: 12) {
                        Button {
                            if isPinned {
                                Task { await requestUnpin() }
                            } else {
                                Task { await togglePin() }
                            }
                        } label: {
                            HStack {
                                if isPinLoading {
                                    ProgressView().tint(isPinned ? .white : theme.accentLight).scaleEffect(0.8)
                                }
                                Label(isPinned ? "Unpin" : "Pin", systemImage: isPinned ? "pin.slash" : "pin")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .tint(theme.accentLight)
                        .disabled(isPinLoading)
                        .confirmationDialog("Unpin this revision?", isPresented: $showUnpinConfirm) {
                            Button("Unpin", role: .destructive) {
                                Task { await performUnpin() }
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("Unpinned revisions may be removed by automatic retention cleanup.")
                        }
                        .sheet(isPresented: $showUnpinAuth) {
                            UnpinRevisionSheet(onUnpin: { password, totpCode in
                                try await store.api?.unpinMessageRevision(messageID: message.id, revisionID: revision.id, password: password, totpCode: totpCode)
                            }, onSuccess: { response in
                                handleUnpinResponse(response)
                            })
                            .environmentObject(store)
                        }

                        Button {
                            showRestoreConfirm = true
                        } label: {
                            HStack {
                                if isRestoring {
                                    ProgressView().tint(.white).scaleEffect(0.8)
                                }
                                Label("Restore", systemImage: "arrow.uturn.backward")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(theme.accentLight)
                        .disabled(isRestoring)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(theme.backgroundPrimary)
            .navigationTitle("Revision")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(theme.accentLight)
                }
            }
        }
        .onAppear { isPinned = revision.isPinned }
        .confirmationDialog("Restore this version?", isPresented: $showRestoreConfirm) {
            Button("Restore") {
                Task {
                    isRestoring = true
                    if let restored = try? await store.api?.restoreMessageRevision(messageID: message.id, revisionID: revision.id) {
                        onRestored?(restored)
                    }
                    isRestoring = false
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The current message will be saved as a revision, and this version will become the current content.")
        }
    }

    private func requestUnpin() async {
        if let safety = try? await store.api?.getSystemSafety(),
           safety.settings.appliesToRevisions,
           safety.settings.authTier != .none {
            showUnpinAuth = true
        } else {
            showUnpinConfirm = true
        }
    }

    private func performUnpin() async {
        isPinLoading = true
        pinError = nil
        do {
            let response = try await store.api?.unpinMessageRevision(messageID: message.id, revisionID: revision.id)
            handleUnpinResponse(response)
        } catch {
            pinError = error.localizedDescription
        }
        isPinLoading = false
    }

    private func handleUnpinResponse(_ response: UnpinRevisionResponse?) {
        if let actionID = response?.pendingActionID, let after = response?.finalizeAfter {
            unpinQueued = DeleteQueued(pendingActionID: actionID, finalizeAfter: after)
        } else {
            isPinned = false
            var updated = revision
            updated.pinnedAt = nil
            onPinChanged?(updated)
        }
    }

    func togglePin() async {
        isPinLoading = true
        pinError = nil
        unpinQueued = nil
        do {
            let updated = try await store.api?.pinMessageRevision(messageID: message.id, revisionID: revision.id)
            isPinned = true
            if let updated { onPinChanged?(updated) }
        } catch {
            pinError = error.localizedDescription
        }
        isPinLoading = false
    }
}

// MARK: - Author Picker Sheet

struct AuthorPickerSheet: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @Binding var selectedID: String?
    @State private var searchText = ""

    private var filteredMembers: [Member] {
        let members = store.members.filter { !$0.isCustomFront }
        if searchText.isEmpty { return members }
        return members.filter {
            ($0.displayName ?? $0.name).localizedCaseInsensitiveContains(searchText)
        }
    }

    private var frontingIDs: Set<String> {
        Set(store.frontingMembers.map(\.id))
    }

    private var frontingMembers: [Member] {
        filteredMembers.filter { frontingIDs.contains($0.id) }
    }

    private var otherMembers: [Member] {
        filteredMembers.filter { !frontingIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            List {
                if !frontingMembers.isEmpty {
                    Section("Currently Fronting") {
                        ForEach(frontingMembers) { member in
                            memberRow(member)
                        }
                    }
                }

                Section(frontingMembers.isEmpty ? "Members" : "Other Members") {
                    ForEach(otherMembers) { member in
                        memberRow(member)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Send as...")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search members")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func memberRow(_ member: Member) -> some View {
        Button {
            selectedID = member.id
            dismiss()
        } label: {
            HStack(spacing: 12) {
                AvatarView(member: member, size: 36)

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

                if member.id == selectedID ?? store.frontingMembers.first?.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.title3)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
