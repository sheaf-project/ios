import SwiftUI

// MARK: - SettingsView
struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var store: SystemStore
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.theme) var theme
    @State private var showLogoutConfirm = false
    @State private var showEditSystem = false
    @State private var showImport = false
    @State private var showSheafImport = false
    @State private var showTOTPSetup = false
    @State private var showTOTPManage = false
    @State private var me: UserRead?
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var showExportSuccess = false
    @State private var deleteConfirmLevel: DeleteConfirmation = .none
    @State private var showDeleteConfirmSheet = false
    @State private var isLoadingFileUsage = false
    @State private var fileUsageDisplay = "—"
    @State private var showFileCleanupConfirm = false
    @State private var fileCleanupResult: String?
    @State private var showFileCleanupResult = false
    @State private var isRunningFileCleanup = false
    @State private var showDeleteAccount = false
    @State private var showCancelDeletion = false
    @State private var isCancellingDeletion = false
    @State private var newsletterOptIn = false

    var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        Text("Settings")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)

                    // Pending deletion banner
                    if let me, let deletionDate = me.deletionRequestedAt {
                        settingsSection(title: "") {
                            VStack(spacing: 12) {
                                HStack(spacing: 10) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(theme.danger)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Account Deletion Pending")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(theme.danger)
                                        if let days = authManager.deletionGraceDays {
                                            let deletionDate2 = Calendar.current.date(byAdding: .day, value: days, to: deletionDate) ?? deletionDate
                                            if deletionDate2 > Date() {
                                                Text("Your account will be permanently deleted in \(deletionDate2, style: .relative).")
                                                    .font(.system(size: 13))
                                                    .foregroundColor(theme.textSecondary)
                                            }
                                        } else {
                                            Text("Requested \(deletionDate, style: .relative) ago")
                                                .font(.system(size: 13))
                                                .foregroundColor(theme.textSecondary)
                                        }
                                    }
                                    Spacer()
                                }

                                Button {
                                    showCancelDeletion = true
                                } label: {
                                    HStack {
                                        if isCancellingDeletion {
                                            ProgressView().tint(.white)
                                        }
                                        Text("Cancel Deletion")
                                            .font(.system(size: 15, weight: .medium))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(theme.accentLight)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                            }
                            .padding(16)
                        }
                    }

                    // Connection
                    settingsSection(title: String(localized: "Connection")) {
                        VStack(spacing: 0) {
                            infoRow(icon: "link", label: String(localized: "API URL"), value: authManager.baseURL)
                            Divider().background(theme.backgroundCard)
                            infoRow(icon: "envelope.fill", label: String(localized: "Email"), value: me?.email ?? "—")
                        }
                    }

                    // Appearance
                    settingsSection(title: String(localized: "Appearance")) {
                        VStack(spacing: 0) {
                            ForEach(ThemeMode.allCases, id: \.self) { mode in
                                Button { themeManager.mode = mode; store.saveClientSettings() } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: mode.icon)
                                            .foregroundColor(themeManager.mode == mode ? theme.accentLight : theme.textTertiary)
                                            .frame(width: 20)
                                        Text(mode.label)
                                            .font(.system(size: 15))
                                            .foregroundColor(theme.textPrimary)
                                        Spacer()
                                        if themeManager.mode == mode {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(theme.accentLight)
                                        }
                                    }
                                    .padding(.horizontal, 16).padding(.vertical, 14)
                                }
                                if mode != ThemeMode.allCases.last {
                                    Divider().background(theme.divider).padding(.leading, 52)
                                }
                            }
                        }
                    }

                    // Security
                    settingsSection(title: String(localized: "Security")) {
                        VStack(spacing: 0) {
                            // TOTP status row
                            HStack(spacing: 12) {
                                Image(systemName: "lock.shield.fill")
                                    .foregroundColor(me?.totpEnabled == true
                                        ? theme.success
                                        : theme.textTertiary)
                                    .frame(width: 20)
                                Text("Two-Factor Auth")
                                    .font(.system(size: 15))
                                    .foregroundColor(theme.textSecondary)
                                Spacer()
                                if let me {
                                    Text(me.totpEnabled ? String(localized: "Enabled") : String(localized: "Disabled"))
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(me.totpEnabled
                                            ? theme.success
                                            : theme.textTertiary)
                                } else {
                                    ProgressView().tint(theme.accentLight).scaleEffect(0.7)
                                }
                            }
                            .padding(.horizontal, 16).padding(.vertical, 14)

                            Divider().background(theme.backgroundCard)

                            // Setup / manage button
                            if me?.totpEnabled == true {
                                Button { showTOTPManage = true } label: {
                                    HStack {
                                        Image(systemName: "gearshape.fill")
                                            .foregroundColor(theme.accentLight)
                                        Text("Manage Two-Factor Auth")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(theme.accentLight)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12))
                                            .foregroundColor(theme.textTertiary)
                                    }
                                    .padding(.horizontal, 16).padding(.vertical, 14)
                                }
                            } else {
                                Button { showTOTPSetup = true } label: {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(theme.accentLight)
                                        Text("Set Up Two-Factor Auth")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(theme.accentLight)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12))
                                            .foregroundColor(theme.textTertiary)
                                    }
                                    .padding(.horizontal, 16).padding(.vertical, 14)
                                }
                            }

                            Divider().background(theme.backgroundCard)

                            // Delete confirmation level
                            Button { showDeleteConfirmSheet = true } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "trash.slash.fill")
                                        .foregroundColor(theme.accentLight)
                                        .frame(width: 20)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Delete Confirmation")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(theme.textPrimary)
                                        Text(deleteConfirmLabel)
                                            .font(.system(size: 12))
                                            .foregroundColor(theme.textTertiary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundColor(theme.textTertiary)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 14)
                            }
                        }
                    }

                    // Files
                    settingsSection(title: "Files") {
                        VStack(spacing: 0) {
                            // Storage usage
                            HStack(spacing: 12) {
                                Image(systemName: "externaldrive.fill")
                                    .foregroundColor(theme.accentLight)
                                    .frame(width: 20)
                                Text("Storage Used")
                                    .font(.system(size: 15))
                                    .foregroundColor(theme.textSecondary)
                                Spacer()
                                if isLoadingFileUsage {
                                    ProgressView().tint(theme.accentLight).scaleEffect(0.7)
                                } else {
                                    Text(fileUsageDisplay)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(theme.textPrimary)
                                }
                            }
                            .padding(.horizontal, 16).padding(.vertical, 14)

                            Divider().background(theme.divider)

                            Button {
                                Task { await checkOrphanedFiles() }
                            } label: {
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(theme.accentLight)
                                        .frame(width: 20)
                                    Text("Check for Orphaned Files")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(theme.textPrimary)
                                    Spacer()
                                    if isRunningFileCleanup {
                                        ProgressView().tint(theme.accentLight).scaleEffect(0.7)
                                    }
                                }
                                .padding(.horizontal, 16).padding(.vertical, 14)
                            }
                            .disabled(isRunningFileCleanup)

                            Divider().background(theme.divider)

                            Button {
                                showFileCleanupConfirm = true
                            } label: {
                                HStack {
                                    Image(systemName: "doc.badge.gearshape")
                                        .foregroundColor(theme.accentLight)
                                        .frame(width: 20)
                                    Text("Clean Up Orphaned Files")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(theme.textPrimary)
                                    Spacer()
                                }
                                .padding(.horizontal, 16).padding(.vertical, 14)
                            }
                            .disabled(isRunningFileCleanup)
                        }
                    }

                    // Data Management
                    settingsSection(title: "Data Management") {
                        VStack(spacing: 0) {
                            // Import from Simply Plural
                            Button { showImport = true } label: {
                                HStack {
                                    Image(systemName: "square.and.arrow.down.fill")
                                        .foregroundColor(theme.accentLight)
                                        .frame(width: 20)
                                    Text("Import from Simply Plural")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(theme.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundColor(theme.textTertiary)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 14)
                            }

                            Divider().background(theme.divider)

                            // Import from Sheaf
                            Button { showSheafImport = true } label: {
                                HStack {
                                    Image(systemName: "square.and.arrow.down.on.square.fill")
                                        .foregroundColor(theme.accentLight)
                                        .frame(width: 20)
                                    Text("Import from Sheaf Export")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(theme.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundColor(theme.textTertiary)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 14)
                            }

                            Divider().background(theme.divider)
                            
                            // Export
                            Button { 
                                Task { await exportData() }
                            } label: {
                                HStack {
                                    Image(systemName: "square.and.arrow.up.fill")
                                        .foregroundColor(theme.accentLight)
                                        .frame(width: 20)
                                    Text("Export All Data")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(theme.textPrimary)
                                    Spacer()
                                    if isExporting {
                                        ProgressView()
                                            .tint(theme.accentLight)
                                            .scaleEffect(0.8)
                                    }
                                }
                                .padding(.horizontal, 16).padding(.vertical, 14)
                            }
                            .disabled(isExporting)
                        }
                    }

                    // Data
                    settingsSection(title: "Data") {
                        VStack(spacing: 0) {
                            NavigationLink {
                                CustomFieldsView()
                                    .environmentObject(store)
                            } label: {
                                HStack {
                                    Image(systemName: "list.bullet.rectangle")
                                        .foregroundColor(theme.accentLight)
                                        .frame(width: 20)
                                    Text("Custom Fields")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(theme.textPrimary)
                                    Spacer()
                                    Text("\(store.fields.count)")
                                        .font(.system(size: 14))
                                        .foregroundColor(theme.textTertiary)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 14)
                            }
                            .buttonStyle(.plain)

                            Divider().background(theme.divider)

                            Button { store.loadAll() } label: {
                                HStack {
                                    Image(systemName: "arrow.clockwise").foregroundColor(theme.accent)
                                    Text("Refresh All Data")
                                        .font(.system(size: 15, weight: .medium)).foregroundColor(theme.textPrimary)
                                    Spacer()
                                    if store.isLoading { ProgressView().tint(theme.accentLight) }
                                }
                                .padding(.horizontal, 16).padding(.vertical, 14)
                            }
                        }
                    }

                    // System info
                    settingsSection(title: "System") {
                        VStack(spacing: 0) {
                            if let profile = store.systemProfile {
                                HStack(spacing: 12) {
                                    ZStack {
                                    Circle()
                                        .fill(Color(hex: profile.color ?? "#8B5CF6") ?? .purple)
                                        .frame(width: 44, height: 44)
                                    if let imageURL = resolveAvatarURL(profile.avatarURL, baseURL: authManager.baseURL) {
                                        AsyncImage(url: imageURL) { img in
                                            img.resizable().scaledToFill()
                                                .frame(width: 44, height: 44)
                                                .clipShape(Circle())
                                        } placeholder: { EmptyView() }
                                    } else {
                                        Text(String(profile.name.prefix(1)).uppercased())
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(profile.name)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(theme.textPrimary)
                                        if let tag = profile.tag, !tag.isEmpty {
                                            Text(tag)
                                                .font(.system(size: 12))
                                                .foregroundColor(theme.textSecondary)
                                        }
                                    }
                                    Spacer()
                                    Button {
                                        showEditSystem = true
                                    } label: {
                                        Text("Edit")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(theme.accentLight)
                                    }
                                }
                                .padding(.horizontal, 16).padding(.vertical, 14)
                                Divider().background(theme.divider)
                            }
                            statRow(label: "Members",            value: "\(store.members.count)")
                            Divider().background(theme.backgroundCard)
                            statRow(label: "Groups",             value: "\(store.groups.count)")
                            Divider().background(theme.backgroundCard)
                            statRow(label: "Currently Fronting", value: "\(store.frontingMembers.count)")
                        }
                    }

                    // API Keys
                    settingsSection(title: String(localized: "API Keys")) {
                        VStack(spacing: 0) {
                            NavigationLink {
                                ApiKeysView()
                                    .environmentObject(authManager)
                                    .environmentObject(store)
                            } label: {
                                HStack {
                                    Image(systemName: "key.horizontal.fill")
                                        .foregroundColor(theme.accentLight)
                                        .frame(width: 20)
                                    Text("Manage API Keys")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(theme.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundColor(theme.textTertiary)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 14)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Sessions
                    settingsSection(title: "Sessions") {
                        VStack(spacing: 0) {
                            NavigationLink {
                                SessionsView()
                                    .environmentObject(authManager)
                                    .environmentObject(store)
                            } label: {
                                HStack {
                                    Image(systemName: "desktopcomputer")
                                        .foregroundColor(theme.accentLight)
                                        .frame(width: 20)
                                    Text("Manage Sessions")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(theme.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundColor(theme.textTertiary)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 14)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Administration (admin only)
                    if me?.isAdmin == true {
                        settingsSection(title: "Administration") {
                            VStack(spacing: 0) {
                                NavigationLink {
                                    AdminPanelView()
                                        .environmentObject(authManager)
                                        .environmentObject(store)
                                } label: {
                                    HStack {
                                        Image(systemName: "shield.lefthalf.filled")
                                            .foregroundColor(theme.accentLight)
                                            .frame(width: 20)
                                        Text("Admin Panel")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(theme.textPrimary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12))
                                            .foregroundColor(theme.textTertiary)
                                    }
                                    .padding(.horizontal, 16).padding(.vertical, 14)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Account
                    settingsSection(title: "Account") {
                        VStack(spacing: 0) {
                            if let me {
                                // User tier
                                HStack(spacing: 12) {
                                    Image(systemName: "person.crop.circle.fill")
                                        .foregroundColor(theme.accentLight)
                                        .frame(width: 20)
                                    Text("Tier")
                                        .font(.system(size: 15))
                                        .foregroundColor(theme.textSecondary)
                                    Spacer()
                                    Text(formatTier(me.tier))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(theme.accentLight)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(theme.accentLight.opacity(0.12))
                                        .cornerRadius(8)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 14)

                                Divider().background(theme.divider)

                                // Newsletter opt-in
                                HStack(spacing: 12) {
                                    Image(systemName: "envelope.fill")
                                        .foregroundColor(theme.accentLight)
                                        .frame(width: 20)
                                    Text("Newsletter")
                                        .font(.system(size: 15))
                                        .foregroundColor(theme.textSecondary)
                                    Spacer()
                                    Toggle("", isOn: $newsletterOptIn)
                                        .labelsHidden()
                                        .tint(theme.accentLight)
                                        .onChange(of: newsletterOptIn) {
                                            Task { await updateNewsletterOptIn(newsletterOptIn) }
                                        }
                                }
                                .padding(.horizontal, 16).padding(.vertical, 14)

                                Divider().background(theme.divider)
                            }

                            if me?.accountStatus != .pendingDeletion {
                                Button { showDeleteAccount = true } label: {
                                    HStack {
                                        Image(systemName: "trash.fill")
                                            .foregroundColor(theme.danger)
                                        Text("Delete Account")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(theme.danger)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16).padding(.vertical, 14)
                                }

                                Divider().background(theme.divider)
                            }

                            Button { showLogoutConfirm = true } label: {
                                HStack {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .foregroundColor(theme.danger)
                                    Text("Disconnect & Log Out")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(theme.danger)
                                    Spacer()
                                }
                                .padding(.horizontal, 16).padding(.vertical, 14)
                            }
                        }
                    }

                    VStack(spacing: 4) {
                        Text("Sheaf").font(.system(size: 13, weight: .semibold)).foregroundColor(theme.textTertiary)
                        Text("v1.0.0").font(.system(size: 12)).foregroundColor(theme.textTertiary)
                    }
                    .padding(.bottom, 80)
                }
            }
            .refreshable {
                store.loadAll()
                await loadMe()
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
        .sheet(isPresented: $showEditSystem) {
            EditSystemProfileSheet()
                .environmentObject(store)
        }
        .task { await loadMe() }
        .confirmationDialog("Log out?", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
            Button("Disconnect", role: .destructive) { authManager.logout() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll need to enter your API URL and email again.")
        }
        .sheet(isPresented: $showImport) {
            SimplyPluralImportSheet()
                .environmentObject(store)
        }
        .sheet(isPresented: $showSheafImport) {
            SheafImportSheet()
                .environmentObject(store)
        }
        .sheet(isPresented: $showTOTPSetup, onDismiss: { Task { await loadMe() } }) {
            TOTPSetupSheet()
                .environmentObject(authManager)
        }
        .sheet(isPresented: $showTOTPManage, onDismiss: { Task { await loadMe() } }) {
            TOTPManageSheet()
                .environmentObject(authManager)
                .environmentObject(store)
        }
        .sheet(isPresented: $showDeleteConfirmSheet, onDismiss: { Task { await loadMe() } }) {
            DeleteConfirmationSheet(currentLevel: deleteConfirmLevel, totpEnabled: me?.totpEnabled == true) { newLevel in
                deleteConfirmLevel = newLevel
            }
            .environmentObject(authManager)
            .environmentObject(store)
        }
        .alert("Export Successful", isPresented: $showExportSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your data has been saved to Files.")
        }
        .alert("Export Failed", isPresented: .constant(exportError != nil)) {
            Button("OK", role: .cancel) {
                exportError = nil
            }
        } message: {
            Text(exportError ?? "An unknown error occurred.")
        }
        .sheet(isPresented: $showDeleteAccount, onDismiss: { Task { await loadMe() } }) {
            DeleteAccountSheet()
                .environmentObject(authManager)
                .environmentObject(store)
        }
        .confirmationDialog("Cancel Account Deletion?", isPresented: $showCancelDeletion, titleVisibility: .visible) {
            Button("Keep My Account") {
                Task {
                    guard let api = store.api else { return }
                    isCancellingDeletion = true
                    do {
                        try await api.cancelDeletion()
                        await loadMe()
                    } catch {}
                    isCancellingDeletion = false
                }
            }
            Button("Never Mind", role: .cancel) {}
        } message: {
            Text("This will cancel your pending account deletion request.")
        }
        .confirmationDialog("Clean Up Orphaned Files?", isPresented: $showFileCleanupConfirm, titleVisibility: .visible) {
            Button("Clean Up", role: .destructive) { Task { await cleanUpOrphanedFiles() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove orphaned files that are no longer referenced by any member or system profile.")
        }
        .alert("File Cleanup", isPresented: $showFileCleanupResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(fileCleanupResult ?? "")
        }
        } // NavigationStack
    }

    private func loadMe() async {
        guard let api = store.api else { return }
        me = try? await api.getMe()
        if let me {
            newsletterOptIn = me.newsletterOptIn
        }
        // Load delete confirmation level from system profile
        if let profile = store.systemProfile {
            deleteConfirmLevel = profile.deleteConfirmation
        } else if let profile = try? await api.getMySystem() {
            deleteConfirmLevel = profile.deleteConfirmation
        }
        // Fetch deletion grace period if not already known
        if authManager.deletionGraceDays == nil {
            if let config = try? await api.getAuthConfig(),
               let days = config["account_deletion_grace_days"] as? Int {
                authManager.deletionGraceDays = days
            }
        }
        // Load file usage
        await loadFileUsage()
    }

    private func updateNewsletterOptIn(_ value: Bool) async {
        guard let api = store.api else { return }
        let update = UserUpdate(newsletterOptIn: value)
        if let updated = try? await api.updateMe(update) {
            me = updated
        }
    }

    private func loadFileUsage() async {
        guard let api = store.api else { return }
        isLoadingFileUsage = true
        if let usage = try? await api.getFileUsage() {
            let bytes = usage["total_bytes"] as? Int ?? usage["used_bytes"] as? Int ?? 0
            let count = usage["total_files"] as? Int ?? usage["file_count"] as? Int ?? 0
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            fileUsageDisplay = "\(formatter.string(fromByteCount: Int64(bytes))) (\(count) files)"
        }
        isLoadingFileUsage = false
    }

    private func checkOrphanedFiles() async {
        guard let api = store.api else { return }
        isRunningFileCleanup = true
        do {
            let result = try await api.cleanupFilesDryRun()
            let count = result["files_to_remove"] as? Int ?? result["count"] as? Int ?? 0
            fileCleanupResult = count > 0
                ? "\(count) orphaned file(s) found. Use 'Clean Up Orphaned Files' to remove them."
                : "No orphaned files found."
        } catch {
            fileCleanupResult = "Error: \(error.localizedDescription)"
        }
        isRunningFileCleanup = false
        showFileCleanupResult = true
    }

    private func cleanUpOrphanedFiles() async {
        guard let api = store.api else { return }
        isRunningFileCleanup = true
        do {
            let result = try await api.cleanupFiles()
            let count = result["files_removed"] as? Int ?? result["count"] as? Int ?? 0
            fileCleanupResult = "Cleaned up \(count) file(s)."
        } catch {
            fileCleanupResult = "Error: \(error.localizedDescription)"
        }
        isRunningFileCleanup = false
        showFileCleanupResult = true
        await loadFileUsage()
    }

    private var deleteConfirmLabel: String {
        switch deleteConfirmLevel {
        case .none: return "No confirmation required"
        case .password: return "Requires password"
        case .totp: return "Requires 2FA code"
        case .both: return "Requires password + 2FA"
        }
    }

    private func exportData() async {
        guard let api = store.api else { return }
        
        await MainActor.run {
            isExporting = true
            exportError = nil
        }
        
        do {
            let data = try await api.exportData()
            
            // Create a temporary file
            let timestamp = ISO8601DateFormatter().string(from: Date())
                .replacingOccurrences(of: ":", with: "-")
            let filename = "sheaf-export-\(timestamp).json"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            
            try data.write(to: tempURL)
            
            // Present share sheet
            await MainActor.run {
                isExporting = false
                presentShareSheet(url: tempURL)
            }
        } catch {
            await MainActor.run {
                isExporting = false
                exportError = error.localizedDescription
            }
        }
    }
    
    private func presentShareSheet(url: URL) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return
        }
        
        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        
        // For iPad - set popover source
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = rootViewController.view
            popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX,
                                       y: rootViewController.view.bounds.midY,
                                       width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        rootViewController.present(activityVC, animated: true) {
            // File will be cleaned up automatically by the system after sharing
        }
    }

    private func formatTier(_ tier: String) -> String {
        switch tier {
        case "free": return String(localized: "Free")
        case "plus": return String(localized: "Plus")
        case "self_hosted": return String(localized: "Self-Hosted")
        default: return tier.capitalized
        }
    }



    func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
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

    func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundColor(theme.textTertiary).frame(width: 20)
            Text(label).font(.system(size: 15)).foregroundColor(theme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13)).foregroundColor(theme.textTertiary)
                .lineLimit(1).truncationMode(.middle).frame(maxWidth: 160, alignment: .trailing)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }

    func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 15)).foregroundColor(theme.textSecondary)
            Spacer()
            Text(value).font(.system(size: 15, weight: .semibold)).foregroundColor(theme.accentLight)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }
}
