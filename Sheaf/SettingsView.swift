import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

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
    @State private var showEditConnection = false
    @State private var showTOTPSetup = false
    @State private var showTOTPManage = false
    @State private var newBaseURL = ""
    @State private var newToken = ""
    @State private var me: UserRead?
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var showExportSuccess = false
    @State private var deleteConfirmLevel: DeleteConfirmation = .none
    @State private var showDeleteConfirmSheet = false
    @State private var isLoadingFileUsage = false
    @State private var fileUsageDisplay = "—"
    @State private var showDeleteAccount = false
    @State private var showCancelDeletion = false
    @State private var isCancellingDeletion = false
    @State private var logoTapCount = 0
    @State private var showDebugToken = false

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

                    // Connection
                    settingsSection(title: String(localized: "Connection")) {
                        VStack(spacing: 0) {
                            infoRow(icon: "link", label: String(localized: "API URL"), value: authManager.baseURL)
                            Divider().background(theme.backgroundCard)
                            if showDebugToken {
                                infoRow(icon: "key.fill", label: String(localized: "Token"), value: maskedToken)
                            } else {
                                infoRow(icon: "envelope.fill", label: String(localized: "Email"), value: me?.email ?? "—")
                            }
                            Divider().background(theme.backgroundCard)
                            Button {
                                newBaseURL = authManager.baseURL
                                newToken   = authManager.accessToken
                                showEditConnection = true
                            } label: {
                                HStack {
                                    Image(systemName: "pencil").foregroundColor(theme.accentLight)
                                    Text("Edit Connection")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(theme.accentLight)
                                    Spacer()
                                }
                                .padding(.horizontal, 16).padding(.vertical, 14)
                            }
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
                                        Text("Requested \(deletionDate, style: .relative) ago")
                                            .font(.system(size: 13))
                                            .foregroundColor(theme.textSecondary)
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
                            }

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
                    .onTapGesture {
                        logoTapCount += 1
                        if logoTapCount >= 5 {
                            withAnimation { showDebugToken.toggle() }
                            logoTapCount = 0
                        }
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
        .sheet(isPresented: $showEditConnection) {
            EditConnectionSheet(baseURL: $newBaseURL, token: $newToken) {
                authManager.save(baseURL: newBaseURL,
                                 tokens: TokenResponse(accessToken: newToken,
                                                       refreshToken: authManager.refreshToken,
                                                       tokenType: "bearer"))
                store.loadAll()
            }
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
        } // NavigationStack
    }

    private func loadMe() async {
        guard let api = store.api else { return }
        me = try? await api.getMe()
        // Load delete confirmation level from system profile
        if let profile = store.systemProfile {
            deleteConfirmLevel = profile.deleteConfirmation
        } else if let profile = try? await api.getMySystem() {
            deleteConfirmLevel = profile.deleteConfirmation
        }
        // Load file usage
        await loadFileUsage()
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

    var maskedToken: String {
        let t = authManager.accessToken
        guard t.count > 8 else { return "••••••••" }
        return String(t.prefix(6)) + "••••••••" + String(t.suffix(4))
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

// MARK: - TOTP Setup Sheet
struct TOTPSetupSheet: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss

    enum Step { case loading, scan, verify, recoveryCodes, done }

    @State private var step: Step = .loading
    @State private var setupResponse: TOTPSetupResponse?
    @State private var error: String = ""
    @State private var digits: [String] = Array(repeating: "", count: 6)
    @State private var isVerifying = false
    @State private var copiedSecret = false
    @State private var copiedCodes = false
    @FocusState private var focusedDigit: Int?

    private var code: String { digits.joined() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    switch step {
                    case .loading:       loadingStep
                    case .scan:          scanStep
                    case .verify:        verifyStep
                    case .recoveryCodes: recoveryCodesStep
                    case .done:          doneStep
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .background(theme.backgroundPrimary)
            .navigationTitle(headerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if step != .done {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                            .foregroundColor(theme.accentLight)
                    }
                }
            }
        }
        .presentationDetents([.large])
        .task { await beginSetup() }
    }

    // MARK: - Steps

    var loadingStep: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 40)
            ProgressView().tint(theme.accentLight).scaleEffect(1.4)
            Text("Generating your secret…")
                .font(.system(size: 15)).foregroundColor(theme.textSecondary)
        }
    }

    var scanStep: some View {
        VStack(spacing: 16) {
            Text("Scan with your authenticator app (Aegis, 1Password, Google Authenticator).")
                .font(.system(size: 13))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)

            // QR code + secret side by side on wider screens, stacked on narrow
            if let uri = setupResponse?.provisioningUri,
               let qr = generateQR(from: uri) {
                Image(uiImage: qr)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 160, height: 160)
                    .padding(12)
                    .background(Color.white)
                    .cornerRadius(14)
            }

            // Manual entry secret
            if let secret = setupResponse?.secret {
                VStack(spacing: 6) {
                    Text("Or enter manually")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(theme.textTertiary)
                        .textCase(.uppercase).kerning(0.8)

                    HStack(spacing: 10) {
                        Text(secret)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(theme.textPrimary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        Button {
                            UIPasteboard.general.string = secret
                            copiedSecret = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedSecret = false }
                        } label: {
                            Image(systemName: copiedSecret ? "checkmark" : "doc.on.doc")
                                .foregroundColor(copiedSecret ? theme.success : theme.accentLight)
                                .font(.system(size: 15))
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(theme.backgroundCard)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.backgroundElevated, lineWidth: 1))
                }
            }

            if !error.isEmpty { errorLabel }

            primaryButton(label: "I've scanned it — Next") {
                withAnimation { step = .verify }
            }
        }
    }

    var verifyStep: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 8)

            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 48))
                .foregroundColor(theme.accentLight)

            Text("Enter the 6-digit code from your authenticator app to confirm setup.")
                .font(.system(size: 14))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)

            // Digit boxes (reuse same style as TOTPView)
            HStack(spacing: 10) {
                ForEach(0..<6, id: \.self) { i in
                    DigitBox(digit: $digits[i],
                             isFocused: focusedDigit == i,
                             hasError: !error.isEmpty)
                        .focused($focusedDigit, equals: i)
                        .onChange(of: digits[i]) { _, new in handleDigit(index: i, value: new) }
                }
            }

            if !error.isEmpty { errorLabel }

            primaryButton(label: isVerifying ? "" : "Verify & Enable",
                          loading: isVerifying,
                          disabled: code.count < 6 || isVerifying) {
                Task { await confirmCode() }
            }

            Button { withAnimation { step = .scan } } label: {
                Text("Back")
                    .font(.system(size: 14))
                    .foregroundColor(theme.textTertiary)
            }
        }
        .onAppear { focusedDigit = 0 }
    }

    var recoveryCodesStep: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 8)

            Image(systemName: "list.bullet.rectangle.portrait.fill")
                .font(.system(size: 40))
                .foregroundColor(theme.warning)

            VStack(spacing: 6) {
                Text("Save your recovery codes")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textPrimary)
                Text("If you lose access to your authenticator, these one-time codes are the only way in. Store them somewhere safe.")
                    .font(.system(size: 13))
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Codes grid
            if let codes = setupResponse?.recoveryCodes {
                VStack(spacing: 0) {
                    ForEach(Array(codes.enumerated()), id: \.offset) { i, code in
                        HStack {
                            Text("\(i + 1).")
                                .font(.system(size: 12))
                                .foregroundColor(theme.textTertiary)
                                .frame(width: 20, alignment: .trailing)
                            Text(code)
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .foregroundColor(theme.textPrimary)
                            Spacer()
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        if i < codes.count - 1 {
                            Divider().background(theme.backgroundCard)
                        }
                    }
                }
                .background(theme.backgroundCard)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.backgroundElevated, lineWidth: 1))

                // Copy all button
                Button {
                    UIPasteboard.general.string = codes.joined(separator: "\n")
                    copiedCodes = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedCodes = false }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: copiedCodes ? "checkmark" : "doc.on.doc")
                        Text(copiedCodes ? "Copied!" : "Copy All Codes")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(copiedCodes ? theme.success : theme.accentLight)
                }
            }

            primaryButton(label: "I've saved them — Done") {
                withAnimation { step = .done }
            }
        }
    }

    var doneStep: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 60)

            ZStack {
                Circle()
                    .fill(theme.success.opacity(0.15))
                    .frame(width: 100, height: 100)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 44))
                    .foregroundColor(theme.success)
            }
            .shadow(color: theme.success.opacity(0.3), radius: 20)

            Text("Two-factor auth enabled!")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(theme.textPrimary)

            Text("Your account is now protected. You'll be asked for a code each time you sign in.")
                .font(.system(size: 14))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 20)

            primaryButton(label: "Close") { dismiss() }
        }
    }

    // MARK: - Helpers

    var headerTitle: String {
        switch step {
        case .loading:       return "Set Up 2FA"
        case .scan:          return "Scan QR Code"
        case .verify:        return "Confirm Code"
        case .recoveryCodes: return "Recovery Codes"
        case .done:          return "All Done"
        }
    }

    var errorLabel: some View {
        Text(error)
            .font(.system(size: 13))
            .foregroundColor(theme.danger)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    func primaryButton(label: String, loading: Bool = false, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                if loading { ProgressView().tint(.white) }
                else { Text(label).font(.system(size: 16, weight: .semibold)).foregroundColor(.white) }
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(Group {
                if disabled {
                    theme.backgroundElevated
                } else {
                    LinearGradient(colors: [theme.accentLight, theme.accent],
                                   startPoint: .leading, endPoint: .trailing)
                }
            })
            .cornerRadius(14)
        }
        .disabled(disabled)
    }

    func handleDigit(index: Int, value: String) {
        error = ""
        let stripped = value.filter { $0.isNumber }
        if stripped.count == 6 {
            for i in 0..<6 { digits[i] = String(stripped[stripped.index(stripped.startIndex, offsetBy: i)]) }
            focusedDigit = nil
            Task { await confirmCode() }
            return
        }
        if value.count > 1 { digits[index] = String(value.last ?? Character("")) }
        digits[index] = digits[index].filter { $0.isNumber }
        if !digits[index].isEmpty && index < 5 { focusedDigit = index + 1 }
        if code.count == 6 { Task { await confirmCode() } }
    }

    func beginSetup() async {
        let api = APIClient(auth: authManager)
        do {
            let response = try await api.setupTOTP()
            await MainActor.run {
                setupResponse = response
                withAnimation { step = .scan }
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                withAnimation { step = .scan }
            }
        }
    }

    func confirmCode() async {
        guard code.count == 6 else { return }
        isVerifying = true
        error = ""
        let api = APIClient(auth: authManager)
        do {
            try await api.verifyTOTP(code: code)
            await MainActor.run {
                isVerifying = false
                withAnimation { step = .recoveryCodes }
            }
        } catch {
            await MainActor.run {
                self.error = "Incorrect code — please try again"
                isVerifying = false
                digits = Array(repeating: "", count: 6)
                focusedDigit = 0
            }
        }
    }

    func generateQR(from string: String) -> UIImage? {
        let context = CIContext()
        let filter  = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Delete Confirmation Sheet
struct DeleteConfirmationSheet: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var store: SystemStore
    @Environment(\.dismiss) var dismiss

    let currentLevel: DeleteConfirmation
    let totpEnabled: Bool
    let onUpdate: (DeleteConfirmation) -> Void

    @State private var selectedLevel: DeleteConfirmation
    @State private var password = ""
    @State private var totpCode = ""
    @State private var isSaving = false
    @State private var error = ""

    init(currentLevel: DeleteConfirmation, totpEnabled: Bool, onUpdate: @escaping (DeleteConfirmation) -> Void) {
        self.currentLevel = currentLevel
        self.totpEnabled = totpEnabled
        self.onUpdate = onUpdate
        _selectedLevel = State(initialValue: currentLevel)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        Text("Choose the level of confirmation required when deleting members or other data.")
                            .font(.system(size: 14))
                            .foregroundColor(theme.textSecondary)
                            .padding(.horizontal, 4)

                        // Level picker
                        VStack(spacing: 0) {
                            confirmOption(.none, title: "None", desc: "No confirmation required")
                            Divider().background(theme.divider)
                            confirmOption(.password, title: "Password", desc: "Require password to delete")
                            if totpEnabled {
                                Divider().background(theme.divider)
                                confirmOption(.totp, title: "2FA Code", desc: "Require authenticator code")
                                Divider().background(theme.divider)
                                confirmOption(.both, title: "Password + 2FA", desc: "Require both to delete")
                            }
                        }
                        .background(theme.backgroundCard)
                        .cornerRadius(14)

                        if selectedLevel != currentLevel {
                            // Password confirmation
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Confirm with your password")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(theme.textSecondary)
                                SecureField("Password", text: $password)
                                    .autocapitalization(.none)
                                    .autocorrectionDisabled()
                                    .padding(14)
                                    .background(theme.inputBackground)
                                    .cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12)
                                        .stroke(theme.inputBorder, lineWidth: 1.5))
                                    .foregroundColor(theme.textPrimary)
                            }

                            if totpEnabled {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("2FA Code")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(theme.textSecondary)
                                    TextField("6-digit code", text: $totpCode)
                                        .keyboardType(.numberPad)
                                        .padding(14)
                                        .background(theme.inputBackground)
                                        .cornerRadius(12)
                                        .overlay(RoundedRectangle(cornerRadius: 12)
                                            .stroke(theme.inputBorder, lineWidth: 1.5))
                                        .foregroundColor(theme.textPrimary)
                                }
                            }
                        }

                        if !error.isEmpty {
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
            .navigationTitle("Delete Confirmation")
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
                                .foregroundColor(selectedLevel != currentLevel && !password.isEmpty ? theme.accentLight : theme.textTertiary)
                        }
                    }
                    .disabled(selectedLevel == currentLevel || password.isEmpty || isSaving)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func confirmOption(_ level: DeleteConfirmation, title: String, desc: String) -> some View {
        Button {
            selectedLevel = level
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selectedLevel == level ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(selectedLevel == level ? theme.accentLight : theme.textTertiary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(theme.textPrimary)
                    Text(desc)
                        .font(.system(size: 12))
                        .foregroundColor(theme.textTertiary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private func save() async {
        guard let api = store.api else { return }
        isSaving = true
        error = ""
        do {
            let update = DeleteConfirmationUpdate(
                level: selectedLevel,
                password: password,
                totpCode: totpCode.isEmpty ? nil : totpCode
            )
            _ = try await api.updateDeleteConfirmation(update)
            await MainActor.run {
                onUpdate(selectedLevel)
                isSaving = false
                dismiss()
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isSaving = false
            }
        }
    }
}

// MARK: - TOTP Manage Sheet
struct TOTPManageSheet: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var store: SystemStore
    @Environment(\.dismiss) var dismiss

    enum Page { case menu, disableConfirm, regenerateConfirm, recoveryCodes, disabled }

    @State private var page: Page = .menu
    @State private var password = ""
    @State private var totpCode = ""
    @State private var error = ""
    @State private var isProcessing = false
    @State private var recoveryCodes: [String] = []
    @State private var copiedCodes = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    switch page {
                    case .menu:              menuPage
                    case .disableConfirm:    disableConfirmPage
                    case .regenerateConfirm: regenerateConfirmPage
                    case .recoveryCodes:     recoveryCodesPage
                    case .disabled:          disabledPage
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .background(theme.backgroundPrimary)
            .navigationTitle(pageTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(page == .disabled || page == .recoveryCodes ? "Done" : "Cancel") { dismiss() }
                        .foregroundColor(theme.accentLight)
                }
            }
        }
        .presentationDetents([.large])
    }

    private var pageTitle: String {
        switch page {
        case .menu:              return "Manage 2FA"
        case .disableConfirm:    return "Disable 2FA"
        case .regenerateConfirm: return "Regenerate Codes"
        case .recoveryCodes:     return "Recovery Codes"
        case .disabled:          return "2FA Disabled"
        }
    }

    // MARK: - Menu

    private var menuPage: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 20)

            ZStack {
                Circle()
                    .fill(theme.success.opacity(0.15))
                    .frame(width: 80, height: 80)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 36))
                    .foregroundColor(theme.success)
            }
            .shadow(color: theme.success.opacity(0.3), radius: 16)

            Text("Two-factor authentication is enabled")
                .font(.system(size: 15))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 12)

            // Regenerate recovery codes
            Button {
                withAnimation { page = .regenerateConfirm }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 18))
                        .foregroundColor(theme.accentLight)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Regenerate Recovery Codes")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(theme.textPrimary)
                        Text("Get new one-time backup codes")
                            .font(.system(size: 12))
                            .foregroundColor(theme.textTertiary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(theme.textTertiary)
                }
                .padding(16)
                .background(theme.backgroundCard)
                .cornerRadius(14)
            }

            // Disable TOTP
            Button {
                withAnimation { page = .disableConfirm }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "lock.open.fill")
                        .font(.system(size: 18))
                        .foregroundColor(theme.danger)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Disable Two-Factor Auth")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(theme.danger)
                        Text("Remove 2FA protection from your account")
                            .font(.system(size: 12))
                            .foregroundColor(theme.textTertiary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(theme.textTertiary)
                }
                .padding(16)
                .background(theme.backgroundCard)
                .cornerRadius(14)
            }
        }
    }

    // MARK: - Disable Confirm

    private var disableConfirmPage: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 12)

            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 48))
                .foregroundColor(theme.warning)

            Text("This will remove two-factor authentication from your account. You'll need to verify your identity.")
                .font(.system(size: 14))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.textSecondary)
                SecureField("Enter your password", text: $password)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .padding(14)
                    .background(theme.inputBackground)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.inputBorder, lineWidth: 1.5))
                    .foregroundColor(theme.textPrimary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Current 2FA Code")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.textSecondary)
                TextField("6-digit code", text: $totpCode)
                    .keyboardType(.numberPad)
                    .padding(14)
                    .background(theme.inputBackground)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.inputBorder, lineWidth: 1.5))
                    .foregroundColor(theme.textPrimary)
            }

            if !error.isEmpty {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundColor(theme.danger)
            }

            Button { Task { await disableTOTP() } } label: {
                HStack {
                    if isProcessing { ProgressView().tint(.white) }
                    else { Text("Disable Two-Factor Auth").font(.system(size: 16, weight: .semibold)) }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(theme.danger)
                .cornerRadius(14)
            }
            .disabled(password.isEmpty || isProcessing)
            .opacity(password.isEmpty ? 0.5 : 1)

            Button { withAnimation { page = .menu } } label: {
                Text("Back")
                    .font(.system(size: 14))
                    .foregroundColor(theme.textTertiary)
            }
        }
    }

    // MARK: - Regenerate Confirm

    private var regenerateConfirmPage: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 12)

            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 48))
                .foregroundColor(theme.warning)

            Text("This will invalidate your current recovery codes and generate new ones. Enter your current 2FA code to confirm.")
                .font(.system(size: 14))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                Text("Current 2FA Code")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.textSecondary)
                TextField("6-digit code", text: $totpCode)
                    .keyboardType(.numberPad)
                    .padding(14)
                    .background(theme.inputBackground)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.inputBorder, lineWidth: 1.5))
                    .foregroundColor(theme.textPrimary)
            }

            if !error.isEmpty {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundColor(theme.danger)
            }

            Button { Task { await regenerateCodes() } } label: {
                HStack {
                    if isProcessing { ProgressView().tint(.white) }
                    else { Text("Regenerate Codes").font(.system(size: 16, weight: .semibold)) }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(LinearGradient(colors: [theme.accentLight, theme.accent],
                                           startPoint: .leading, endPoint: .trailing))
                .cornerRadius(14)
            }
            .disabled(totpCode.count != 6 || isProcessing)
            .opacity(totpCode.count != 6 ? 0.5 : 1)

            Button { withAnimation { page = .menu } } label: {
                Text("Back")
                    .font(.system(size: 14))
                    .foregroundColor(theme.textTertiary)
            }
        }
    }

    // MARK: - Recovery Codes

    private var recoveryCodesPage: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 8)

            Image(systemName: "list.bullet.rectangle.portrait.fill")
                .font(.system(size: 40))
                .foregroundColor(theme.warning)

            VStack(spacing: 6) {
                Text("New Recovery Codes")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textPrimary)
                Text("Your old recovery codes are now invalid. Save these new codes somewhere safe.")
                    .font(.system(size: 13))
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 0) {
                ForEach(Array(recoveryCodes.enumerated()), id: \.offset) { i, code in
                    HStack {
                        Text("\(i + 1).")
                            .font(.system(size: 12))
                            .foregroundColor(theme.textTertiary)
                            .frame(width: 20, alignment: .trailing)
                        Text(code)
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundColor(theme.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    if i < recoveryCodes.count - 1 {
                        Divider().background(theme.backgroundCard)
                    }
                }
            }
            .background(theme.backgroundCard)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.backgroundElevated, lineWidth: 1))

            Button {
                UIPasteboard.general.string = recoveryCodes.joined(separator: "\n")
                copiedCodes = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedCodes = false }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: copiedCodes ? "checkmark" : "doc.on.doc")
                    Text(copiedCodes ? "Copied!" : "Copy All Codes")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(copiedCodes ? theme.success : theme.accentLight)
            }
        }
    }

    // MARK: - Disabled

    private var disabledPage: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 60)

            ZStack {
                Circle()
                    .fill(theme.warning.opacity(0.15))
                    .frame(width: 100, height: 100)
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 44))
                    .foregroundColor(theme.warning)
            }
            .shadow(color: theme.warning.opacity(0.3), radius: 20)

            Text("Two-factor auth disabled")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(theme.textPrimary)

            Text("Your account is no longer protected by two-factor authentication. You can re-enable it from Settings.")
                .font(.system(size: 14))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Actions

    private func disableTOTP() async {
        guard let api = store.api else { return }
        isProcessing = true
        error = ""
        do {
            // The API expects email + password + optional totp code
            let me = try await api.getMe()
            try await api.disableTOTP(
                email: me.email,
                password: password,
                totpCode: totpCode.isEmpty ? nil : totpCode
            )
            await MainActor.run {
                isProcessing = false
                withAnimation { page = .disabled }
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isProcessing = false
            }
        }
    }

    private func regenerateCodes() async {
        guard let api = store.api else { return }
        isProcessing = true
        error = ""
        do {
            let codes = try await api.regenerateRecoveryCodes(code: totpCode)
            await MainActor.run {
                recoveryCodes = codes
                isProcessing = false
                withAnimation { page = .recoveryCodes }
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isProcessing = false
            }
        }
    }
}

// MARK: - API Keys View
struct ApiKeysView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var store: SystemStore

    @State private var keys: [ApiKeyRead] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var showCreate = false
    @State private var createdKey: ApiKeyCreated?
    @State private var showCreatedAlert = false
    @State private var copiedKey = false

    var body: some View {
        ZStack {
            theme.backgroundPrimary.ignoresSafeArea()

            if isLoading {
                ProgressView().tint(theme.accentLight)
            } else if keys.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "key.horizontal.fill")
                        .font(.system(size: 40))
                        .foregroundColor(theme.textTertiary)
                    Text("No API Keys")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                    Text("Create an API key to access the Sheaf API programmatically.")
                        .font(.system(size: 14))
                        .foregroundColor(theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            } else {
                List {
                    ForEach(keys) { key in
                        apiKeyRow(key)
                            .listRowBackground(theme.backgroundCard)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 5, leading: 24, bottom: 5, trailing: 24))
                    }
                    .onDelete { indexSet in
                        Task {
                            for index in indexSet {
                                let key = keys[index]
                                try? await store.api?.revokeApiKey(id: key.id)
                            }
                            keys.remove(atOffsets: indexSet)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("API Keys")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreate = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(theme.accentLight)
                }
            }
        }
        .task { await loadKeys() }
        .sheet(isPresented: $showCreate, onDismiss: { Task { await loadKeys() } }) {
            CreateApiKeySheet { created in
                createdKey = created
                showCreate = false
                showCreatedAlert = true
                Task { await loadKeys() }
            }
            .environmentObject(authManager)
            .environmentObject(store)
        }
        .sheet(isPresented: $showCreatedAlert) {
            if let created = createdKey {
                apiKeyCreatedSheet(created)
            }
        }
    }

    private func loadKeys() async {
        guard let api = store.api else { return }
        isLoading = true
        keys = (try? await api.listApiKeys()) ?? []
        isLoading = false
    }

    private func apiKeyRow(_ key: ApiKeyRead) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(key.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                Spacer()
                if let expires = key.expiresAt {
                    if expires < Date() {
                        Text("Expired")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(theme.danger)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(theme.danger.opacity(0.12))
                            .cornerRadius(6)
                    } else {
                        Text("Expires \(expires, style: .relative)")
                            .font(.system(size: 11))
                            .foregroundColor(theme.textTertiary)
                    }
                }
            }

            // Scopes
            if !key.scopes.isEmpty {
                HStack(spacing: 6) {
                    ForEach(key.scopes, id: \.self) { scope in
                        Text(scope)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(theme.accentLight)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(theme.accentLight.opacity(0.1))
                            .cornerRadius(6)
                    }
                }
            }

            HStack(spacing: 16) {
                if let lastUsed = key.lastUsedAt {
                    Label("Used \(lastUsed, style: .relative) ago", systemImage: "clock")
                        .font(.system(size: 11))
                        .foregroundColor(theme.textTertiary)
                } else {
                    Label("Never used", systemImage: "clock")
                        .font(.system(size: 11))
                        .foregroundColor(theme.textTertiary)
                }
                Spacer()
                Text("Created \(key.createdAt, style: .date)")
                    .font(.system(size: 11))
                    .foregroundColor(theme.textTertiary)
            }
        }
        .padding(14)
        .background(theme.backgroundCard)
        .cornerRadius(14)
    }

    private func apiKeyCreatedSheet(_ created: ApiKeyCreated) -> some View {
        ZStack {
            theme.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 20) {
                Capsule().fill(theme.inputBorder).frame(width: 40, height: 4).padding(.top, 12)

                Image(systemName: "key.horizontal.fill")
                    .font(.system(size: 40))
                    .foregroundColor(theme.success)
                    .padding(.top, 8)

                Text("API Key Created")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textPrimary)

                Text("Copy this key now. You won't be able to see it again.")
                    .font(.system(size: 14))
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                VStack(spacing: 8) {
                    Text(created.key)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(theme.textPrimary)
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(theme.backgroundCard)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.border, lineWidth: 1))

                    Button {
                        UIPasteboard.general.string = created.key
                        copiedKey = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedKey = false }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: copiedKey ? "checkmark" : "doc.on.doc")
                            Text(copiedKey ? "Copied!" : "Copy Key")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(copiedKey ? theme.success : theme.accentLight)
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(theme.backgroundCard)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                Button {
                    showCreatedAlert = false
                    createdKey = nil
                } label: {
                    Text("Done")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(LinearGradient(colors: [theme.accentLight, theme.accent],
                                                   startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(14)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Create API Key Sheet
struct CreateApiKeySheet: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var store: SystemStore
    @Environment(\.dismiss) var dismiss

    let onCreate: (ApiKeyCreated) -> Void

    @State private var name = ""
    @State private var selectedScopes: Set<String> = []
    @State private var hasExpiry = false
    @State private var expiresAt = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var isCreating = false
    @State private var error: String?

    private let availableScopes = [
        "members:read", "members:write",
        "fronts:read", "fronts:write",
        "groups:read", "groups:write",
        "system:read", "system:write",
        "fields:read", "fields:write",
        "tags:read", "tags:write",
        "files:read", "files:write",
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Name
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Name")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(theme.textSecondary)
                            TextField("My API Key", text: $name)
                                .autocorrectionDisabled()
                                .padding(12)
                                .background(theme.backgroundCard)
                                .cornerRadius(12)
                                .foregroundColor(theme.textPrimary)
                        }

                        // Scopes
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Scopes")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(theme.textSecondary)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                ForEach(availableScopes, id: \.self) { scope in
                                    Button {
                                        if selectedScopes.contains(scope) {
                                            selectedScopes.remove(scope)
                                        } else {
                                            selectedScopes.insert(scope)
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: selectedScopes.contains(scope) ? "checkmark.circle.fill" : "circle")
                                                .font(.system(size: 14))
                                                .foregroundColor(selectedScopes.contains(scope) ? theme.accentLight : theme.textTertiary)
                                            Text(scope)
                                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                                .foregroundColor(theme.textPrimary)
                                                .lineLimit(1)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 10).padding(.vertical, 8)
                                        .background(selectedScopes.contains(scope)
                                                     ? theme.accentLight.opacity(0.1)
                                                     : theme.backgroundCard)
                                        .cornerRadius(10)
                                        .overlay(RoundedRectangle(cornerRadius: 10)
                                            .stroke(selectedScopes.contains(scope)
                                                    ? theme.accentLight.opacity(0.3)
                                                    : theme.border, lineWidth: 1))
                                    }
                                }
                            }
                        }

                        // Expiry
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle(isOn: $hasExpiry) {
                                Text("Set Expiry")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(theme.textPrimary)
                            }
                            .tint(theme.accentLight)

                            if hasExpiry {
                                DatePicker("Expires", selection: $expiresAt,
                                           in: Date()...,
                                           displayedComponents: [.date])
                                    .datePickerStyle(.compact)
                                    .tint(theme.accentLight)
                                    .foregroundColor(theme.textPrimary)
                            }
                        }
                        .padding(14)
                        .background(theme.backgroundCard)
                        .cornerRadius(12)

                        if let error {
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundColor(theme.danger)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 80)
                }
            }
            .navigationTitle("Create API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(theme.accentLight)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await createKey() }
                    } label: {
                        if isCreating {
                            ProgressView().tint(theme.accentLight)
                        } else {
                            Text("Create")
                                .fontWeight(.semibold)
                                .foregroundColor(canCreate ? theme.accentLight : theme.textTertiary)
                        }
                    }
                    .disabled(!canCreate || isCreating)
                }
            }
        }
    }

    private var canCreate: Bool {
        !name.isEmpty && !selectedScopes.isEmpty
    }

    private func createKey() async {
        guard let api = store.api else { return }
        isCreating = true
        error = nil
        do {
            let create = ApiKeyCreate(
                name: name,
                scopes: Array(selectedScopes).sorted(),
                expiresAt: hasExpiry ? expiresAt : nil
            )
            let created = try await api.createApiKey(create)
            await MainActor.run {
                isCreating = false
                onCreate(created)
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isCreating = false
            }
        }
    }
}

// MARK: - Edit Connection Sheet
struct EditConnectionSheet: View {
    @Environment(\.theme) var theme
    @Binding var baseURL: String
    @Binding var token: String
    let onSave: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            theme.backgroundPrimary.ignoresSafeArea()
            VStack(spacing: 0) {
                Capsule().fill(theme.inputBorder).frame(width: 40, height: 4).padding(.top, 12)
                HStack {
                    Button("Cancel") { dismiss() }.foregroundColor(theme.textSecondary)
                    Spacer()
                    Text("Edit Connection").font(.system(size: 17, weight: .semibold)).foregroundColor(theme.textPrimary)
                    Spacer()
                    Button("Save") { onSave(); dismiss() }
                        .foregroundColor(theme.accentLight)
                        .font(.system(size: 16, weight: .semibold))
                        .disabled(baseURL.isEmpty || token.isEmpty)
                }
                .padding(.horizontal, 24).padding(.top, 16)

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("API Base URL").font(.system(size: 13, weight: .semibold)).foregroundColor(theme.textSecondary)
                        TextField("https://...", text: $baseURL)
                            .keyboardType(.URL).autocapitalization(.none).autocorrectionDisabled()
                            .padding(14).background(theme.backgroundCard).cornerRadius(12).foregroundColor(theme.textPrimary)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bearer Token").font(.system(size: 13, weight: .semibold)).foregroundColor(theme.textSecondary)
                        SecureField("eyJ...", text: $token)
                            .autocapitalization(.none).autocorrectionDisabled()
                            .padding(14).background(theme.backgroundCard).cornerRadius(12).foregroundColor(theme.textPrimary)
                    }
                }
                .padding(.horizontal, 24).padding(.top, 24)
                Spacer()
            }
        }
    }
}

// MARK: - Sessions View
struct SessionsView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var store: SystemStore

    @State private var sessions: [SessionRead] = []
    @State private var isLoading = true
    @State private var showRevokeAllConfirm = false
    @State private var renameSessionId: String?
    @State private var renameText = ""
    @State private var showRenameAlert = false

    var body: some View {
        ZStack {
            theme.backgroundPrimary.ignoresSafeArea()

            if isLoading {
                ProgressView().tint(theme.accentLight)
            } else if sessions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 40))
                        .foregroundColor(theme.textTertiary)
                    Text("No Sessions")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(theme.textSecondary)
                }
            } else {
                List {
                    ForEach(sessions) { session in
                        sessionRow(session)
                            .listRowBackground(theme.backgroundCard)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 5, leading: 24, bottom: 5, trailing: 24))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if !session.isCurrent {
                                    Button(role: .destructive) {
                                        Task { await revoke(session) }
                                    } label: {
                                        Label("Revoke", systemImage: "xmark.circle")
                                    }
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .refreshable { await load() }
            }
        }
        .navigationTitle("Sessions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(role: .destructive) {
                        showRevokeAllConfirm = true
                    } label: {
                        Label("Revoke All Others", systemImage: "xmark.shield")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20))
                        .foregroundColor(theme.accentLight)
                }
            }
        }
        .confirmationDialog("Revoke All Other Sessions?", isPresented: $showRevokeAllConfirm, titleVisibility: .visible) {
            Button("Revoke All Others", role: .destructive) {
                Task { await revokeAllOthers() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will immediately sign out all other devices. Your current session will not be affected.")
        }
        .alert("Rename Session", isPresented: $showRenameAlert) {
            TextField("Nickname", text: $renameText)
            Button("Save") {
                if let id = renameSessionId {
                    Task { await rename(id: id, nickname: renameText) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Give this session a name to identify it.")
        }
        .task { await load() }
    }

    private func sessionRow(_ session: SessionRead) -> some View {
        Button {
            renameSessionId = session.id
            renameText = session.nickname ?? ""
            showRenameAlert = true
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: iconForSession(session))
                        .font(.system(size: 16))
                        .foregroundColor(session.isCurrent ? theme.success : theme.accentLight)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(session.nickname ?? session.clientName ?? "Unknown Client")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(theme.textPrimary)
                                .lineLimit(1)
                            if session.isCurrent {
                                Text("Current")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(theme.success)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(theme.success.opacity(0.15))
                                    .cornerRadius(4)
                            }
                        }
                        if let ip = session.ipAddress {
                            Text(ip)
                                .font(.system(size: 12))
                                .foregroundColor(theme.textTertiary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        if let lastActive = session.lastActiveAt {
                            Text(lastActive, style: .relative)
                                .font(.system(size: 11))
                                .foregroundColor(theme.textTertiary)
                        }
                        Text(session.createdAt, style: .date)
                            .font(.system(size: 10))
                            .foregroundColor(theme.textTertiary)
                    }
                }
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private func iconForSession(_ session: SessionRead) -> String {
        let client = (session.clientName ?? session.userAgent ?? "").lowercased()
        if client.contains("ios") || client.contains("iphone") { return "iphone" }
        if client.contains("watch") { return "applewatch" }
        if client.contains("android") { return "phone" }
        if client.contains("safari") || client.contains("firefox") || client.contains("chrome") || client.contains("edge") { return "globe" }
        return "desktopcomputer"
    }

    private func load() async {
        guard let api = store.api else { return }
        do {
            let loaded = try await api.listSessions()
            await MainActor.run {
                // Sort: current session first, then by last active descending
                sessions = loaded.sorted {
                    if $0.isCurrent != $1.isCurrent { return $0.isCurrent }
                    return ($0.lastActiveAt ?? $0.createdAt) > ($1.lastActiveAt ?? $1.createdAt)
                }
                isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }

    private func revoke(_ session: SessionRead) async {
        guard let api = store.api else { return }
        do {
            try await api.revokeSession(id: session.id)
            await MainActor.run {
                withAnimation { sessions.removeAll { $0.id == session.id } }
            }
        } catch { /* silently fail — user can pull to refresh */ }
    }

    private func revokeAllOthers() async {
        guard let api = store.api else { return }
        do {
            try await api.revokeOtherSessions()
            await MainActor.run {
                withAnimation { sessions.removeAll { !$0.isCurrent } }
            }
        } catch { /* silently fail */ }
    }

    private func rename(id: String, nickname: String) async {
        guard let api = store.api else { return }
        do {
            let updated = try await api.renameSession(id: id, nickname: nickname)
            await MainActor.run {
                if let i = sessions.firstIndex(where: { $0.id == id }) {
                    sessions[i] = updated
                }
            }
        } catch { /* silently fail */ }
    }
}

// MARK: - Delete Account Sheet
struct DeleteAccountSheet: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var store: SystemStore
    @State private var password = ""
    @State private var totpCode = ""
    @State private var isDeleting = false
    @State private var errorMessage: String?
    @State private var showFinalConfirm = false
    @State private var me: UserRead?

    var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Warning banner
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(theme.danger)

                            Text("Delete Your Account")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(theme.textPrimary)

                            Text("This will schedule your account for deletion. All your data — members, fronting history, groups, and files — will be permanently removed.")
                                .font(.system(size: 14))
                                .foregroundColor(theme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)
                        .padding(.horizontal, 24)

                        VStack(spacing: 16) {
                            // Password field
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Password")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(theme.textSecondary)
                                SecureField("Enter your password", text: $password)
                                    .textContentType(.password)
                                    .padding(12)
                                    .background(theme.backgroundCard)
                                    .cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.divider, lineWidth: 1))
                            }

                            // TOTP field (only if TOTP is enabled)
                            if me?.totpEnabled == true {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Two-Factor Code")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(theme.textSecondary)
                                    TextField("6-digit code", text: $totpCode)
                                        .keyboardType(.numberPad)
                                        .textContentType(.oneTimeCode)
                                        .padding(12)
                                        .background(theme.backgroundCard)
                                        .cornerRadius(10)
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.divider, lineWidth: 1))
                                }
                            }

                            if let errorMessage {
                                Text(errorMessage)
                                    .font(.system(size: 13))
                                    .foregroundColor(theme.danger)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.horizontal, 24)

                        // Delete button
                        Button {
                            showFinalConfirm = true
                        } label: {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("Delete My Account")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(password.isEmpty ? theme.danger.opacity(0.4) : theme.danger)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(password.isEmpty || isDeleting)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                    }
                }
            }
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                guard let api = store.api else { return }
                me = try? await api.getMe()
            }
            .confirmationDialog("Are you absolutely sure?", isPresented: $showFinalConfirm, titleVisibility: .visible) {
                Button("Delete My Account", role: .destructive) {
                    Task { await performDeletion() }
                }
                Button("Go Back", role: .cancel) {}
            } message: {
                Text("This action cannot be easily undone. Your account and all associated data will be scheduled for permanent deletion.")
            }
        }
    }

    private func performDeletion() async {
        guard let api = store.api else { return }
        isDeleting = true
        errorMessage = nil
        do {
            try await api.deleteAccount(
                password: password,
                totpCode: totpCode.isEmpty ? nil : totpCode
            )
            // Don't dismiss() — logout changes the view hierarchy,
            // which removes this sheet automatically.
            await MainActor.run { authManager.logout() }
        } catch {
            errorMessage = error.localizedDescription
            isDeleting = false
        }
    }
}

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
    @State private var stats: [String: Int]?
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
                // Pending Approvals
                approvalsSection

                // Invite Codes
                invitesSection

                // Stats
                statsSection

                // User Management
                userManagementSection

                // Maintenance
                maintenanceSection
            }
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .refreshable {
            await loadStats()
            await loadUsers(reset: true)
            await loadInvites()
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
        .task { await loadApprovals() }
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
        .task { await loadInvites() }
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
                    adminStatCard(title: "Users", value: "\(stats["total_users"] ?? 0)", icon: "person.2.fill")
                    adminStatCard(title: "Members", value: "\(stats["total_members"] ?? 0)", icon: "person.fill")
                    adminStatCard(title: "Fronts", value: "\(stats["total_fronts"] ?? 0)", icon: "arrow.triangle.swap")
                    adminStatCard(title: "Groups", value: "\(stats["total_groups"] ?? 0)", icon: "folder.fill")
                    adminStatCard(title: "Fields", value: "\(stats["total_fields"] ?? 0)", icon: "list.bullet.rectangle")
                    adminStatCard(title: "Storage", value: formatBytes(stats["total_storage_bytes"] ?? 0), icon: "externaldrive.fill")
                }
                .padding(.horizontal, 24)
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
            await loadStats()
            await loadUsers(reset: true)
        }
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
            await loadStats()
            await loadUsers(reset: true)
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
            if reset { users = [] }
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
                        // User Info (read-only)
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

                        // Editable Fields
                        VStack(alignment: .leading, spacing: 10) {
                            Text("SETTINGS")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(theme.textSecondary)
                                .textCase(.uppercase)
                                .kerning(0.8)

                            VStack(spacing: 0) {
                                // Tier picker
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

                                // Admin toggle
                                Toggle(isOn: $isAdmin) {
                                    Text("Administrator")
                                        .font(.system(size: 15))
                                        .foregroundColor(theme.textPrimary)
                                }
                                .tint(theme.accentLight)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)

                                Divider().background(theme.divider)

                                // Member limit
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

                        // Recovery Tools
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
                            }
                            .background(theme.backgroundCard)
                            .cornerRadius(14)
                        }

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
