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
                        Text(LocalizedStrings.settings)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)

                    // Connection
                    settingsSection(title: LocalizedStrings.connection) {
                        VStack(spacing: 0) {
                            infoRow(icon: "link", label: LocalizedStrings.apiURL, value: authManager.baseURL)
                            Divider().background(theme.backgroundCard)
                            infoRow(icon: "key.fill", label: LocalizedStrings.token, value: maskedToken)
                            Divider().background(theme.backgroundCard)
                            Button {
                                newBaseURL = authManager.baseURL
                                newToken   = authManager.accessToken
                                showEditConnection = true
                            } label: {
                                HStack {
                                    Image(systemName: "pencil").foregroundColor(theme.accentLight)
                                    Text(LocalizedStrings.editConnection)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(theme.accentLight)
                                    Spacer()
                                }
                                .padding(.horizontal, 16).padding(.vertical, 14)
                            }
                        }
                    }

                    // Appearance
                    settingsSection(title: LocalizedStrings.appearance) {
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
                    settingsSection(title: LocalizedStrings.security) {
                        VStack(spacing: 0) {
                            // TOTP status row
                            HStack(spacing: 12) {
                                Image(systemName: "lock.shield.fill")
                                    .foregroundColor(me?.totpEnabled == true
                                        ? theme.success
                                        : Color.white.opacity(0.4))
                                    .frame(width: 20)
                                Text(LocalizedStrings.twoFactorAuth)
                                    .font(.system(size: 15))
                                    .foregroundColor(theme.textSecondary)
                                Spacer()
                                if let me {
                                    Text(me.totpEnabled ? LocalizedStrings.twoFactorEnabled : LocalizedStrings.twoFactorDisabled)
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
                                         ? LocalizedStrings.manageTwoFactorAuth : LocalizedStrings.setUpTwoFactorAuth)
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
                            // Import
                            Button { showImport = true } label: {
                                HStack {
                                    Image(systemName: "square.and.arrow.down.fill")
                                        .foregroundColor(theme.accentLight)
                                        .frame(width: 20)
                                    Text(LocalizedStrings.importFromSimplyPlural)
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
                                    if let url = profile.avatarURL, !url.isEmpty,
                                       let imageURL = URL(string: url) {
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

                    // Account
                    settingsSection(title: "Account") {
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
