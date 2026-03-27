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
    @State private var newBaseURL = ""
    @State private var newToken = ""
    @State private var me: UserRead?
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var showExportSuccess = false

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
                            infoRow(icon: "key.fill", label: String(localized: "Token"), value: maskedToken)
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
                                Button { themeManager.mode = mode } label: {
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
                                        : Color.white.opacity(0.4))
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
                                            : Color.white.opacity(0.3))
                                } else {
                                    ProgressView().tint(theme.accentLight).scaleEffect(0.7)
                                }
                            }
                            .padding(.horizontal, 16).padding(.vertical, 14)

                            Divider().background(theme.backgroundCard)

                            // Setup / manage button
                            Button { showTOTPSetup = true } label: {
                                HStack {
                                    Image(systemName: me?.totpEnabled == true
                                          ? "gearshape.fill" : "plus.circle.fill")
                                        .foregroundColor(theme.accentLight)
                                    Text(me?.totpEnabled == true
                                         ? String(localized: "Manage Two-Factor Auth") : String(localized: "Set Up Two-Factor Auth"))
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
                            // User tier
                            if let me {
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
        } // NavigationStack
    }

    private func loadMe() async {
        guard let api = store.api else { return }
        me = try? await api.getMe()
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
        .confirmationDialog("Run Storage Audit?", isPresented: $showAuditConfirm, titleVisibility: .visible) {
            Button("Run Storage Audit", role: .destructive) { Task { await runMaintenance(.storageAudit) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will audit storage usage across all users.")
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

                    Text("Enter your password to access the admin panel.")
                        .font(.system(size: 14))
                        .foregroundColor(theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 40)

                VStack(spacing: 16) {
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

                    VStack(alignment: .leading, spacing: 8) {
                        Text("TOTP Code (if enabled)")
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
                .padding(.horizontal, 24)

                if let authError {
                    Text(authError)
                        .font(.system(size: 13))
                        .foregroundColor(theme.danger)
                        .padding(.horizontal, 24)
                }

                Button {
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
                    .background(password.isEmpty ? theme.accentLight.opacity(0.4) : theme.accentLight)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(password.isEmpty || isAuthenticating)
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
            isAdminAuthed = try await api.getAdminAuthStatus()
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

    private func loadStats() async {
        guard let api = store.api else { return }
        isLoadingStats = true
        stats = try? await api.getAdminStats()
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
            if reset { users = [] }
        }
        isLoadingUsers = false
    }

    private enum MaintenanceAction {
        case retention, cleanup, storageAudit
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
            case .storageAudit:
                try await api.runStorageAudit()
                maintenanceResult = "Storage audit completed successfully."
            }
        } catch {
            maintenanceResult = "Error: \(error.localizedDescription)"
        }
        isRunningMaintenance = false
        showMaintenanceResult = true
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
}
