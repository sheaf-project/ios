import SwiftUI

/// The server answers a missing step-up credential with a 400 whose detail the
/// client must not paraphrase away; matching on it is how the web client does it too.
func isStepUpBounce(_ error: Error) -> Bool {
    let e = error as NSError
    return e.code == 400 &&
        (e.localizedDescription == "Password required" || e.localizedDescription == "TOTP code required")
}

/// Resolves a localized string THROUGH the inflection engine. Plain
/// String(localized:) leaves `^[...](inflect: true)` markup unprocessed, so
/// any count string that gets joined or stored as a String must come through
/// here instead.
func inflectedString(_ value: String.LocalizationValue) -> String {
    String(AttributedString(localized: value).characters)
}

struct StepUpRequest: Identifiable {
    let id = UUID()
    let message: String
    let perform: (_ password: String?, _ totpCode: String?) async throws -> Void
}

struct SharingView: View {
    @Environment(\.theme) var theme
    @Environment(\.apiBaseURL) private var baseURL
    @EnvironmentObject var store: SystemStore

    @State private var views: [ShareView] = []
    @State private var grants: [ShareGrant] = []
    @State private var audit: ShareAudit?
    @State private var pendingExposures: [PendingExposure] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    // Mirrors of the server gates; the server stays authoritative on every call.
    @State private var stepUpArmed = false
    @State private var authTier: DeleteConfirmation = .none
    @State private var totpEnabled = false
    @State private var publishingEnabled = true
    @State private var adultAttested = false

    @State private var showNewView = false
    @State private var newViewName = ""
    @State private var showPublish = false
    @State private var createdGrant: ShareGrantCreated?
    @State private var revokeTarget: ShareGrant?
    @State private var isMutating = false

    private var activeGrants: [ShareGrant] {
        grants.filter { $0.status != "revoked" }
    }

    var body: some View {
        ZStack {
            theme.backgroundPrimary.ignoresSafeArea()

            if isLoading {
                ProgressView().tint(theme.accentLight)
            } else if views.isEmpty && grants.isEmpty, let errorMessage {
                errorState(errorMessage)
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        if !publishingEnabled {
                            instanceOffBanner
                        }
                        if !pendingExposures.isEmpty {
                            pendingExposureBanner
                        }
                        if let reason = audit?.profileSuppressed {
                            suppressedBanner(reason)
                        }
                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundColor(theme.danger)
                                .padding(.horizontal, 24)
                        }
                        viewsSection
                        grantsSection
                    }
                    .padding(.vertical, 16)
                }
                .refreshable { await load() }
            }
        }
        .navigationTitle("Sharing")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .alert("New View", isPresented: $showNewView) {
            TextField("Name", text: $newViewName)
            Button("Create") { Task { await createView() } }
            Button("Cancel", role: .cancel) { newViewName = "" }
        } message: {
            Text("A view is a curated selection of what a visitor can see. It shows nothing until you publish it.")
        }
        .sheet(isPresented: $showPublish) {
            PublishGrantSheet(
                views: views,
                grants: activeGrants,
                stepUpArmed: stepUpArmed,
                authTier: authTier,
                totpEnabled: totpEnabled,
                needsAttestation: !adultAttested,
                onCreated: { created in
                    grants.insert(created.grant, at: 0)
                    adultAttested = true
                    createdGrant = created
                    Task { await load() }
                }
            )
            .environmentObject(store)
        }
        .sheet(item: $createdGrant) { created in
            GrantCreatedSheet(created: created, systemID: store.systemProfile?.id, baseURL: baseURL)
        }
        .confirmationDialog(
            "Revoke this share?",
            isPresented: Binding(get: { revokeTarget != nil }, set: { if !$0 { revokeTarget = nil } }),
            titleVisibility: .visible
        ) {
            Button("Revoke", role: .destructive) {
                if let g = revokeTarget { Task { await revoke(g) } }
            }
            Button("Cancel", role: .cancel) { revokeTarget = nil }
        } message: {
            Text("Revoking takes effect immediately. Anyone using this share loses access at once.")
        }
    }

    // MARK: - Banners

    private var instanceOffBanner: some View {
        banner(icon: "moon.zzz.fill", color: theme.textTertiary,
               text: String(localized: "Public profiles are turned off on this server. Nothing new can be published; anything already shared is kept, and revoking still works."))
    }

    private var pendingExposureBanner: some View {
        let next = pendingExposures.map(\.activatesAt).min() ?? Date()
        return banner(icon: "clock.badge.exclamationmark.fill", color: theme.warning,
                      text: inflectedString("^[\(pendingExposures.count) staged change](inflect: true) will make more of this system public. Next takes effect \(next.formatted(.relative(presentation: .named)))."))
    }

    private func suppressedBanner(_ reason: String) -> some View {
        let text: String
        switch reason {
        case "system_private":
            text = String(localized: "Nothing is being served right now because the system privacy level is not public. Set it to public in the system profile to serve these shares.")
        case "publishing_blocked":
            text = String(localized: "Nothing is being served right now: publishing has been blocked by a server operator.")
        case "account_state":
            text = String(localized: "Nothing is being served right now because of the account's state.")
        default:
            text = String(localized: "Nothing is being served right now.")
        }
        return banner(icon: "eye.slash.fill", color: theme.warning, text: text)
    }

    private func banner(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            Text(text)
                .font(.footnote)
                .foregroundColor(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(theme.backgroundCard)
        .cornerRadius(12)
        .padding(.horizontal, 24)
    }

    // MARK: - Views section

    private var viewsSection: some View {
        section(title: String(localized: "Views")) {
            VStack(spacing: 0) {
                if views.isEmpty {
                    Text("No views yet. Create one to choose what a visitor could see.")
                        .font(.footnote)
                        .foregroundColor(theme.textTertiary)
                        .padding(.horizontal, 16).padding(.vertical, 14)
                }
                ForEach(views) { v in
                    NavigationLink {
                        ShareViewDetailView(
                            initial: v,
                            stepUpArmed: stepUpArmed,
                            authTier: authTier,
                            totpEnabled: totpEnabled,
                            publishingEnabled: publishingEnabled,
                            onUpdate: { updated in
                                if let i = views.firstIndex(where: { $0.id == updated.id }) {
                                    views[i] = updated
                                }
                            },
                            onDelete: { id in
                                views.removeAll { $0.id == id }
                                grants.removeAll { $0.viewID == id }
                                Task { await load() }
                            }
                        )
                        .environmentObject(store)
                    } label: {
                        viewRow(v)
                    }
                    .buttonStyle(.plain)
                    Divider().background(theme.divider)
                }

                Button {
                    newViewName = ""
                    showNewView = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(theme.accentLight)
                            .frame(width: 20)
                        Text("New View")
                            .font(.subheadline).fontWeight(.medium)
                            .foregroundColor(theme.accentLight)
                        Spacer()
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                }
                .disabled(!publishingEnabled || isMutating)
                .opacity(publishingEnabled ? 1 : 0.5)
            }
        }
    }

    private func viewRow(_ v: ShareView) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "rectangle.on.rectangle")
                .foregroundColor(theme.accentLight)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(v.name)
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundColor(theme.textPrimary)
                    if v.isShared {
                        statusBadge(String(localized: "Live"), color: theme.success)
                    }
                    if v.flagsActivateAt != nil {
                        statusBadge(String(localized: "Pending"), color: theme.warning)
                    }
                }
                Text("^[\(v.members.count) member](inflect: true) · ^[\(v.fields.count) field](inflect: true)")
                    .font(.caption)
                    .foregroundColor(theme.textTertiary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(theme.textTertiary)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    // MARK: - Grants section

    private var grantsSection: some View {
        section(title: String(localized: "Published Shares")) {
            VStack(spacing: 0) {
                if activeGrants.isEmpty {
                    Text("Nothing is published. Views stay private until you publish one here.")
                        .font(.footnote)
                        .foregroundColor(theme.textTertiary)
                        .padding(.horizontal, 16).padding(.vertical, 14)
                }
                ForEach(activeGrants) { g in
                    grantRow(g)
                    Divider().background(theme.divider)
                }

                Button {
                    showPublish = true
                } label: {
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(theme.accentLight)
                            .frame(width: 20)
                        Text("Publish a View")
                            .font(.subheadline).fontWeight(.medium)
                            .foregroundColor(theme.accentLight)
                        Spacer()
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                }
                .disabled(!publishingEnabled || views.isEmpty || isMutating)
                .opacity(publishingEnabled && !views.isEmpty ? 1 : 0.5)
            }
        }
    }

    private func grantRow(_ g: ShareGrant) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: g.subjectType == "public" ? "person.2.wave.2.fill" : "link")
                .foregroundColor(theme.accentLight)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(g.subjectType == "public" ? "Public profile" : "Share link")
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundColor(theme.textPrimary)
                    if g.status == "pending", let at = g.activatesAt {
                        statusBadge(String(localized: "Live \(at.formatted(.relative(presentation: .named)))"), color: theme.warning)
                    } else if let exp = g.expiresAt, exp < Date() {
                        statusBadge(String(localized: "Expired"), color: theme.textTertiary)
                    } else {
                        statusBadge(String(localized: "Live"), color: theme.success)
                    }
                }
                Text(viewName(g.viewID))
                    .font(.caption)
                    .foregroundColor(theme.textTertiary)
                if let note = g.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(2)
                }
                if let exp = g.expiresAt, exp >= Date() {
                    Text("Expires \(exp.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundColor(theme.textTertiary)
                }
            }
            Spacer()
            Menu {
                if g.subjectType == "public", let sid = store.systemProfile?.id {
                    Button {
                        UIPasteboard.general.string = baseURL + "/p/" + sid
                    } label: {
                        Label("Copy Link", systemImage: "doc.on.doc")
                    }
                }
                if g.subjectType == "link" {
                    Button {
                        Task { await rotate(g) }
                    } label: {
                        Label("Rotate Link", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                Button(role: .destructive) {
                    revokeTarget = g
                } label: {
                    Label("Revoke", systemImage: "xmark.circle")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(theme.textTertiary)
                    .padding(.vertical, 4)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    // MARK: - Shared bits

    private func statusBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2).fontWeight(.semibold)
            .foregroundColor(color)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.12))
            .cornerRadius(6)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(theme.textTertiary)
            Text(message)
                .font(.footnote)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Retry") { Task { await load() } }
                .font(.subheadline).fontWeight(.medium)
                .foregroundColor(theme.accentLight)
        }
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
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
                .padding(.horizontal, 24)
        }
    }

    private func viewName(_ id: String) -> String {
        views.first { $0.id == id }?.name ?? String(localized: "Deleted view")
    }

    // MARK: - Actions

    private func load() async {
        guard let api = store.api else { return }
        isLoading = views.isEmpty && grants.isEmpty
        do {
            async let v = api.getShareViews()
            async let g = api.getShareGrants()
            async let a = api.getSharingAudit()
            views = try await v
            grants = try await g
            audit = try await a
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage
        }
        if let safety = try? await api.getSystemSafety() {
            stepUpArmed = safety.settings.appliesToProfileVisibility
            authTier = safety.settings.authTier
            pendingExposures = safety.pendingExposures
        }
        if let me = try? await api.getMe() {
            totpEnabled = me.totpEnabled
            publishingEnabled = me.publicProfilesEnabled
            adultAttested = me.adultAttestedAt != nil
        }
        isLoading = false
    }

    private func createView() async {
        guard let api = store.api else { return }
        let name = newViewName.trimmingCharacters(in: .whitespacesAndNewlines)
        newViewName = ""
        guard !name.isEmpty else { return }
        isMutating = true
        defer { isMutating = false }
        do {
            let v = try await api.createShareView(ShareViewCreate(name: name))
            views.append(v)
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    private func rotate(_ grant: ShareGrant) async {
        guard let api = store.api else { return }
        isMutating = true
        defer { isMutating = false }
        do {
            let created = try await api.rotateShareGrant(id: grant.id)
            createdGrant = created
            errorMessage = nil
            await load()
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    private func revoke(_ grant: ShareGrant) async {
        guard let api = store.api else { return }
        revokeTarget = nil
        isMutating = true
        defer { isMutating = false }
        do {
            try await api.revokeShareGrant(id: grant.id)
            grants.removeAll { $0.id == grant.id }
            errorMessage = nil
            await load()
        } catch {
            errorMessage = error.userFacingMessage
        }
    }
}

// MARK: - Step-up sheet

struct SharingStepUpSheet: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss

    let request: StepUpRequest
    let authTier: DeleteConfirmation
    let totpEnabled: Bool

    @State private var password = ""
    @State private var totpCode = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    private var needsPassword: Bool {
        authTier == .password || authTier == .both
    }

    private var needsTotp: Bool {
        (authTier == .totp || authTier == .both) && totpEnabled
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Label(request.message, systemImage: "eye.fill")
                        .font(.footnote)
                        .foregroundColor(theme.textSecondary)

                    if needsPassword {
                        HStack {
                            Image(systemName: "key.fill")
                                .foregroundColor(theme.textTertiary)
                                .frame(width: 20)
                            SecureField("Password", text: $password)
                                .font(.subheadline)
                                .textContentType(.password)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .background(theme.backgroundCard)
                        .cornerRadius(12)
                    }

                    if needsTotp {
                        HStack {
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(theme.textTertiary)
                                .frame(width: 20)
                            TextField("6-digit code", text: $totpCode)
                                .font(.subheadline)
                                .textContentType(.oneTimeCode)
                                .keyboardType(.numberPad)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .background(theme.backgroundCard)
                        .cornerRadius(12)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundColor(theme.danger)
                    }
                }

                Spacer()

                Button {
                    Task { await confirm() }
                } label: {
                    HStack {
                        if isWorking { ProgressView().tint(.white) }
                        Text(isWorking ? "Confirming…" : "Confirm")
                            .font(.subheadline).fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(theme.accentLight)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isWorking || (needsPassword && password.isEmpty) || (needsTotp && totpCode.isEmpty))
            }
            .padding(24)
            .background(theme.backgroundPrimary)
            .navigationTitle("Confirm It's You")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(theme.accentLight)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func confirm() async {
        isWorking = true
        errorMessage = nil
        do {
            let pw = needsPassword ? password : nil
            let totp = needsTotp ? totpCode : nil
            try await request.perform(pw, totp)
            dismiss()
        } catch {
            errorMessage = error.userFacingMessage
        }
        isWorking = false
    }
}

// MARK: - Publish sheet

struct PublishGrantSheet: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: SystemStore

    let views: [ShareView]
    let grants: [ShareGrant]
    let stepUpArmed: Bool
    let authTier: DeleteConfirmation
    let totpEnabled: Bool
    let needsAttestation: Bool
    let onCreated: (ShareGrantCreated) -> Void

    @State private var viewID: String = ""
    @State private var subjectType: ShareSubjectType = .link
    @State private var note = ""
    @State private var hasExpiry = false
    @State private var expiresAt = Date().addingTimeInterval(7 * 86400)
    @State private var attested = false
    @State private var password = ""
    @State private var totpCode = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    // The local gate is a mirror of the server's; a bounce means it drifted,
    // so show the credential fields anyway.
    @State private var forceCredentials = false

    private var needsCredentials: Bool {
        (stepUpArmed && authTier != .none) || forceCredentials
    }

    private var needsPassword: Bool {
        needsCredentials && (forceCredentials || authTier == .password || authTier == .both)
    }

    private var needsTotp: Bool {
        needsCredentials && totpEnabled && (forceCredentials || authTier == .totp || authTier == .both)
    }

    private var hasPublicGrant: Bool {
        grants.contains { $0.subjectType == "public" }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("View")
                                .font(.footnote).fontWeight(.semibold)
                                .foregroundColor(theme.textSecondary)
                            Picker("View", selection: $viewID) {
                                ForEach(views) { v in
                                    Text(v.name).tag(v.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(theme.accentLight)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(6)
                            .background(theme.backgroundCard)
                            .cornerRadius(12)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Type")
                                .font(.footnote).fontWeight(.semibold)
                                .foregroundColor(theme.textSecondary)
                            Picker("Type", selection: $subjectType) {
                                Text("Share link").tag(ShareSubjectType.link)
                                Text("Public profile").tag(ShareSubjectType.public)
                            }
                            .pickerStyle(.segmented)
                            Text(subjectType == .link
                                 ? String(localized: "An unlisted link you hand to specific people. Rotating it cuts off anyone holding the old one.")
                                 : String(localized: "A page at a stable public address tied to this system."))
                                .font(.caption)
                                .foregroundColor(theme.textTertiary)
                            if subjectType == .public && hasPublicGrant {
                                Text("This system already has a public profile.")
                                    .font(.caption)
                                    .foregroundColor(theme.warning)
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Note (only you see this)")
                                .font(.footnote).fontWeight(.semibold)
                                .foregroundColor(theme.textSecondary)
                            TextField("e.g. for the group chat", text: $note)
                                .padding(12)
                                .background(theme.backgroundCard)
                                .cornerRadius(12)
                                .foregroundColor(theme.textPrimary)
                        }

                        VStack(spacing: 0) {
                            Toggle(isOn: $hasExpiry) {
                                Text("Expires")
                                    .font(.subheadline)
                                    .foregroundColor(theme.textPrimary)
                            }
                            .tint(theme.accentLight)
                            .padding(.horizontal, 12).padding(.vertical, 10)

                            if hasExpiry {
                                Divider().background(theme.divider).padding(.leading, 12)
                                DatePicker("Until", selection: $expiresAt, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                                    .font(.subheadline)
                                    .foregroundColor(theme.textPrimary)
                                    .tint(theme.accentLight)
                                    .padding(.horizontal, 12).padding(.vertical, 10)
                            }
                        }
                        .background(theme.backgroundCard)
                        .cornerRadius(12)

                        if needsAttestation {
                            Toggle(isOn: $attested) {
                                Text("I confirm I am 18 or older")
                                    .font(.subheadline)
                                    .foregroundColor(theme.textPrimary)
                            }
                            .tint(theme.accentLight)
                            .padding(.horizontal, 12).padding(.vertical, 10)
                            .background(theme.backgroundCard)
                            .cornerRadius(12)
                        }

                        if needsCredentials {
                            VStack(spacing: 0) {
                                Text("Publishing requires re-authentication.")
                                    .font(.caption)
                                    .foregroundColor(theme.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 16).padding(.vertical, 10)

                                if needsPassword {
                                    Divider().background(theme.divider)
                                    HStack {
                                        Image(systemName: "key.fill")
                                            .foregroundColor(theme.textTertiary)
                                            .frame(width: 20)
                                        SecureField("Password", text: $password)
                                            .font(.subheadline)
                                            .textContentType(.password)
                                    }
                                    .padding(.horizontal, 16).padding(.vertical, 12)
                                }

                                if needsTotp {
                                    Divider().background(theme.divider)
                                    HStack {
                                        Image(systemName: "lock.shield.fill")
                                            .foregroundColor(theme.textTertiary)
                                            .frame(width: 20)
                                        TextField("6-digit code", text: $totpCode)
                                            .font(.subheadline)
                                            .textContentType(.oneTimeCode)
                                            .keyboardType(.numberPad)
                                    }
                                    .padding(.horizontal, 16).padding(.vertical, 12)
                                }
                            }
                            .background(theme.backgroundCard)
                            .cornerRadius(12)
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundColor(theme.danger)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Publish")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(theme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await publish() }
                    } label: {
                        if isSaving {
                            ProgressView().tint(theme.accentLight).scaleEffect(0.8)
                        } else {
                            Text("Publish")
                                .font(.callout).fontWeight(.semibold)
                                .foregroundColor(theme.accentLight)
                        }
                    }
                    .disabled(isSaving || viewID.isEmpty
                              || (needsAttestation && !attested)
                              || (needsPassword && password.isEmpty)
                              || (needsTotp && totpCode.isEmpty)
                              || (subjectType == .public && hasPublicGrant))
                }
            }
        }
        .presentationDetents([.large])
        .onAppear {
            if viewID.isEmpty { viewID = views.first?.id ?? "" }
        }
    }

    private func publish() async {
        guard let api = store.api else { return }
        isSaving = true
        errorMessage = nil
        do {
            if needsAttestation {
                _ = try await api.attestAdult()
            }
            var create = ShareGrantCreate(viewID: viewID, subjectType: subjectType)
            let n = note.trimmingCharacters(in: .whitespacesAndNewlines)
            if !n.isEmpty { create.note = n }
            if hasExpiry { create.expiresAt = expiresAt }
            if needsCredentials {
                create.password = needsPassword ? password : nil
                create.totpCode = needsTotp ? totpCode : nil
            }
            let created = try await api.createShareGrant(create)
            await MainActor.run {
                isSaving = false
                onCreated(created)
                dismiss()
            }
        } catch is CancellationError {
            await MainActor.run { isSaving = false }
        } catch {
            await MainActor.run {
                if isStepUpBounce(error) {
                    forceCredentials = true
                    self.errorMessage = String(localized: "Re-authentication is required. Enter your credentials below and try again.")
                } else {
                    self.errorMessage = error.userFacingMessage
                }
                isSaving = false
            }
        }
    }
}

// MARK: - Grant created / token reveal

struct GrantCreatedSheet: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss

    let created: ShareGrantCreated
    let systemID: String?
    let baseURL: String

    @State private var copied = false

    private var link: String? {
        if let token = created.token {
            return baseURL + "/s/" + token
        }
        if created.grant.subjectType == "public", let systemID {
            return baseURL + "/p/" + systemID
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(theme.success)

                if created.grant.status == "pending", let at = created.grant.activatesAt {
                    Text("This share is staged and goes live \(at.formatted(.relative(presentation: .named))). You can revoke it before then from the Sharing screen.")
                        .font(.footnote)
                        .foregroundColor(theme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                if let link {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(created.token != nil ? "Share link" : "Public profile address")
                            .font(.footnote).fontWeight(.semibold)
                            .foregroundColor(theme.textSecondary)
                        Text(link)
                            .font(.footnote.monospaced())
                            .foregroundColor(theme.textPrimary)
                            .textSelection(.enabled)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(theme.backgroundCard)
                            .cornerRadius(12)
                        if created.token != nil {
                            Text("This link is shown only once and cannot be retrieved later. Rotating creates a new one.")
                                .font(.caption)
                                .foregroundColor(theme.warning)
                        }
                    }

                    Button {
                        UIPasteboard.general.string = link
                        copied = true
                    } label: {
                        HStack {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            Text(copied ? "Copied" : "Copy Link")
                                .font(.subheadline).fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(theme.accentLight)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }

                Spacer()
            }
            .padding(24)
            .background(theme.backgroundPrimary)
            .navigationTitle("Published")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(theme.accentLight)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(created.token != nil && !copied)
    }
}
