import SwiftUI

/// Step-up sheet for ceiling raises made from the content editors. Unlike the
/// Sharing screen, the editors don't preload safety state, so this loads the
/// auth tier itself before showing the credential fields.
struct CeilingStepUpSheet: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme

    let request: StepUpRequest

    @State private var authTier: DeleteConfirmation = .both
    @State private var totpEnabled = false
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ZStack {
                    theme.backgroundPrimary.ignoresSafeArea()
                    ProgressView().tint(theme.accentLight)
                }
                .presentationDetents([.medium])
            } else {
                SharingStepUpSheet(request: request, authTier: authTier, totpEnabled: totpEnabled)
            }
        }
        .task {
            if let safety = try? await store.api?.getSystemSafety() {
                authTier = safety.settings.authTier
            }
            if let me = try? await store.api?.getMe() {
                totpEnabled = me.totpEnabled
            }
            isLoading = false
        }
    }
}

/// Runs a ceiling mutation bare, and hands back a StepUpRequest when the
/// server bounces it for credentials. The server is the only gate consulted;
/// un-exposing directions never bounce so they pass straight through.
func runCeilingChange(
    message: String,
    onError: @escaping (String?) -> Void,
    onStepUp: @escaping (StepUpRequest) -> Void,
    _ op: @escaping (_ password: String?, _ totpCode: String?) async throws -> Void
) {
    Task {
        do {
            try await op(nil, nil)
            await MainActor.run { onError(nil) }
        } catch {
            await MainActor.run {
                if isStepUpBounce(error) {
                    onStepUp(StepUpRequest(message: message, perform: op))
                } else {
                    onError(error.userFacingMessage)
                }
            }
        }
    }
}

/// The member-level sharing ceilings, edited where the member is edited.
/// Applies immediately via its own sparse PATCH, outside the form save and
/// the offline queue, because a raise can demand re-auth and may land staged.
struct MemberCeilingSection: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var store: SystemStore

    @State private var member: Member
    @State private var stepUp: StepUpRequest?
    @State private var errorMessage: String?

    init(member: Member) {
        _member = State(initialValue: member)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Public Sharing")
                .font(.footnote).fontWeight(.semibold)
                .foregroundColor(theme.textSecondary)

            VStack(spacing: 0) {
                Toggle(isOn: Binding(
                    get: { member.neverShareable },
                    set: { setCeiling(neverShareable: $0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Never shareable")
                            .font(.subheadline)
                            .foregroundColor(theme.textPrimary)
                        Text("Excluded from every shared view and public page.")
                            .font(.caption)
                            .foregroundColor(theme.textTertiary)
                    }
                }
                .tint(theme.accentLight)
                .padding(.horizontal, 12).padding(.vertical, 10)

                Divider().background(theme.divider).padding(.leading, 12)

                Toggle(isOn: Binding(
                    get: { member.frontingPrivate },
                    set: { setCeiling(frontingPrivate: $0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Keep fronting private")
                            .font(.subheadline)
                            .foregroundColor(theme.textPrimary)
                        if let at = member.frontingPrivateActivatesAt {
                            Text("Release staged, applies \(at.formatted(.relative(presentation: .named)))")
                                .font(.caption)
                                .foregroundColor(theme.warning)
                        } else {
                            Text("Fronting never appears on shared pages, not even in the hidden count.")
                                .font(.caption)
                                .foregroundColor(theme.textTertiary)
                        }
                    }
                }
                .tint(theme.accentLight)
                .padding(.horizontal, 12).padding(.vertical, 10)

                if let errorMessage {
                    Divider().background(theme.divider).padding(.leading, 12)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(theme.danger)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                }
            }
            .background(theme.backgroundCard)
            .cornerRadius(12)
        }
        .sheet(item: $stepUp) { req in
            CeilingStepUpSheet(request: req)
                .environmentObject(store)
        }
    }

    private func setCeiling(neverShareable: Bool? = nil, frontingPrivate: Bool? = nil) {
        var u = MemberCeilingUpdate()
        u.neverShareable = neverShareable
        u.frontingPrivate = frontingPrivate
        runCeilingChange(
            message: String(localized: "Releasing this guard can expose the member on shared pages."),
            onError: { errorMessage = $0 },
            onStepUp: { stepUp = $0 }
        ) { pw, totp in
            guard let api = store.api else { return }
            var x = u
            x.password = pw
            x.totpCode = totp
            let updated = try await api.updateMemberCeiling(id: member.id, update: x)
            await MainActor.run {
                member = updated
                if let i = store.members.firstIndex(where: { $0.id == updated.id }) {
                    store.members[i] = updated
                }
            }
        }
    }
}

/// Group privacy ceiling: decides whether the group may appear on shared
/// pages at all. Same apply-immediately posture as the member ceilings.
struct GroupCeilingSection: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var store: SystemStore

    @State private var group: SystemGroup
    @State private var stepUp: StepUpRequest?
    @State private var errorMessage: String?

    init(group: SystemGroup) {
        _group = State(initialValue: group)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Privacy")
                .font(.footnote).fontWeight(.semibold)
                .foregroundColor(theme.textSecondary)

            VStack(alignment: .leading, spacing: 6) {
                Picker("Privacy", selection: Binding(
                    get: { group.privacy },
                    set: { setPrivacy($0) }
                )) {
                    ForEach(PrivacyLevel.allCases, id: \.self) { level in
                        Text(level.rawValue.capitalized).tag(level)
                    }
                }
                .pickerStyle(.segmented)

                if let pending = group.pendingPrivacy, let at = group.privacyActivatesAt {
                    Text("Changes to \(pending.rawValue) \(at.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundColor(theme.warning)
                }
                Text("Only public groups can appear on shared pages. Raising to public applies right away.")
                    .font(.caption)
                    .foregroundColor(theme.textTertiary)
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(theme.danger)
                }
            }
        }
        .sheet(item: $stepUp) { req in
            CeilingStepUpSheet(request: req)
                .environmentObject(store)
        }
    }

    private func setPrivacy(_ level: PrivacyLevel) {
        runCeilingChange(
            message: String(localized: "Making this group public can expose it on shared pages."),
            onError: { errorMessage = $0 },
            onStepUp: { stepUp = $0 }
        ) { pw, totp in
            guard let api = store.api else { return }
            let updated = try await api.updateGroupCeiling(
                id: group.id,
                update: GroupCeilingUpdate(privacy: level, password: pw, totpCode: totp)
            )
            await MainActor.run {
                group = updated
                if let i = store.groups.firstIndex(where: { $0.id == updated.id }) {
                    store.groups[i] = updated
                }
            }
        }
    }
}
