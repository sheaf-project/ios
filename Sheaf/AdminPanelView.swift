import SwiftUI

// MARK: - Admin Panel View
struct AdminPanelView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var store: SystemStore

    // Step-up auth state
    @State private var isAdminAuthed = false
    @State private var isCheckingAuth = true
    @State private var password = ""
    @State private var totpCode = ""
    @State private var authError: String?
    @State private var isAuthenticating = false
    @State private var authLevel = "none"    // "none", "password", "totp"
    @State private var totpEnabled = false

    private var canAuthenticate: Bool {
        switch authLevel {
        case "password": return !password.isEmpty
        case "totp": return totpCode.count == 6
        default: return false
        }
    }

    // Stats
    @State private var stats: AdminStats?
    @State private var isLoadingStats = false

    // Users
    @State private var users: [AdminUserRead] = []
    @State private var searchText = ""
    @State private var currentPage = 1
    @State private var hasMoreUsers = true
    @State private var isLoadingUsers = false
    @State private var selectedUser: AdminUserRead?

    // Maintenance
    @State private var showRetentionConfirm = false
    @State private var showCleanupConfirm = false
    @State private var showAuditConfirm = false
    @State private var maintenanceResult: String?
    @State private var showMaintenanceResult = false
    @State private var isRunningMaintenance = false

    // File cleanup
    @State private var showFileCleanupConfirm = false
    @State private var fileCleanupResult: String?
    @State private var showFileCleanupResult = false

    var body: some View {
        ZStack {
            theme.backgroundPrimary.ignoresSafeArea()

            if isCheckingAuth {
                ProgressView().tint(theme.accentLight)
            } else if !isAdminAuthed {
                stepUpAuthView
            } else {
                adminContent
            }
        }
        .navigationTitle("Admin Panel")
        .navigationBarTitleDisplayMode(.inline)
        .task { await checkAdminAuth() }
        .sheet(item: $selectedUser) { user in
            AdminUserEditSheet(user: user) { updatedUser in
                if let idx = users.firstIndex(where: { $0.id == updatedUser.id }) {
                    users[idx] = updatedUser
                }
            }
            .environmentObject(authManager)
            .environmentObject(store)
        }
        .alert("Maintenance", isPresented: $showMaintenanceResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(maintenanceResult ?? "")
        }
        .confirmationDialog("Run Retention?", isPresented: $showRetentionConfirm, titleVisibility: .visible) {
            Button("Run Retention", role: .destructive) { Task { await runMaintenance(.retention) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will run the retention policy and may delete expired data.")
        }
        .confirmationDialog("Run Cleanup?", isPresented: $showCleanupConfirm, titleVisibility: .visible) {
            Button("Run Cleanup", role: .destructive) { Task { await runMaintenance(.cleanup) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will run cleanup tasks on the server.")
        }
        .confirmationDialog("View Storage Stats?", isPresented: $showAuditConfirm, titleVisibility: .visible) {
            Button("Get Storage Stats") { Task { await runMaintenance(.storageStats) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will fetch storage usage statistics from the server.")
        }
        .confirmationDialog("Clean Up Orphaned Files?", isPresented: $showFileCleanupConfirm, titleVisibility: .visible) {
            Button("Clean Up", role: .destructive) { Task { await runFileCleanup() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove orphaned files that are no longer referenced by any member or system profile.")
        }
        .alert("File Cleanup", isPresented: $showFileCleanupResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(fileCleanupResult ?? "")
        }
    }

    // MARK: - Step-Up Auth

    private var stepUpAuthView: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 48))
                        .foregroundColor(theme.accentLight)

                    Text("Admin Authentication")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textPrimary)

                    Text(authLevel == "totp"
                         ? "Enter your TOTP code to access the admin panel."
                         : "Enter your password to access the admin panel.")
                        .font(.system(size: 14))
                        .foregroundColor(theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 40)

                VStack(spacing: 16) {
                    if authLevel == "password" {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(theme.textSecondary)
                            SecureField("Enter your password", text: $password)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .padding(14)
                                .background(theme.backgroundCard)
                                .cornerRadius(12)
                                .foregroundColor(theme.textPrimary)
                        }
                    }

                    if authLevel == "totp" {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TOTP Code")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(theme.textSecondary)
                            TextField("6-digit code", text: $totpCode)
                                .keyboardType(.numberPad)
                                .padding(14)
                                .background(theme.backgroundCard)
                                .cornerRadius(12)
                                .foregroundColor(theme.textPrimary)
                        }
                    }
                }
                .padding(.horizontal, 24)

                if let authError {
                    Text(authError)
                        .font(.system(size: 13))
                        .foregroundColor(theme.danger)
                        .padding(.horizontal, 24)
                }

                Button {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    Task { await authenticate() }
                } label: {
                    HStack {
                        if isAuthenticating {
                            ProgressView().tint(.white).scaleEffect(0.8)
                        }
                        Text("Authenticate")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(canAuthenticate ? theme.accentLight : theme.accentLight.opacity(0.4))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!canAuthenticate || isAuthenticating)
                .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - Admin Content

    private var adminContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Stats
                statsSection

                // Pending Approvals
                approvalsSection

                // Invite Codes
                invitesSection

                // Announcements
                announcementsSection

                // User Management
                userManagementSection

                // Maintenance
                maintenanceSection
            }
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .refreshable {
            await loadAdminData()
        }
    }

    // MARK: - Approvals Section

    @State private var approvals: [PendingUserRead] = []
    @State private var isLoadingApprovals = false
    @State private var approvalToApprove: PendingUserRead?
    @State private var approvalToReject: PendingUserRead?

    private var approvalsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PENDING APPROVALS")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(theme.textSecondary)
                .textCase(.uppercase)
                .kerning(0.8)
                .padding(.horizontal, 24)

            if isLoadingApprovals {
                HStack { Spacer(); ProgressView().tint(theme.accentLight); Spacer() }
                    .padding(.vertical, 20)
            } else if approvals.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 28))
                            .foregroundColor(theme.success)
                        Text("No pending approvals")
                            .font(.system(size: 14))
                            .foregroundColor(theme.textSecondary)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(approvals) { user in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(user.email)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(theme.textPrimary)
                                    HStack(spacing: 8) {
                                        Text(user.createdAt, style: .date)
                                            .font(.system(size: 12))
                                            .foregroundColor(theme.textTertiary)
                                        if let ip = user.signupIp {
                                            Text(ip)
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundColor(theme.textTertiary)
                                        }
                                        if !user.emailVerified {
                                            Text("Unverified")
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundColor(theme.warning)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(theme.warning.opacity(0.12))
                                                .cornerRadius(4)
                                        }
                                    }
                                }
                                Spacer()
                            }
                            HStack(spacing: 10) {
                                Button {
                                    approvalToApprove = user
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("Approve")
                                    }
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(theme.success)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(theme.success.opacity(0.12))
                                    .cornerRadius(10)
                                }
                                Button {
                                    approvalToReject = user
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "xmark.circle.fill")
                                        Text("Reject")
                                    }
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(theme.danger)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(theme.danger.opacity(0.12))
                                    .cornerRadius(10)
                                }
                                Spacer()
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        if user.id != approvals.last?.id {
                            Divider().background(theme.divider).padding(.leading, 16)
                        }
                    }
                }
                .background(theme.backgroundCard)
                .cornerRadius(14)
                .padding(.horizontal, 24)
            }
        }
        .confirmationDialog("Approve this user?", isPresented: .init(
            get: { approvalToApprove != nil },
            set: { if !$0 { approvalToApprove = nil } }
        ), titleVisibility: .visible) {
            Button("Approve") {
                if let user = approvalToApprove {
                    Task { await performApproval(userID: user.id, approve: true) }
                }
            }
            Button("Cancel", role: .cancel) { approvalToApprove = nil }
        } message: {
            Text("This will activate the account for \(approvalToApprove?.email ?? "this user").")
        }
        .confirmationDialog("Reject this user?", isPresented: .init(
            get: { approvalToReject != nil },
            set: { if !$0 { approvalToReject = nil } }
        ), titleVisibility: .visible) {
            Button("Reject", role: .destructive) {
                if let user = approvalToReject {
                    Task { await performApproval(userID: user.id, approve: false) }
                }
            }
            Button("Cancel", role: .cancel) { approvalToReject = nil }
        } message: {
            Text("This will reject and delete the account for \(approvalToReject?.email ?? "this user").")
        }
    }

    private func loadApprovals() async {
        guard let api = store.api else { return }
        isLoadingApprovals = true
        approvals = (try? await api.getApprovals()) ?? []
        isLoadingApprovals = false
    }

    private func performApproval(userID: String, approve: Bool) async {
        guard let api = store.api else { return }
        do {
            if approve {
                try await api.approveUser(userID: userID)
            } else {
                try await api.rejectUser(userID: userID)
            }
            withAnimation {
                approvals.removeAll { $0.id == userID }
            }
        } catch {
            // Reload on error
            await loadApprovals()
        }
    }

    // MARK: - Invites Section

    @State private var invites: [InviteCodeRead] = []
    @State private var isLoadingInvites = false
    @State private var showCreateInvite = false
    @State private var inviteToDelete: InviteCodeRead?
    @State private var copiedInviteCode: String?

    private var invitesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("INVITE CODES")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.textSecondary)
                    .textCase(.uppercase)
                    .kerning(0.8)
                Spacer()
                Button {
                    showCreateInvite = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(theme.accentLight)
                }
            }
            .padding(.horizontal, 24)

            if isLoadingInvites {
                HStack { Spacer(); ProgressView().tint(theme.accentLight); Spacer() }
                    .padding(.vertical, 20)
            } else if invites.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "ticket")
                            .font(.system(size: 28))
                            .foregroundColor(theme.textTertiary)
                        Text("No invite codes")
                            .font(.system(size: 14))
                            .foregroundColor(theme.textSecondary)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(invites) { invite in
                        inviteRow(invite)

                        if invite.id != invites.last?.id {
                            Divider().background(theme.divider).padding(.leading, 16)
                        }
                    }
                }
                .background(theme.backgroundCard)
                .cornerRadius(14)
                .padding(.horizontal, 24)
            }
        }
        .sheet(isPresented: $showCreateInvite) {
            CreateInviteSheet { _ in
                Task { await loadInvites() }
            }
            .environmentObject(authManager)
            .environmentObject(store)
        }
        .confirmationDialog("Delete this invite code?", isPresented: .init(
            get: { inviteToDelete != nil },
            set: { if !$0 { inviteToDelete = nil } }
        ), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let invite = inviteToDelete {
                    Task { await deleteInvite(id: invite.id) }
                }
            }
            Button("Cancel", role: .cancel) { inviteToDelete = nil }
        } message: {
            Text("This invite code will be permanently deleted.")
        }
    }

    private func inviteRow(_ invite: InviteCodeRead) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(invite.code)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)

                Button {
                    UIPasteboard.general.string = invite.code
                    copiedInviteCode = invite.id
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        if copiedInviteCode == invite.id { copiedInviteCode = nil }
                    }
                } label: {
                    Image(systemName: copiedInviteCode == invite.id ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundColor(copiedInviteCode == invite.id ? theme.success : theme.textTertiary)
                }

                Spacer()

                // Status badge
                if invite.isExpired {
                    inviteBadge("Expired", color: theme.danger)
                } else if invite.isExhausted {
                    inviteBadge("Used up", color: theme.warning)
                } else {
                    inviteBadge("Active", color: theme.success)
                }
            }

            HStack(spacing: 12) {
                // Uses
                Label(invite.maxUses > 0 ? "\(invite.useCount)/\(invite.maxUses) uses" : "\(invite.useCount) uses",
                      systemImage: "person.2")
                    .font(.system(size: 11))
                    .foregroundColor(theme.textTertiary)

                // Expiry
                if let exp = invite.expiresAt {
                    if exp < Date() {
                        Label("Expired \(exp, style: .relative) ago", systemImage: "clock")
                            .font(.system(size: 11))
                            .foregroundColor(theme.danger)
                    } else {
                        Label("Expires \(exp, style: .relative)", systemImage: "clock")
                            .font(.system(size: 11))
                            .foregroundColor(theme.textTertiary)
                    }
                } else {
                    Label("No expiry", systemImage: "infinity")
                        .font(.system(size: 11))
                        .foregroundColor(theme.textTertiary)
                }

                Spacer()

                // Delete button
                Button { inviteToDelete = invite } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundColor(theme.danger.opacity(0.7))
                }
            }

            // Note
            if let note = invite.note, !note.isEmpty {
                Text(note)
                    .font(.system(size: 12))
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func inviteBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .cornerRadius(6)
    }

    private func loadInvites() async {
        guard let api = store.api else { return }
        isLoadingInvites = true
        invites = (try? await api.getInvites()) ?? []
        isLoadingInvites = false
    }

    private func deleteInvite(id: String) async {
        guard let api = store.api else { return }
        do {
            try await api.deleteInvite(id: id)
            withAnimation { invites.removeAll { $0.id == id } }
        } catch {
            await loadInvites()
        }
    }

    // MARK: - Announcements Section

    @State private var adminAnnouncements: [AnnouncementRead] = []
    @State private var isLoadingAnnouncements = false
    @State private var showCreateAnnouncement = false
    @State private var announcementToEdit: AnnouncementRead?
    @State private var announcementToDelete: AnnouncementRead?

    private var announcementsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ANNOUNCEMENTS")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.textSecondary)
                    .textCase(.uppercase)
                    .kerning(0.8)
                Spacer()
                Button {
                    showCreateAnnouncement = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(theme.accentLight)
                }
            }
            .padding(.horizontal, 24)

            if isLoadingAnnouncements {
                HStack { Spacer(); ProgressView().tint(theme.accentLight); Spacer() }
                    .padding(.vertical, 20)
            } else if adminAnnouncements.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "megaphone")
                            .font(.system(size: 28))
                            .foregroundColor(theme.textTertiary)
                        Text("No announcements")
                            .font(.system(size: 14))
                            .foregroundColor(theme.textSecondary)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(adminAnnouncements) { announcement in
                        Button {
                            announcementToEdit = announcement
                        } label: {
                            announcementRow(announcement)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                announcementToEdit = announcement
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                announcementToDelete = announcement
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }

                        if announcement.id != adminAnnouncements.last?.id {
                            Divider().background(theme.divider).padding(.leading, 16)
                        }
                    }
                }
                .background(theme.backgroundCard)
                .cornerRadius(14)
                .padding(.horizontal, 24)
            }
        }
        .sheet(isPresented: $showCreateAnnouncement) {
            AnnouncementEditSheet(announcement: nil) {
                Task { await loadAnnouncements() }
            }
            .environmentObject(authManager)
            .environmentObject(store)
        }
        .sheet(item: $announcementToEdit) { announcement in
            AnnouncementEditSheet(announcement: announcement) {
                Task { await loadAnnouncements() }
            }
            .environmentObject(authManager)
            .environmentObject(store)
        }
        .confirmationDialog("Delete this announcement?", isPresented: .init(
            get: { announcementToDelete != nil },
            set: { if !$0 { announcementToDelete = nil } }
        ), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let announcement = announcementToDelete {
                    Task { await deleteAnnouncement(id: announcement.id) }
                }
            }
            Button("Cancel", role: .cancel) { announcementToDelete = nil }
        } message: {
            Text("This announcement will be permanently deleted.")
        }
    }

    private func announcementRow(_ announcement: AnnouncementRead) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(announcement.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
                Spacer()
                severityBadge(announcement.severity)
            }
            HStack(spacing: 8) {
                if !announcement.active {
                    Text("Inactive")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(theme.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.textTertiary.opacity(0.12))
                        .cornerRadius(4)
                }
                if !announcement.dismissible {
                    Text("Persistent")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(theme.warning)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.warning.opacity(0.12))
                        .cornerRadius(4)
                }
                Text(announcement.createdAt, style: .date)
                    .font(.system(size: 12))
                    .foregroundColor(theme.textTertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func severityBadge(_ severity: AnnouncementSeverity) -> some View {
        let (text, color): (String, Color) = {
            switch severity {
            case .info:     return ("Info", theme.accentLight)
            case .warning:  return ("Warning", theme.warning)
            case .critical: return ("Critical", theme.danger)
            }
        }()
        return Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .cornerRadius(6)
    }

    private func loadAnnouncements() async {
        guard let api = store.api else { return }
        isLoadingAnnouncements = true
        adminAnnouncements = (try? await api.getAdminAnnouncements()) ?? []
        isLoadingAnnouncements = false
    }

    private func deleteAnnouncement(id: String) async {
        guard let api = store.api else { return }
        do {
            try await api.deleteAnnouncement(id: id)
            withAnimation { adminAnnouncements.removeAll { $0.id == id } }
        } catch {
            await loadAnnouncements()
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("STATISTICS")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(theme.textSecondary)
                .textCase(.uppercase)
                .kerning(0.8)
                .padding(.horizontal, 24)

            if let stats {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    adminStatCard(title: "Users", value: "\(stats.totalUsers)", icon: "person.2.fill")
                    adminStatCard(title: "Members", value: "\(stats.totalMembers)", icon: "person.fill")
                    adminStatCard(title: "Storage", value: formatBytes(stats.totalStorageBytes), icon: "externaldrive.fill")
                }
                .padding(.horizontal, 24)

                if !stats.usersByTier.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(stats.usersByTier.sorted(by: { $0.value > $1.value }), id: \.key) { tier, count in
                            HStack {
                                Text(formatTierLabel(tier))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(theme.textPrimary)
                                Spacer()
                                Text("\(count)")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(theme.textSecondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(theme.backgroundCard)
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal, 24)
                }
            } else if isLoadingStats {
                HStack { Spacer(); ProgressView().tint(theme.accentLight); Spacer() }
                    .padding(.vertical, 20)
            }
        }
    }

    private func adminStatCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(theme.accentLight)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(theme.textPrimary)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(theme.backgroundCard)
        .cornerRadius(14)
    }

    // MARK: - User Management Section

    private var userManagementSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("USERS")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(theme.textSecondary)
                .textCase(.uppercase)
                .kerning(0.8)
                .padding(.horizontal, 24)

            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(theme.textTertiary)
                    TextField("Search users...", text: $searchText)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .foregroundColor(theme.textPrimary)
                }
                .padding(12)
                .background(theme.backgroundCard)
                .cornerRadius(12)
                .padding(.horizontal, 24)
                .onChange(of: searchText) {
                    Task {
                        // Debounce: wait briefly then search
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        await loadUsers(reset: true)
                    }
                }

                if isLoadingUsers && users.isEmpty {
                    HStack { Spacer(); ProgressView().tint(theme.accentLight); Spacer() }
                        .padding(.vertical, 20)
                } else if users.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.slash.fill")
                            .font(.system(size: 32))
                            .foregroundColor(theme.textTertiary)
                        Text("No users found")
                            .font(.system(size: 15))
                            .foregroundColor(theme.textSecondary)
                    }
                    .padding(.vertical, 24)
                } else {
                    VStack(spacing: 0) {
                        ForEach(users) { user in
                            Button {
                                selectedUser = user
                            } label: {
                                adminUserRow(user)
                            }
                            .buttonStyle(.plain)

                            if user.id != users.last?.id {
                                Divider().background(theme.divider).padding(.leading, 24)
                            }
                        }

                        if hasMoreUsers {
                            Button {
                                Task { await loadUsers(reset: false) }
                            } label: {
                                HStack {
                                    if isLoadingUsers {
                                        ProgressView().tint(theme.accentLight).scaleEffect(0.8)
                                    }
                                    Text("Load More")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(theme.accentLight)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                            }
                        }
                    }
                    .background(theme.backgroundCard)
                    .cornerRadius(14)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                }
            }
        }
    }

    private func adminUserRow(_ user: AdminUserRead) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(user.email)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)
                    if user.isAdmin {
                        Text("Admin")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(theme.accentLight)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(theme.accentLight.opacity(0.15))
                            .cornerRadius(4)
                    }
                }
                HStack(spacing: 8) {
                    Text(formatAdminTier(user.tier))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.textTertiary)
                    Text("\(user.memberCount) members")
                        .font(.system(size: 12))
                        .foregroundColor(theme.textTertiary)
                    Text(formatBytes(user.storageUsedBytes))
                        .font(.system(size: 12))
                        .foregroundColor(theme.textTertiary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(theme.textTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Maintenance Section

    private var maintenanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MAINTENANCE")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(theme.textSecondary)
                .textCase(.uppercase)
                .kerning(0.8)
                .padding(.horizontal, 24)

            VStack(spacing: 0) {
                maintenanceButton(
                    icon: "clock.arrow.circlepath",
                    title: "Run Retention",
                    subtitle: "Remove expired data per retention policy"
                ) {
                    showRetentionConfirm = true
                }

                Divider().background(theme.divider).padding(.leading, 52)

                maintenanceButton(
                    icon: "trash.circle",
                    title: "Run Cleanup",
                    subtitle: "Clean up orphaned data and temp files"
                ) {
                    showCleanupConfirm = true
                }

                Divider().background(theme.divider).padding(.leading, 52)

                maintenanceButton(
                    icon: "externaldrive.badge.checkmark",
                    title: "Run Storage Audit",
                    subtitle: "Recalculate storage usage for all users"
                ) {
                    showAuditConfirm = true
                }

                Divider().background(theme.divider).padding(.leading, 52)

                maintenanceButton(
                    icon: "magnifyingglass",
                    title: "Check for Orphaned Files",
                    subtitle: "Preview what file cleanup would remove"
                ) {
                    Task { await runFileCleanupDryRun() }
                }

                Divider().background(theme.divider).padding(.leading, 52)

                maintenanceButton(
                    icon: "doc.badge.gearshape",
                    title: "Clean Up Orphaned Files",
                    subtitle: "Remove unreferenced uploaded files"
                ) {
                    showFileCleanupConfirm = true
                }
            }
            .background(theme.backgroundCard)
            .cornerRadius(14)
            .padding(.horizontal, 24)
        }
    }

    private func maintenanceButton(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(theme.warning)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(theme.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(theme.textTertiary)
                }
                Spacer()
                if isRunningMaintenance {
                    ProgressView().tint(theme.accentLight).scaleEffect(0.7)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .disabled(isRunningMaintenance)
    }

    // MARK: - Actions

    private func checkAdminAuth() async {
        guard let api = store.api else { return }
        isCheckingAuth = true
        do {
            let status = try await api.getAdminAuthStatus()
            authLevel = status.level
            totpEnabled = status.totpEnabled
            isAdminAuthed = status.verified || status.level == "none"
        } catch {
            // If the check itself fails (e.g. 403), assume step-up is needed
            isAdminAuthed = false
        }
        isCheckingAuth = false

        if isAdminAuthed {
            await loadAdminData()
        }
    }

    private func loadAdminData() async {
        await loadStats()
        await loadUsers(reset: true)
        await loadApprovals()
        await loadInvites()
        await loadAnnouncements()
    }

    private func authenticate() async {
        guard let api = store.api else { return }
        isAuthenticating = true
        authError = nil
        do {
            let verify = AdminStepUpVerify(
                password: password.isEmpty ? nil : password,
                totpCode: totpCode.isEmpty ? nil : totpCode
            )
            try await api.adminStepUp(verify)
            isAdminAuthed = true
            password = ""
            totpCode = ""
            await loadAdminData()
        } catch {
            authError = error.localizedDescription
        }
        isAuthenticating = false
    }

    /// Returns true (and resets to auth screen) if the error is a step-up expiry.
    private func handleStepUpExpiry(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.code == 403,
           nsError.localizedDescription.contains("admin_step_up_required") {
            isAdminAuthed = false
            authError = "Session expired. Please re-authenticate."
            return true
        }
        return false
    }

    private func loadStats() async {
        guard let api = store.api else { return }
        isLoadingStats = true
        do {
            stats = try await api.getAdminStats()
        } catch {
            if handleStepUpExpiry(error) { return }
        }
        isLoadingStats = false
    }

    private func loadUsers(reset: Bool) async {
        guard let api = store.api else { return }
        if reset { currentPage = 1 }
        isLoadingUsers = true
        let limit = 50
        do {
            let fetched = try await api.getAdminUsers(
                search: searchText.isEmpty ? nil : searchText,
                page: currentPage,
                limit: limit
            )
            if reset {
                users = fetched
            } else {
                users.append(contentsOf: fetched)
            }
            hasMoreUsers = fetched.count == limit
            if !reset { currentPage += 1 }
        } catch {
            if handleStepUpExpiry(error) { return }
        }
        isLoadingUsers = false
    }

    private enum MaintenanceAction {
        case retention, cleanup, storageStats
    }

    private func runMaintenance(_ action: MaintenanceAction) async {
        guard let api = store.api else { return }
        isRunningMaintenance = true
        do {
            switch action {
            case .retention:
                try await api.runRetention()
                maintenanceResult = "Retention completed successfully."
            case .cleanup:
                try await api.runCleanup()
                maintenanceResult = "Cleanup completed successfully."
            case .storageStats:
                let stats = try await api.getStorageStats()
                let summary = stats.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
                maintenanceResult = summary.isEmpty ? "No storage stats available." : summary
            }
        } catch {
            if handleStepUpExpiry(error) { return }
            maintenanceResult = "Error: \(error.localizedDescription)"
        }
        isRunningMaintenance = false
        showMaintenanceResult = true
    }

    // MARK: - File Cleanup

    private func runFileCleanupDryRun() async {
        guard let api = store.api else { return }
        isRunningMaintenance = true
        do {
            let result = try await api.cleanupFilesDryRun()
            let count = result["files_to_remove"] as? Int ?? result["count"] as? Int ?? 0
            fileCleanupResult = count > 0
                ? "\(count) orphaned file(s) found. Use 'Clean Up Orphaned Files' to remove them."
                : "No orphaned files found."
        } catch {
            if handleStepUpExpiry(error) { return }
            fileCleanupResult = "Error: \(error.localizedDescription)"
        }
        isRunningMaintenance = false
        showFileCleanupResult = true
    }

    private func runFileCleanup() async {
        guard let api = store.api else { return }
        isRunningMaintenance = true
        do {
            let result = try await api.cleanupFiles()
            let count = result["files_removed"] as? Int ?? result["count"] as? Int ?? 0
            fileCleanupResult = "Cleaned up \(count) file(s)."
        } catch {
            if handleStepUpExpiry(error) { return }
            fileCleanupResult = "Error: \(error.localizedDescription)"
        }
        isRunningMaintenance = false
        showFileCleanupResult = true
    }

    // MARK: - Helpers

    private func formatTierLabel(_ tier: String) -> String {
        switch tier {
        case "free": return "Free"
        case "plus": return "Plus"
        case "self_hosted": return "Self-Hosted"
        default: return tier.capitalized
        }
    }

    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private func formatAdminTier(_ tier: UserTier) -> String {
        switch tier {
        case .free: return "Free"
        case .plus: return "Plus"
        case .selfHosted: return "Self-Hosted"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - Admin User Edit Sheet
struct AdminUserEditSheet: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var store: SystemStore
    @Environment(\.dismiss) var dismiss

    let user: AdminUserRead
    let onSave: (AdminUserRead) -> Void

    @State private var selectedTier: UserTier
    @State private var isAdmin: Bool
    @State private var memberLimitText: String
    @State private var isSaving = false
    @State private var error: String?
    @State private var recoveryMessage: String?
    @State private var isRecoveryError = false
    @State private var showResetPassword = false
    @State private var newPassword = ""
    @State private var showChangeEmail = false
    @State private var newEmail = ""
    @State private var showDisableTOTP = false
    @State private var showVerifyEmail = false
    @State private var showCancelDeletion = false

    init(user: AdminUserRead, onSave: @escaping (AdminUserRead) -> Void) {
        self.user = user
        self.onSave = onSave
        _selectedTier = State(initialValue: user.tier)
        _isAdmin = State(initialValue: user.isAdmin)
        _memberLimitText = State(initialValue: user.memberLimit.map { "\($0)" } ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        userInfoSection
                        editableFieldsSection
                        recoveryToolsSection

                        if let recoveryMessage {
                            Text(recoveryMessage)
                                .font(.system(size: 13))
                                .foregroundColor(isRecoveryError ? theme.danger : theme.success)
                        }

                        if let error {
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundColor(theme.danger)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(user.email)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(theme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView().tint(theme.accentLight).scaleEffect(0.8)
                        } else {
                            Text("Save")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(theme.accentLight)
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .alert("Reset Password", isPresented: $showResetPassword) {
                SecureField("New password (optional)", text: $newPassword)
                Button("Reset", role: .destructive) {
                    Task { await adminResetPassword() }
                }
                Button("Cancel", role: .cancel) { newPassword = "" }
            } message: {
                Text("Enter a new password, or leave blank to send a password reset email to the user.")
            }
            .alert("Change Email", isPresented: $showChangeEmail) {
                TextField("New email address", text: $newEmail)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                Button("Change", role: .destructive) {
                    Task { await adminChangeEmail() }
                }
                Button("Cancel", role: .cancel) { newEmail = "" }
            } message: {
                Text("Enter the new email address for this user.")
            }
            .confirmationDialog("Disable 2FA?", isPresented: $showDisableTOTP, titleVisibility: .visible) {
                Button("Disable 2FA", role: .destructive) {
                    Task { await adminDisableTOTP() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove two-factor authentication from this user's account. They can set it up again later.")
            }
            .confirmationDialog("Verify Email?", isPresented: $showVerifyEmail, titleVisibility: .visible) {
                Button("Mark as Verified") {
                    Task { await adminVerifyEmail() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will manually mark this user's email as verified.")
            }
            .confirmationDialog("Cancel Account Deletion?", isPresented: $showCancelDeletion, titleVisibility: .visible) {
                Button("Cancel Deletion") {
                    Task { await adminCancelDeletion() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will cancel the pending account deletion for this user.")
            }
        }
    }

    private var userInfoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("USER INFO")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(theme.textSecondary)
                .textCase(.uppercase)
                .kerning(0.8)

            VStack(spacing: 0) {
                infoRow(label: "Email", value: user.email)
                Divider().background(theme.divider)
                infoRow(label: "Members", value: "\(user.memberCount)")
                Divider().background(theme.divider)
                infoRow(label: "Storage", value: formatBytes(user.storageUsedBytes))
                Divider().background(theme.divider)
                infoRow(label: "Created", value: user.createdAt.formatted(date: .abbreviated, time: .shortened))
                if let lastLogin = user.lastLoginAt {
                    Divider().background(theme.divider)
                    infoRow(label: "Last Login", value: lastLogin.formatted(date: .abbreviated, time: .shortened))
                }
            }
            .background(theme.backgroundCard)
            .cornerRadius(14)
        }
    }

    private var editableFieldsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SETTINGS")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(theme.textSecondary)
                .textCase(.uppercase)
                .kerning(0.8)

            VStack(spacing: 0) {
                HStack {
                    Text("Tier")
                        .font(.system(size: 15))
                        .foregroundColor(theme.textPrimary)
                    Spacer()
                    Picker("Tier", selection: $selectedTier) {
                        Text("Free").tag(UserTier.free)
                        Text("Plus").tag(UserTier.plus)
                        Text("Self-Hosted").tag(UserTier.selfHosted)
                    }
                    .tint(theme.accentLight)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider().background(theme.divider)

                Toggle(isOn: $isAdmin) {
                    Text("Administrator")
                        .font(.system(size: 15))
                        .foregroundColor(theme.textPrimary)
                }
                .tint(theme.accentLight)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider().background(theme.divider)

                HStack {
                    Text("Member Limit")
                        .font(.system(size: 15))
                        .foregroundColor(theme.textPrimary)
                    Spacer()
                    TextField("Default", text: $memberLimitText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .foregroundColor(theme.textPrimary)
                    if !memberLimitText.isEmpty {
                        Button {
                            memberLimitText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(theme.textTertiary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(theme.backgroundCard)
            .cornerRadius(14)
        }
    }

    private var recoveryToolsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RECOVERY TOOLS")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(theme.textSecondary)
                .textCase(.uppercase)
                .kerning(0.8)

            VStack(spacing: 0) {
                recoveryButton(
                    icon: "key.fill",
                    title: "Reset Password",
                    desc: "Set a new password for this user"
                ) { showResetPassword = true }

                Divider().background(theme.divider)

                recoveryButton(
                    icon: "envelope.fill",
                    title: "Change Email",
                    desc: "Update this user's email address"
                ) { showChangeEmail = true }

                if !user.emailVerified {
                    Divider().background(theme.divider)

                    recoveryButton(
                        icon: "checkmark.seal.fill",
                        title: "Verify Email",
                        desc: "Manually mark email as verified"
                    ) { showVerifyEmail = true }
                }

                Divider().background(theme.divider)

                recoveryButton(
                    icon: "lock.open.fill",
                    title: "Disable 2FA",
                    desc: "Remove two-factor authentication"
                ) { showDisableTOTP = true }

                if user.accountStatus == .pendingDeletion {
                    Divider().background(theme.divider)

                    recoveryButton(
                        icon: "arrow.uturn.backward.circle.fill",
                        title: "Cancel Account Deletion",
                        desc: "Remove pending deletion from this account"
                    ) { showCancelDeletion = true }
                }
            }
            .background(theme.backgroundCard)
            .cornerRadius(14)
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(theme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(theme.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private func save() async {
        guard let api = store.api else { return }
        isSaving = true
        error = nil

        let memberLimit = Int(memberLimitText)
        let clearLimit = memberLimitText.isEmpty && user.memberLimit != nil

        let update = AdminUserUpdate(
            tier: selectedTier != user.tier ? selectedTier : nil,
            isAdmin: isAdmin != user.isAdmin ? isAdmin : nil,
            memberLimit: memberLimit,
            clearMemberLimit: clearLimit ? true : nil
        )

        do {
            let updated = try await api.updateAdminUser(userID: user.id, update: update)
            onSave(updated)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }

    private func recoveryButton(icon: String, title: String, desc: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(theme.danger)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(theme.textPrimary)
                    Text(desc)
                        .font(.system(size: 12))
                        .foregroundColor(theme.textTertiary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private func setRecoveryMessage(_ msg: String, isError: Bool = false) {
        recoveryMessage = msg
        isRecoveryError = isError
    }

    private func adminResetPassword() async {
        guard let api = store.api else { return }
        do {
            try await api.adminResetPassword(userID: user.id, newPassword: newPassword.isEmpty ? nil : newPassword)
            setRecoveryMessage(newPassword.isEmpty ? "Password reset email sent." : "Password has been reset.")
            newPassword = ""
        } catch {
            setRecoveryMessage(error.localizedDescription, isError: true)
        }
    }

    private func adminChangeEmail() async {
        guard let api = store.api else { return }
        let email = newEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else { return }
        do {
            try await api.adminChangeEmail(userID: user.id, newEmail: email)
            setRecoveryMessage("Email changed to \(email).")
            newEmail = ""
        } catch {
            setRecoveryMessage(error.localizedDescription, isError: true)
        }
    }

    private func adminDisableTOTP() async {
        guard let api = store.api else { return }
        do {
            try await api.adminDisableTOTP(userID: user.id)
            setRecoveryMessage("Two-factor authentication has been disabled.")
        } catch {
            setRecoveryMessage(error.localizedDescription, isError: true)
        }
    }

    private func adminVerifyEmail() async {
        guard let api = store.api else { return }
        do {
            try await api.adminVerifyEmail(userID: user.id)
            setRecoveryMessage("Email has been marked as verified.")
        } catch {
            setRecoveryMessage(error.localizedDescription, isError: true)
        }
    }

    private func adminCancelDeletion() async {
        guard let api = store.api else { return }
        do {
            try await api.adminCancelDeletion(userID: user.id)
            setRecoveryMessage("Account deletion has been cancelled.")
        } catch {
            setRecoveryMessage(error.localizedDescription, isError: true)
        }
    }
}

// MARK: - Create Invite Sheet
struct CreateInviteSheet: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var store: SystemStore
    @Environment(\.dismiss) var dismiss

    let onCreate: (InviteCodeRead) -> Void

    @State private var note = ""
    @State private var maxUsesText = ""
    @State private var hasExpiry = false
    @State private var expiresAt = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var isCreating = false
    @State private var error: String?
    @State private var createdInvite: InviteCodeRead?
    @State private var copiedCode = false

    var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        if let invite = createdInvite {
                            createdView(invite)
                        } else {
                            formView
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(createdInvite != nil ? "Invite Created" : "New Invite Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(createdInvite != nil ? "Done" : "Cancel") {
                        if let invite = createdInvite {
                            onCreate(invite)
                        }
                        dismiss()
                    }
                    .foregroundColor(theme.textSecondary)
                }
                if createdInvite == nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            Task { await create() }
                        } label: {
                            if isCreating {
                                ProgressView().tint(theme.accentLight).scaleEffect(0.8)
                            } else {
                                Text("Create")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(theme.accentLight)
                            }
                        }
                        .disabled(isCreating)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var formView: some View {
        VStack(spacing: 16) {
            // Note
            VStack(alignment: .leading, spacing: 6) {
                Text("Note")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.textSecondary)
                TextField("Optional description", text: $note)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(theme.backgroundCard)
                    .cornerRadius(12)
                    .foregroundColor(theme.textPrimary)
            }

            // Max uses
            VStack(alignment: .leading, spacing: 6) {
                Text("Max Uses")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.textSecondary)
                HStack {
                    TextField("Unlimited", text: $maxUsesText)
                        .keyboardType(.numberPad)
                        .padding(12)
                        .background(theme.backgroundCard)
                        .cornerRadius(12)
                        .foregroundColor(theme.textPrimary)
                }
                Text("Leave empty for unlimited uses")
                    .font(.system(size: 11))
                    .foregroundColor(theme.textTertiary)
            }

            // Expiry
            VStack(alignment: .leading, spacing: 6) {
                Toggle(isOn: $hasExpiry) {
                    Text("Expires")
                        .font(.system(size: 15))
                        .foregroundColor(theme.textPrimary)
                }
                .tint(theme.accentLight)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(theme.backgroundCard)
                .cornerRadius(12)

                if hasExpiry {
                    DatePicker("Expiry Date", selection: $expiresAt, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                        .tint(theme.accentLight)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(theme.backgroundCard)
                        .cornerRadius(12)
                        .foregroundColor(theme.textPrimary)
                }
            }

            if let error {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundColor(theme.danger)
            }
        }
    }

    private func createdView(_ invite: InviteCodeRead) -> some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(theme.success.opacity(0.15))
                    .frame(width: 72, height: 72)
                Image(systemName: "ticket.fill")
                    .font(.system(size: 32))
                    .foregroundColor(theme.success)
            }
            .shadow(color: theme.success.opacity(0.3), radius: 16)

            Text("Invite Code Created")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(theme.textPrimary)

            // Code display
            VStack(spacing: 8) {
                Text(invite.code)
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundColor(theme.textPrimary)
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(theme.backgroundCard)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.border, lineWidth: 1))

                Button {
                    UIPasteboard.general.string = invite.code
                    copiedCode = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedCode = false }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: copiedCode ? "checkmark" : "doc.on.doc")
                        Text(copiedCode ? "Copied!" : "Copy Code")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(copiedCode ? theme.success : theme.accentLight)
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(theme.backgroundCard)
                    .cornerRadius(12)
                }
            }

            // Details
            VStack(spacing: 0) {
                if invite.maxUses > 0 {
                    HStack {
                        Text("Max Uses")
                            .font(.system(size: 14))
                            .foregroundColor(theme.textSecondary)
                        Spacer()
                        Text("\(invite.maxUses)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(theme.textPrimary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    Divider().background(theme.divider)
                }
                if let exp = invite.expiresAt {
                    HStack {
                        Text("Expires")
                            .font(.system(size: 14))
                            .foregroundColor(theme.textSecondary)
                        Spacer()
                        Text(exp, style: .date)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(theme.textPrimary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }
            .background(theme.backgroundCard)
            .cornerRadius(12)
        }
    }

    private func create() async {
        guard let api = store.api else { return }
        isCreating = true
        error = nil

        let create = InviteCodeCreate(
            maxUses: Int(maxUsesText),
            note: note.isEmpty ? nil : note,
            expiresAt: hasExpiry ? expiresAt : nil
        )

        do {
            let invite = try await api.createInvite(create)
            await MainActor.run {
                createdInvite = invite
                isCreating = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isCreating = false
            }
        }
    }
}
