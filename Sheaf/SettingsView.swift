import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - SettingsView
struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var store: SystemStore
    @State private var showLogoutConfirm = false
    @State private var showEditConnection = false
    @State private var showTOTPSetup = false
    @State private var newBaseURL = ""
    @State private var newToken = ""
    @State private var me: UserRead?

    var body: some View {
        ZStack {
            Color(hex: "#0F0C29")!.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Text("Settings")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)

                    // Connection
                    settingsSection(title: "Connection") {
                        VStack(spacing: 0) {
                            infoRow(icon: "link", label: "API URL", value: authManager.baseURL)
                            Divider().background(Color.white.opacity(0.06))
                            infoRow(icon: "key.fill", label: "Token", value: maskedToken)
                            Divider().background(Color.white.opacity(0.06))
                            Button {
                                newBaseURL = authManager.baseURL
                                newToken   = authManager.accessToken
                                showEditConnection = true
                            } label: {
                                HStack {
                                    Image(systemName: "pencil").foregroundColor(Color(hex: "#A78BFA")!)
                                    Text("Edit Connection")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(Color(hex: "#A78BFA")!)
                                    Spacer()
                                }
                                .padding(.horizontal, 16).padding(.vertical, 14)
                            }
                        }
                    }

                    // Security
                    settingsSection(title: "Security") {
                        VStack(spacing: 0) {
                            // TOTP status row
                            HStack(spacing: 12) {
                                Image(systemName: "lock.shield.fill")
                                    .foregroundColor(me?.totpEnabled == true
                                        ? Color(hex: "#4ADE80")!
                                        : Color.white.opacity(0.4))
                                    .frame(width: 20)
                                Text("Two-Factor Auth")
                                    .font(.system(size: 15))
                                    .foregroundColor(.white.opacity(0.7))
                                Spacer()
                                if let me {
                                    Text(me.totpEnabled ? "Enabled" : "Disabled")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(me.totpEnabled
                                            ? Color(hex: "#4ADE80")!
                                            : Color.white.opacity(0.3))
                                } else {
                                    ProgressView().tint(Color(hex: "#A78BFA")!).scaleEffect(0.7)
                                }
                            }
                            .padding(.horizontal, 16).padding(.vertical, 14)

                            Divider().background(Color.white.opacity(0.06))

                            // Setup / manage button
                            Button { showTOTPSetup = true } label: {
                                HStack {
                                    Image(systemName: me?.totpEnabled == true
                                          ? "gearshape.fill" : "plus.circle.fill")
                                        .foregroundColor(Color(hex: "#A78BFA")!)
                                    Text(me?.totpEnabled == true
                                         ? "Manage Two-Factor Auth" : "Set Up Two-Factor Auth")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(Color(hex: "#A78BFA")!)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.2))
                                }
                                .padding(.horizontal, 16).padding(.vertical, 14)
                            }
                        }
                    }

                    // Data
                    settingsSection(title: "Data") {
                        Button { store.loadAll() } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise").foregroundColor(Color(hex: "#6366F1")!)
                                Text("Refresh All Data")
                                    .font(.system(size: 15, weight: .medium)).foregroundColor(.white)
                                Spacer()
                                if store.isLoading { ProgressView().tint(Color(hex: "#A78BFA")!) }
                            }
                            .padding(.horizontal, 16).padding(.vertical, 14)
                        }
                    }

                    // System info
                    settingsSection(title: "System Info") {
                        VStack(spacing: 0) {
                            statRow(label: "Members",          value: "\(store.members.count)")
                            Divider().background(Color.white.opacity(0.06))
                            statRow(label: "Groups",           value: "\(store.groups.count)")
                            Divider().background(Color.white.opacity(0.06))
                            statRow(label: "Currently Fronting", value: "\(store.frontingMembers.count)")
                        }
                    }

                    // Account
                    settingsSection(title: "Account") {
                        Button { showLogoutConfirm = true } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .foregroundColor(Color(hex: "#F87171")!)
                                Text("Disconnect & Log Out")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(Color(hex: "#F87171")!)
                                Spacer()
                            }
                            .padding(.horizontal, 16).padding(.vertical, 14)
                        }
                    }

                    VStack(spacing: 4) {
                        Text("Sheaf").font(.system(size: 13, weight: .semibold)).foregroundColor(.white.opacity(0.3))
                        Text("v1.0.0").font(.system(size: 12)).foregroundColor(.white.opacity(0.2))
                    }
                    .padding(.bottom, 80)
                }
            }
        }
        .task { await loadMe() }
        .confirmationDialog("Log out?", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
            Button("Disconnect", role: .destructive) { authManager.logout() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll need to enter your API URL and email again.")
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
    }

    private func loadMe() async {
        guard let api = store.api else { return }
        me = try? await api.getMe()
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
                .foregroundColor(.white.opacity(0.45))
                .textCase(.uppercase)
                .kerning(0.8)
                .padding(.horizontal, 24)
            VStack(spacing: 0) { content() }
                .background(Color.white.opacity(0.05))
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.07), lineWidth: 1))
                .padding(.horizontal, 24)
        }
    }

    func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundColor(.white.opacity(0.4)).frame(width: 20)
            Text(label).font(.system(size: 15)).foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.system(size: 13)).foregroundColor(.white.opacity(0.35))
                .lineLimit(1).truncationMode(.middle).frame(maxWidth: 160, alignment: .trailing)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }

    func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 15)).foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(value).font(.system(size: 15, weight: .semibold)).foregroundColor(Color(hex: "#A78BFA")!)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }
}

// MARK: - TOTP Setup Sheet
struct TOTPSetupSheet: View {
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
        ZStack {
            Color(hex: "#0F0C29")!.ignoresSafeArea()

            VStack(spacing: 0) {
                // Handle + header
                Capsule().fill(Color.white.opacity(0.2)).frame(width: 40, height: 4).padding(.top, 12)

                HStack {
                    Button(step == .done ? "" : "Cancel") {
                        if step != .done { dismiss() }
                    }
                    .foregroundColor(.white.opacity(0.5))
                    .opacity(step == .done ? 0 : 1)

                    Spacer()

                    Text(headerTitle)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    // Balance
                    Color.clear.frame(width: 50)
                }
                .padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 8)

                // Step content
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
                    .padding(.bottom, 60)
                }
            }
        }
        .task { await beginSetup() }
    }

    // MARK: - Steps

    var loadingStep: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 80)
            ProgressView().tint(Color(hex: "#A78BFA")!).scaleEffect(1.4)
            Text("Generating your secret…")
                .font(.system(size: 15)).foregroundColor(.white.opacity(0.5))
        }
    }

    var scanStep: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 8)

            Text("Scan this QR code with your authenticator app (e.g. Aegis, 1Password, Google Authenticator).")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)

            // QR code
            if let uri = setupResponse?.provisioningUri,
               let qr = generateQR(from: uri) {
                Image(uiImage: qr)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(16)
            }

            // Manual entry secret
            if let secret = setupResponse?.secret {
                VStack(spacing: 8) {
                    Text("Or enter manually")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                        .textCase(.uppercase).kerning(0.8)

                    HStack(spacing: 10) {
                        Text(secret)
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)

                        Button {
                            UIPasteboard.general.string = secret
                            copiedSecret = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedSecret = false }
                        } label: {
                            Image(systemName: copiedSecret ? "checkmark" : "doc.on.doc")
                                .foregroundColor(copiedSecret ? Color(hex: "#4ADE80")! : Color(hex: "#A78BFA")!)
                                .font(.system(size: 15))
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.07))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
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
                .foregroundColor(Color(hex: "#A78BFA")!)

            Text("Enter the 6-digit code from your authenticator app to confirm setup.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
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
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .onAppear { focusedDigit = 0 }
    }

    var recoveryCodesStep: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 8)

            Image(systemName: "list.bullet.rectangle.portrait.fill")
                .font(.system(size: 40))
                .foregroundColor(Color(hex: "#FBBF24")!)

            VStack(spacing: 6) {
                Text("Save your recovery codes")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("If you lose access to your authenticator, these one-time codes are the only way in. Store them somewhere safe.")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
            }

            // Codes grid
            if let codes = setupResponse?.recoveryCodes {
                VStack(spacing: 0) {
                    ForEach(Array(codes.enumerated()), id: \.offset) { i, code in
                        HStack {
                            Text("\(i + 1).")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.3))
                                .frame(width: 20, alignment: .trailing)
                            Text(code)
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        if i < codes.count - 1 {
                            Divider().background(Color.white.opacity(0.06))
                        }
                    }
                }
                .background(Color.white.opacity(0.05))
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))

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
                    .foregroundColor(copiedCodes ? Color(hex: "#4ADE80")! : Color(hex: "#A78BFA")!)
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
                    .fill(Color(hex: "#4ADE80")!.opacity(0.15))
                    .frame(width: 100, height: 100)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 44))
                    .foregroundColor(Color(hex: "#4ADE80")!)
            }
            .shadow(color: Color(hex: "#4ADE80")!.opacity(0.3), radius: 20)

            Text("Two-factor auth enabled!")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("Your account is now protected. You'll be asked for a code each time you sign in.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.55))
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
            .foregroundColor(Color(hex: "#F87171")!)
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
                    Color.white.opacity(0.1)
                } else {
                    LinearGradient(colors: [Color(hex: "#A78BFA")!, Color(hex: "#6366F1")!],
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
    @Binding var baseURL: String
    @Binding var token: String
    let onSave: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color(hex: "#0F0C29")!.ignoresSafeArea()
            VStack(spacing: 0) {
                Capsule().fill(Color.white.opacity(0.2)).frame(width: 40, height: 4).padding(.top, 12)
                HStack {
                    Button("Cancel") { dismiss() }.foregroundColor(.white.opacity(0.5))
                    Spacer()
                    Text("Edit Connection").font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
                    Spacer()
                    Button("Save") { onSave(); dismiss() }
                        .foregroundColor(Color(hex: "#A78BFA")!)
                        .font(.system(size: 16, weight: .semibold))
                        .disabled(baseURL.isEmpty || token.isEmpty)
                }
                .padding(.horizontal, 24).padding(.top, 16)

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("API Base URL").font(.system(size: 13, weight: .semibold)).foregroundColor(.white.opacity(0.55))
                        TextField("https://...", text: $baseURL)
                            .keyboardType(.URL).autocapitalization(.none).autocorrectionDisabled()
                            .padding(14).background(Color.white.opacity(0.07)).cornerRadius(12).foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bearer Token").font(.system(size: 13, weight: .semibold)).foregroundColor(.white.opacity(0.55))
                        SecureField("eyJ...", text: $token)
                            .autocapitalization(.none).autocorrectionDisabled()
                            .padding(14).background(Color.white.opacity(0.07)).cornerRadius(12).foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 24).padding(.top, 24)
                Spacer()
            }
        }
    }
}
