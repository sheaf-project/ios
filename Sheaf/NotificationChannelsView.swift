import SwiftUI

// MARK: - NotificationChannelsView

struct NotificationChannelsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    @State private var watchTokens: [WatchToken] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreateWatcher = false
    @State private var newWatcherLabel = ""

    private var activeTokens: [WatchToken] {
        watchTokens.filter { $0.revokedAt == nil }
    }

    var body: some View {
        ZStack {
            theme.backgroundPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    if isLoading && watchTokens.isEmpty {
                        ProgressView()
                            .tint(theme.accentLight)
                            .padding(.top, 60)
                    } else if activeTokens.isEmpty {
                        emptyState
                    } else {
                        watcherList
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 80)
            }
            .refreshable { await loadData() }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showCreateWatcher = true } label: {
                    Image(systemName: "plus")
                        .foregroundColor(theme.accentLight)
                }
            }
        }
        .task { await loadData() }
        .alert("New Watcher", isPresented: $showCreateWatcher) {
            TextField("Label", text: $newWatcherLabel)
            Button("Create") { Task { await createWatcher() } }
            Button("Cancel", role: .cancel) { newWatcherLabel = "" }
        } message: {
            Text("Give this watcher a name to help you identify it.")
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 48))
                .foregroundColor(theme.textTertiary)
            Text("No Watchers")
                .font(.headline)
                .foregroundColor(theme.textPrimary)
            Text("Create a watcher to set up notification channels for fronting changes.")
                .font(.subheadline)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button { showCreateWatcher = true } label: {
                Text("Create Watcher")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24).padding(.vertical, 12)
                    .background(theme.accentLight)
                    .cornerRadius(12)
            }
            .padding(.top, 8)
        }
        .padding(.top, 60)
    }

    private var watcherList: some View {
        VStack(spacing: 0) {
            ForEach(Array(activeTokens.enumerated()), id: \.element.id) { index, token in
                NavigationLink {
                    WatcherDetailView(watchToken: token, onUpdate: { await loadData() })
                        .environmentObject(authManager)
                        .environmentObject(store)
                } label: {
                    watcherRow(token)
                }
                .buttonStyle(.plain)

                if index < activeTokens.count - 1 {
                    Divider().background(theme.divider).padding(.leading, 52)
                }
            }
        }
        .background(theme.backgroundCard)
        .cornerRadius(16)
        .padding(.horizontal, 24)
    }

    private func watcherRow(_ token: WatchToken) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "eye.fill")
                .foregroundColor(theme.accentLight)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(token.label ?? "Untitled Watcher")
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundColor(theme.textPrimary)
                Text("\(token.channelCount) channel\(token.channelCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(theme.textTertiary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(theme.textTertiary)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }

    private func loadData() async {
        guard let api = store.api, let systemID = store.systemProfile?.id else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            watchTokens = try await api.listWatchTokens(systemID: systemID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createWatcher() async {
        guard let api = store.api, let systemID = store.systemProfile?.id else { return }
        let label = newWatcherLabel.trimmingCharacters(in: .whitespaces)
        newWatcherLabel = ""
        do {
            _ = try await api.createWatchToken(systemID: systemID, label: label.isEmpty ? nil : label)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - WatcherDetailView

struct WatcherDetailView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss

    @State var watchToken: WatchToken
    var onUpdate: () async -> Void

    @State private var channels: [NotificationChannel] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreateChannel = false
    @State private var showRename = false
    @State private var renameLabel = ""
    @State private var showRevokeConfirm = false
    @State private var showRevokeAuthSheet = false
    @State private var isRevoking = false
    @State private var revokeQueuedInfo: DeleteQueued?
    @State private var showRevokeQueued = false

    var body: some View {
        ZStack {
            theme.backgroundPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    sectionCard(title: "Watcher") {
                        VStack(spacing: 0) {
                            HStack {
                                Text("Label")
                                    .font(.subheadline).foregroundColor(theme.textSecondary)
                                Spacer()
                                Text(watchToken.label ?? "Untitled")
                                    .font(.subheadline).foregroundColor(theme.textPrimary)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 14)

                            Divider().background(theme.divider)

                            HStack {
                                Text("Created")
                                    .font(.subheadline).foregroundColor(theme.textSecondary)
                                Spacer()
                                Text(watchToken.createdAt, style: .date)
                                    .font(.subheadline).foregroundColor(theme.textTertiary)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 14)
                        }
                    }

                    sectionCard(title: "Channels (\(channels.count))") {
                        if channels.isEmpty && !isLoading {
                            VStack(spacing: 8) {
                                Text("No channels yet")
                                    .font(.subheadline)
                                    .foregroundColor(theme.textTertiary)
                                Button { showCreateChannel = true } label: {
                                    Text("Add Channel")
                                        .font(.subheadline).fontWeight(.medium)
                                        .foregroundColor(theme.accentLight)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(channels.enumerated()), id: \.element.id) { index, channel in
                                    NavigationLink {
                                        ChannelDetailView(channel: channel, onUpdate: { await loadChannels() })
                                            .environmentObject(authManager)
                                            .environmentObject(store)
                                    } label: {
                                        channelRow(channel)
                                    }
                                    .buttonStyle(.plain)

                                    if index < channels.count - 1 {
                                        Divider().background(theme.divider).padding(.leading, 52)
                                    }
                                }
                            }
                        }
                    }

                    sectionCard(title: "Actions") {
                        VStack(spacing: 0) {
                            Button {
                                renameLabel = watchToken.label ?? ""
                                showRename = true
                            } label: {
                                HStack {
                                    Image(systemName: "pencil")
                                        .foregroundColor(theme.accentLight).frame(width: 20)
                                    Text("Rename Watcher")
                                        .font(.subheadline).fontWeight(.medium)
                                        .foregroundColor(theme.accentLight)
                                    Spacer()
                                }
                                .padding(.horizontal, 16).padding(.vertical, 14)
                            }

                            Divider().background(theme.divider)

                            Button { requestRevoke() } label: {
                                HStack {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(theme.danger).frame(width: 20)
                                    Text("Revoke Watcher")
                                        .font(.subheadline).fontWeight(.medium)
                                        .foregroundColor(theme.danger)
                                    Spacer()
                                    if isRevoking {
                                        ProgressView().tint(theme.danger).scaleEffect(0.7)
                                    }
                                }
                                .padding(.horizontal, 16).padding(.vertical, 14)
                            }
                            .disabled(isRevoking)
                        }
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 80)
            }
            .refreshable { await loadChannels() }
        }
        .navigationTitle(watchToken.label ?? "Watcher")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showCreateChannel = true } label: {
                    Image(systemName: "plus")
                        .foregroundColor(theme.accentLight)
                }
            }
        }
        .task { await loadChannels() }
        .sheet(isPresented: $showCreateChannel, onDismiss: { Task { await loadChannels() } }) {
            CreateChannelSheet(watchTokenID: watchToken.id)
                .environmentObject(authManager)
                .environmentObject(store)
        }
        .alert("Rename Watcher", isPresented: $showRename) {
            TextField("Label", text: $renameLabel)
            Button("Save") { Task { await renameWatcher() } }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Revoke this watcher?", isPresented: $showRevokeConfirm, titleVisibility: .visible) {
            Button("Revoke", role: .destructive) { Task { await revokeWatcher(confirmation: nil) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will disable all notification channels under \"\(watchToken.label ?? "this watcher")\". This cannot be undone.")
        }
        .sheet(isPresented: $showRevokeAuthSheet) {
            DeleteConfirmSheet(
                resourceName: watchToken.label ?? "this watcher",
                actionLabel: "Revoke Watcher"
            ) { confirmation in
                Task { await revokeWatcher(confirmation: confirmation) }
            }
            .environmentObject(store)
        }
        .alert("Revocation Queued", isPresented: $showRevokeQueued) {
            Button("OK", role: .cancel) { revokeQueuedInfo = nil }
        } message: {
            if let info = revokeQueuedInfo {
                Text("This revocation has been queued and will finalize \(info.finalizeAfter, style: .relative). You can cancel it from System Safety settings.")
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func channelRow(_ channel: NotificationChannel) -> some View {
        HStack(spacing: 12) {
            Image(systemName: channel.destinationType.icon)
                .foregroundColor(theme.accentLight)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(channel.name)
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundColor(theme.textPrimary)
                Text(channel.destinationType.label)
                    .font(.caption)
                    .foregroundColor(theme.textTertiary)
            }
            Spacer()
            stateIndicator(channel.destinationState)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(theme.textTertiary)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }

    private func stateIndicator(_ state: DestinationState) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(stateColor(state))
                .frame(width: 6, height: 6)
            Text(state.label)
                .font(.caption2).fontWeight(.medium)
                .foregroundColor(stateColor(state))
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(stateColor(state).opacity(0.12))
        .cornerRadius(8)
    }

    private func stateColor(_ state: DestinationState) -> Color {
        switch state {
        case .active: return theme.success
        case .disabled: return theme.textTertiary
        case .pendingRegistration: return .orange
        case .unknown: return theme.textTertiary
        }
    }

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption).fontWeight(.semibold)
                .foregroundColor(theme.textSecondary)
                .textCase(.uppercase)
                .kerning(0.8)
                .padding(.horizontal, 24)
            VStack(spacing: 0) { content() }
                .background(theme.backgroundCard)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.backgroundCard, lineWidth: 1))
                .padding(.horizontal, 24)
        }
    }

    private func loadChannels() async {
        guard let api = store.api else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            channels = try await api.listChannels(watchTokenID: watchToken.id)
                .sorted { $0.createdAt > $1.createdAt }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func renameWatcher() async {
        guard let api = store.api else { return }
        let label = renameLabel.trimmingCharacters(in: .whitespaces)
        do {
            watchToken = try await api.updateWatchToken(id: watchToken.id, label: label.isEmpty ? nil : label)
            await onUpdate()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func requestRevoke() {
        let level = store.systemProfile?.deleteConfirmation ?? .none
        if level == .none {
            showRevokeConfirm = true
        } else {
            showRevokeAuthSheet = true
        }
    }

    private func revokeWatcher(confirmation: MemberDeleteConfirm?) async {
        guard let api = store.api else { return }
        isRevoking = true
        do {
            let queued = try await api.deleteWatchToken(id: watchToken.id, confirmation: confirmation)
            if let queued {
                revokeQueuedInfo = queued
                showRevokeQueued = true
                isRevoking = false
            } else {
                await onUpdate()
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
            isRevoking = false
        }
    }
}

// MARK: - CreateChannelSheet

struct CreateChannelSheet: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss

    let watchTokenID: String

    @State private var name = ""
    @State private var destinationType: DestinationType = .ntfy
    @State private var ntfyServer = "https://ntfy.sh"
    @State private var ntfyTopic = ""
    @State private var pushoverUserKey = ""
    @State private var webhookURL = ""
    @State private var webhookFormat: WebhookFormat = .json
    @State private var webhookSecret = ""
    @State private var triggerOnStart = true
    @State private var triggerOnStop = false
    @State private var triggerOnCofrontChange = false
    @State private var payloadSensitivity: PayloadSensitivity = .full
    @State private var cofrontRedaction: CofrontRedaction = .count
    @State private var includePrivate = false
    @State private var showAdvanced = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var isValid: Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        switch destinationType {
        case .ntfy: return !ntfyServer.isEmpty && !ntfyTopic.trimmingCharacters(in: .whitespaces).isEmpty
        case .pushover: return !pushoverUserKey.trimmingCharacters(in: .whitespaces).isEmpty
        case .webhook: return !webhookURL.trimmingCharacters(in: .whitespaces).isEmpty
        default: return false
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        sectionCard(title: "Destination") {
                            VStack(spacing: 0) {
                                ForEach(DestinationType.creatableTypes, id: \.self) { type in
                                    Button { destinationType = type } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: type.icon)
                                                .foregroundColor(destinationType == type ? theme.accentLight : theme.textTertiary)
                                                .frame(width: 20)
                                            Text(type.label)
                                                .font(.subheadline)
                                                .foregroundColor(theme.textPrimary)
                                            Spacer()
                                            if destinationType == type {
                                                Image(systemName: "checkmark")
                                                    .font(.footnote).fontWeight(.semibold)
                                                    .foregroundColor(theme.accentLight)
                                            }
                                        }
                                        .padding(.horizontal, 16).padding(.vertical, 14)
                                    }
                                    if type != DestinationType.creatableTypes.last {
                                        Divider().background(theme.divider).padding(.leading, 52)
                                    }
                                }
                            }
                        }

                        sectionCard(title: "Configuration") {
                            VStack(spacing: 0) {
                                fieldRow(label: "Name", text: $name, placeholder: "e.g. My Phone")

                                Divider().background(theme.divider)

                                switch destinationType {
                                case .ntfy:
                                    fieldRow(label: "Server", text: $ntfyServer, placeholder: "https://ntfy.sh")
                                    Divider().background(theme.divider)
                                    fieldRow(label: "Topic", text: $ntfyTopic, placeholder: "my-sheaf-alerts")
                                case .pushover:
                                    fieldRow(label: "User Key", text: $pushoverUserKey, placeholder: "Your Pushover user key")
                                case .webhook:
                                    fieldRow(label: "URL", text: $webhookURL, placeholder: "https://example.com/webhook", keyboardType: .URL)
                                    Divider().background(theme.divider)
                                    pickerRow(label: "Format", selection: $webhookFormat) { f in
                                        Text(f.label)
                                    }
                                    if webhookFormat.supportsSignature {
                                        Divider().background(theme.divider)
                                        fieldRow(label: "Secret", text: $webhookSecret, placeholder: "Optional HMAC secret", isSecure: true)
                                    }
                                default:
                                    EmptyView()
                                }
                            }
                        }

                        sectionCard(title: "Notify When") {
                            VStack(spacing: 0) {
                                toggleRow(label: "Someone starts fronting", isOn: $triggerOnStart)
                                Divider().background(theme.divider).padding(.leading, 16)
                                toggleRow(label: "Someone stops fronting", isOn: $triggerOnStop)
                                Divider().background(theme.divider).padding(.leading, 16)
                                toggleRow(label: "Co-fronters change", isOn: $triggerOnCofrontChange)
                            }
                        }

                        sectionCard(title: "") {
                            VStack(spacing: 0) {
                                Button { withAnimation { showAdvanced.toggle() } } label: {
                                    HStack {
                                        Image(systemName: "slider.horizontal.3")
                                            .foregroundColor(theme.accentLight)
                                            .frame(width: 20)
                                        Text("Advanced Options")
                                            .font(.subheadline).fontWeight(.medium)
                                            .foregroundColor(theme.textPrimary)
                                        Spacer()
                                        Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                                            .font(.caption)
                                            .foregroundColor(theme.textTertiary)
                                    }
                                    .padding(.horizontal, 16).padding(.vertical, 14)
                                }

                                if showAdvanced {
                                    Divider().background(theme.divider)

                                    pickerRow(label: "Detail Level", selection: $payloadSensitivity) { s in
                                        Text(s.description)
                                    }

                                    Divider().background(theme.divider)

                                    pickerRow(label: "Hidden Co-fronters", selection: $cofrontRedaction) { r in
                                        Text(r.label)
                                    }

                                    Divider().background(theme.divider)

                                    toggleRow(label: "Include private members", isOn: $includePrivate)
                                }
                            }
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundColor(theme.danger)
                                .padding(.horizontal, 24)
                        }

                        Button { Task { await save() } } label: {
                            HStack {
                                if isSaving {
                                    ProgressView().tint(.white)
                                }
                                Text("Create Channel")
                                    .font(.subheadline).fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(isValid ? theme.accentLight : theme.textTertiary)
                            .cornerRadius(12)
                            .padding(.horizontal, 24)
                        }
                        .disabled(!isValid || isSaving)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("New Channel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(theme.accentLight)
                }
            }
        }
    }

    private func save() async {
        guard let api = store.api else { return }
        isSaving = true
        errorMessage = nil

        do {
            var config: [String: String] = [:]
            var secret: String?

            switch destinationType {
            case .ntfy:
                config["server_url"] = ntfyServer
                config["topic"] = ntfyTopic.trimmingCharacters(in: .whitespaces)
            case .pushover:
                config["user_key"] = pushoverUserKey.trimmingCharacters(in: .whitespaces)
            case .webhook:
                config["url"] = webhookURL.trimmingCharacters(in: .whitespaces)
                config["format"] = webhookFormat.rawValue
                if webhookFormat.supportsSignature && !webhookSecret.isEmpty { secret = webhookSecret }
            default: break
            }

            let create = NotificationChannelCreate(
                name: name.trimmingCharacters(in: .whitespaces),
                destinationType: destinationType,
                destinationConfig: config,
                webhookSecret: secret,
                triggerOnStart: triggerOnStart,
                triggerOnStop: triggerOnStop,
                triggerOnCofrontChange: triggerOnCofrontChange,
                cofrontRedaction: cofrontRedaction,
                payloadSensitivity: payloadSensitivity,
                baseAllMembers: true,
                baseIncludePrivate: includePrivate
            )

            _ = try await api.createChannel(watchTokenID: watchTokenID, create: create)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if !title.isEmpty {
                Text(title)
                    .font(.caption).fontWeight(.semibold)
                    .foregroundColor(theme.textSecondary)
                    .textCase(.uppercase)
                    .kerning(0.8)
                    .padding(.horizontal, 24)
            }
            VStack(spacing: 0) { content() }
                .background(theme.backgroundCard)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.backgroundCard, lineWidth: 1))
                .padding(.horizontal, 24)
        }
    }

    private func fieldRow(label: String, text: Binding<String>, placeholder: String, keyboardType: UIKeyboardType = .default, isSecure: Bool = false) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(theme.textSecondary)
                .frame(width: 70, alignment: .leading)
            if isSecure {
                SecureField(placeholder, text: text)
                    .font(.subheadline)
                    .foregroundColor(theme.textPrimary)
            } else {
                TextField(placeholder, text: text)
                    .font(.subheadline)
                    .foregroundColor(theme.textPrimary)
                    .keyboardType(keyboardType)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private func toggleRow(label: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(theme.textPrimary)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(theme.accentLight)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private func pickerRow<T: Hashable & CaseIterable>(label: String, selection: Binding<T>, @ViewBuilder content: @escaping (T) -> some View) -> some View where T.AllCases: RandomAccessCollection {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(theme.textPrimary)
            Spacer()
            Menu {
                Picker("", selection: selection) {
                    ForEach(Array(T.allCases), id: \.self) { item in
                        content(item).tag(item)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    content(selection.wrappedValue)
                        .font(.subheadline)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                }
                .foregroundColor(theme.accentLight)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }
}

// MARK: - ChannelDetailView

struct ChannelDetailView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss

    @State var channel: NotificationChannel
    var onUpdate: () async -> Void

    @State private var isTesting = false
    @State private var testResult: String?
    @State private var showTestResult = false
    @State private var isToggling = false
    @State private var showDeleteConfirm = false
    @State private var showDeleteAuthSheet = false
    @State private var deleteQueuedInfo: DeleteQueued?
    @State private var showDeleteQueued = false
    @State private var isDeleting = false
    @State private var errorMessage: String?
    @State private var hasUnsavedChanges = false

    @State private var triggerOnStart: Bool = true
    @State private var triggerOnStop: Bool = false
    @State private var triggerOnCofrontChange: Bool = false
    @State private var payloadSensitivity: PayloadSensitivity = .full
    @State private var cofrontRedaction: CofrontRedaction = .count
    @State private var includePrivate: Bool = false

    var body: some View {
        ZStack {
            theme.backgroundPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    sectionCard(title: "Status") {
                        VStack(spacing: 0) {
                            HStack {
                                Text("State")
                                    .font(.subheadline).foregroundColor(theme.textSecondary)
                                Spacer()
                                stateIndicator(channel.destinationState)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 14)

                            Divider().background(theme.divider)

                            HStack {
                                Text(channel.destinationState == .active ? "Enabled" : "Disabled")
                                    .font(.subheadline).foregroundColor(theme.textPrimary)
                                Spacer()
                                if isToggling {
                                    ProgressView().tint(theme.accentLight).scaleEffect(0.7)
                                } else {
                                    Toggle("", isOn: Binding(
                                        get: { channel.destinationState == .active },
                                        set: { _ in Task { await toggleEnabled() } }
                                    ))
                                    .labelsHidden()
                                    .tint(theme.accentLight)
                                }
                            }
                            .padding(.horizontal, 16).padding(.vertical, 10)

                            if let lastDelivered = channel.lastDeliveredAt {
                                Divider().background(theme.divider)
                                HStack {
                                    Text("Last Delivered")
                                        .font(.subheadline).foregroundColor(theme.textSecondary)
                                    Spacer()
                                    Text(lastDelivered, style: .relative)
                                        .font(.subheadline).foregroundColor(theme.textTertiary)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 14)
                            }
                        }
                    }

                    sectionCard(title: "Destination") {
                        VStack(spacing: 0) {
                            HStack {
                                Image(systemName: channel.destinationType.icon)
                                    .foregroundColor(theme.accentLight).frame(width: 20)
                                Text(channel.destinationType.label)
                                    .font(.subheadline).foregroundColor(theme.textPrimary)
                                Spacer()
                            }
                            .padding(.horizontal, 16).padding(.vertical, 14)

                            ForEach(Array(channel.destinationConfig.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                                Divider().background(theme.divider)
                                HStack {
                                    Text(formatConfigKey(key))
                                        .font(.subheadline).foregroundColor(theme.textSecondary)
                                    Spacer()
                                    Text(formatConfigValue(key, value))
                                        .font(.footnote).foregroundColor(theme.textTertiary)
                                        .lineLimit(1).truncationMode(.middle)
                                        .frame(maxWidth: 200, alignment: .trailing)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 14)
                            }
                        }
                    }

                    sectionCard(title: "Notify When") {
                        VStack(spacing: 0) {
                            toggleRow(label: "Someone starts fronting", isOn: $triggerOnStart)
                            Divider().background(theme.divider).padding(.leading, 16)
                            toggleRow(label: "Someone stops fronting", isOn: $triggerOnStop)
                            Divider().background(theme.divider).padding(.leading, 16)
                            toggleRow(label: "Co-fronters change", isOn: $triggerOnCofrontChange)
                        }
                    }

                    sectionCard(title: "Privacy") {
                        VStack(spacing: 0) {
                            pickerRow(label: "Detail Level", selection: $payloadSensitivity) { s in
                                Text(s.description)
                            }
                            Divider().background(theme.divider)
                            pickerRow(label: "Hidden Co-fronters", selection: $cofrontRedaction) { r in
                                Text(r.label)
                            }
                            Divider().background(theme.divider)
                            toggleRow(label: "Include private members", isOn: $includePrivate)
                        }
                    }

                    if hasUnsavedChanges {
                        Button { Task { await saveChanges() } } label: {
                            Text("Save Changes")
                                .font(.subheadline).fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(theme.accentLight)
                                .cornerRadius(12)
                                .padding(.horizontal, 24)
                        }
                    }

                    sectionCard(title: "Actions") {
                        VStack(spacing: 0) {
                            Button { Task { await sendTest() } } label: {
                                HStack {
                                    Image(systemName: "paperplane.fill")
                                        .foregroundColor(theme.accentLight).frame(width: 20)
                                    Text("Send Test Notification")
                                        .font(.subheadline).fontWeight(.medium)
                                        .foregroundColor(theme.accentLight)
                                    Spacer()
                                    if isTesting {
                                        ProgressView().tint(theme.accentLight).scaleEffect(0.7)
                                    }
                                }
                                .padding(.horizontal, 16).padding(.vertical, 14)
                            }
                            .disabled(channel.destinationState != .active || isTesting)

                            Divider().background(theme.divider)

                            Button { requestDelete() } label: {
                                HStack {
                                    Image(systemName: "trash.fill")
                                        .foregroundColor(theme.danger).frame(width: 20)
                                    Text("Delete Channel")
                                        .font(.subheadline).fontWeight(.medium)
                                        .foregroundColor(theme.danger)
                                    Spacer()
                                    if isDeleting {
                                        ProgressView().tint(theme.danger).scaleEffect(0.7)
                                    }
                                }
                                .padding(.horizontal, 16).padding(.vertical, 14)
                            }
                            .disabled(isDeleting)
                        }
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 80)
            }
        }
        .navigationTitle(channel.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadEditableState() }
        .onChange(of: triggerOnStart) { checkForChanges() }
        .onChange(of: triggerOnStop) { checkForChanges() }
        .onChange(of: triggerOnCofrontChange) { checkForChanges() }
        .onChange(of: payloadSensitivity) { checkForChanges() }
        .onChange(of: cofrontRedaction) { checkForChanges() }
        .onChange(of: includePrivate) { checkForChanges() }
        .alert("Test Result", isPresented: $showTestResult) {
            Button("OK") {}
        } message: {
            Text(testResult ?? "")
        }
        .confirmationDialog("Delete this channel?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { Task { await deleteChannel(confirmation: nil) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove the notification channel \"\(channel.name)\".")
        }
        .sheet(isPresented: $showDeleteAuthSheet) {
            DeleteConfirmSheet(
                resourceName: channel.name,
                actionLabel: "Delete Channel"
            ) { confirmation in
                Task { await deleteChannel(confirmation: confirmation) }
            }
            .environmentObject(store)
        }
        .alert("Deletion Queued", isPresented: $showDeleteQueued) {
            Button("OK", role: .cancel) { deleteQueuedInfo = nil }
        } message: {
            if let info = deleteQueuedInfo {
                Text("This deletion has been queued and will finalize \(info.finalizeAfter, style: .relative). You can cancel it from System Safety settings.")
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func loadEditableState() {
        triggerOnStart = channel.triggerOnStart
        triggerOnStop = channel.triggerOnStop
        triggerOnCofrontChange = channel.triggerOnCofrontChange
        payloadSensitivity = channel.payloadSensitivity
        cofrontRedaction = channel.cofrontRedaction
        includePrivate = channel.baseIncludePrivate
    }

    private func checkForChanges() {
        hasUnsavedChanges =
            triggerOnStart != channel.triggerOnStart ||
            triggerOnStop != channel.triggerOnStop ||
            triggerOnCofrontChange != channel.triggerOnCofrontChange ||
            payloadSensitivity != channel.payloadSensitivity ||
            cofrontRedaction != channel.cofrontRedaction ||
            includePrivate != channel.baseIncludePrivate
    }

    private func saveChanges() async {
        guard let api = store.api else { return }
        do {
            let update = NotificationChannelUpdate(
                triggerOnStart: triggerOnStart,
                triggerOnStop: triggerOnStop,
                triggerOnCofrontChange: triggerOnCofrontChange,
                cofrontRedaction: cofrontRedaction,
                payloadSensitivity: payloadSensitivity,
                baseIncludePrivate: includePrivate
            )
            channel = try await api.updateChannel(id: channel.id, update: update)
            hasUnsavedChanges = false
            await onUpdate()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleEnabled() async {
        guard let api = store.api else { return }
        isToggling = true
        do {
            if channel.destinationState == .active {
                channel = try await api.disableChannel(id: channel.id)
            } else {
                channel = try await api.enableChannel(id: channel.id)
            }
            await onUpdate()
        } catch {
            errorMessage = error.localizedDescription
        }
        isToggling = false
    }

    private func sendTest() async {
        guard let api = store.api else { return }
        isTesting = true
        do {
            let result = try await api.testChannel(id: channel.id)
            if result.delivered {
                testResult = "Test notification sent successfully!"
            } else {
                testResult = "Delivery failed: \(result.error ?? "Unknown error")"
            }
        } catch {
            testResult = "Error: \(error.localizedDescription)"
        }
        isTesting = false
        showTestResult = true
    }

    private func requestDelete() {
        let level = store.systemProfile?.deleteConfirmation ?? .none
        if level == .none {
            showDeleteConfirm = true
        } else {
            showDeleteAuthSheet = true
        }
    }

    private func deleteChannel(confirmation: MemberDeleteConfirm?) async {
        guard let api = store.api else { return }
        isDeleting = true
        do {
            let queued = try await api.deleteChannel(id: channel.id, confirmation: confirmation)
            if let queued {
                deleteQueuedInfo = queued
                showDeleteQueued = true
                isDeleting = false
            } else {
                await onUpdate()
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
            isDeleting = false
        }
    }

    private func formatConfigKey(_ key: String) -> String {
        key.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func formatConfigValue(_ key: String, _ value: String) -> String {
        if key == "format", let format = WebhookFormat(rawValue: value) {
            return format.label
        }
        return value
    }

    private func stateIndicator(_ state: DestinationState) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(stateColor(state))
                .frame(width: 6, height: 6)
            Text(state.label)
                .font(.caption2).fontWeight(.medium)
                .foregroundColor(stateColor(state))
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(stateColor(state).opacity(0.12))
        .cornerRadius(8)
    }

    private func stateColor(_ state: DestinationState) -> Color {
        switch state {
        case .active: return theme.success
        case .disabled: return theme.textTertiary
        case .pendingRegistration: return .orange
        case .unknown: return theme.textTertiary
        }
    }

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption).fontWeight(.semibold)
                .foregroundColor(theme.textSecondary)
                .textCase(.uppercase)
                .kerning(0.8)
                .padding(.horizontal, 24)
            VStack(spacing: 0) { content() }
                .background(theme.backgroundCard)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.backgroundCard, lineWidth: 1))
                .padding(.horizontal, 24)
        }
    }

    private func toggleRow(label: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(theme.textPrimary)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(theme.accentLight)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private func pickerRow<T: Hashable & CaseIterable>(label: String, selection: Binding<T>, @ViewBuilder content: @escaping (T) -> some View) -> some View where T.AllCases: RandomAccessCollection {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(theme.textPrimary)
            Spacer()
            Menu {
                Picker("", selection: selection) {
                    ForEach(Array(T.allCases), id: \.self) { item in
                        content(item).tag(item)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    content(selection.wrappedValue)
                        .font(.subheadline)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                }
                .foregroundColor(theme.accentLight)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }
}

// MARK: - DeleteConfirmSheet

struct DeleteConfirmSheet: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var store: SystemStore
    @Environment(\.dismiss) var dismiss
    let resourceName: String
    var actionLabel: String = "Delete"
    var onConfirm: (MemberDeleteConfirm) -> Void

    @State private var password = ""
    @State private var totpCode = ""

    private var level: DeleteConfirmation {
        store.systemProfile?.deleteConfirmation ?? .none
    }

    private var needsPassword: Bool {
        level == .password || level == .both
    }

    private var needsTOTP: Bool {
        level == .totp || level == .both
    }

    private var canSubmit: Bool {
        (!needsPassword || !password.isEmpty) && (!needsTOTP || totpCode.count == 6)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        Text("\"\(resourceName)\"")
                            .font(.subheadline).fontWeight(.medium)
                            .foregroundColor(theme.textPrimary)

                        Text("Your system safety settings require authentication to delete resources.")
                            .font(.footnote)
                            .foregroundColor(theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)

                        VStack(spacing: 0) {
                            if needsPassword {
                                SecureField("Password", text: $password)
                                    .font(.subheadline)
                                    .padding(.horizontal, 16).padding(.vertical, 14)
                                    .background(theme.backgroundCard)
                            }

                            if needsPassword && needsTOTP {
                                Divider().background(theme.divider)
                            }

                            if needsTOTP {
                                TextField("6-digit TOTP code", text: $totpCode)
                                    .font(.subheadline)
                                    .keyboardType(.numberPad)
                                    .padding(.horizontal, 16).padding(.vertical, 14)
                                    .background(theme.backgroundCard)
                                    .onChange(of: totpCode) {
                                        totpCode = String(totpCode.filter(\.isNumber).prefix(6))
                                    }
                            }
                        }
                        .cornerRadius(12)
                        .padding(.horizontal, 24)

                        Button {
                            let confirmation = MemberDeleteConfirm(
                                password: needsPassword ? password : nil,
                                totpCode: needsTOTP ? totpCode : nil
                            )
                            dismiss()
                            onConfirm(confirmation)
                        } label: {
                            Text(actionLabel)
                                .font(.subheadline).fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(canSubmit ? theme.danger : theme.textTertiary)
                                .cornerRadius(12)
                        }
                        .disabled(!canSubmit)
                        .padding(.horizontal, 24)
                    }
                    .padding(.top, 24)
                }
            }
            .navigationTitle("Confirm \(actionLabel)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(theme.accentLight)
                }
            }
        }
    }
}
