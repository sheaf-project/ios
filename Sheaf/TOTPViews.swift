import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

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
                .font(.subheadline).foregroundColor(theme.textSecondary)
        }
    }

    var scanStep: some View {
        VStack(spacing: 16) {
            Text("Scan with your authenticator app (Aegis, 1Password, Google Authenticator).")
                .font(.footnote)
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
                        .font(.caption2).fontWeight(.semibold)
                        .foregroundColor(theme.textTertiary)
                        .textCase(.uppercase).kerning(0.8)

                    HStack(spacing: 10) {
                        Text(secret)
                            .font(.footnote).fontWeight(.semibold).fontDesign(.monospaced)
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
                                .font(.subheadline)
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
                .font(.largeTitle)
                .foregroundColor(theme.accentLight)

            Text("Enter the 6-digit code from your authenticator app to confirm setup.")
                .font(.subheadline)
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
                    .font(.subheadline)
                    .foregroundColor(theme.textTertiary)
            }
        }
        .onAppear { focusedDigit = 0 }
    }

    var recoveryCodesStep: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 8)

            Image(systemName: "list.bullet.rectangle.portrait.fill")
                .font(.largeTitle)
                .foregroundColor(theme.warning)

            VStack(spacing: 6) {
                Text("Save your recovery codes")
                    .font(.title3).fontWeight(.bold).fontDesign(.rounded)
                    .foregroundColor(theme.textPrimary)
                Text("If you lose access to your authenticator, these one-time codes are the only way in. Store them somewhere safe.")
                    .font(.footnote)
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Codes grid
            if let codes = setupResponse?.recoveryCodes {
                VStack(spacing: 0) {
                    ForEach(Array(codes.enumerated()), id: \.offset) { i, code in
                        HStack {
                            Text("\(i + 1).")
                                .font(.caption)
                                .foregroundColor(theme.textTertiary)
                                .frame(width: 20, alignment: .trailing)
                            Text(code)
                                .font(.subheadline).fontWeight(.semibold).fontDesign(.monospaced)
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
                            .font(.subheadline).fontWeight(.medium)
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
                    .font(.largeTitle)
                    .foregroundColor(theme.success)
            }
            .shadow(color: theme.success.opacity(0.3), radius: 20)

            Text("Two-factor auth enabled!")
                .font(.title3).fontWeight(.bold).fontDesign(.rounded)
                .foregroundColor(theme.textPrimary)

            Text("Your account is now protected. You'll be asked for a code each time you sign in.")
                .font(.subheadline)
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
            .font(.footnote)
            .foregroundColor(theme.danger)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    func primaryButton(label: String, loading: Bool = false, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                if loading { ProgressView() }
                else { Text(label) }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(theme.accentLight)
        .disabled(disabled || loading)
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
        } catch is CancellationError {
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
                    .font(.title)
                    .foregroundColor(theme.success)
            }
            .shadow(color: theme.success.opacity(0.3), radius: 16)

            Text("Two-factor authentication is enabled")
                .font(.subheadline)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 12)

            // Regenerate recovery codes
            Button {
                withAnimation { page = .regenerateConfirm }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.body)
                        .foregroundColor(theme.accentLight)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Regenerate Recovery Codes")
                            .font(.subheadline).fontWeight(.medium)
                            .foregroundColor(theme.textPrimary)
                        Text("Get new one-time backup codes")
                            .font(.caption)
                            .foregroundColor(theme.textTertiary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
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
                        .font(.body)
                        .foregroundColor(theme.danger)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Disable Two-Factor Auth")
                            .font(.subheadline).fontWeight(.medium)
                            .foregroundColor(theme.danger)
                        Text("Remove 2FA protection from your account")
                            .font(.caption)
                            .foregroundColor(theme.textTertiary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
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
                .font(.largeTitle)
                .foregroundColor(theme.warning)

            Text("This will remove two-factor authentication from your account. You'll need to verify your identity.")
                .font(.subheadline)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.footnote).fontWeight(.semibold)
                    .foregroundColor(theme.textSecondary)
                SecureField("Enter your password", text: $password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(14)
                    .background(theme.inputBackground)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.inputBorder, lineWidth: 1.5))
                    .foregroundColor(theme.textPrimary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Current 2FA Code")
                    .font(.footnote).fontWeight(.semibold)
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
                    .font(.footnote)
                    .foregroundColor(theme.danger)
            }

            Button { Task { await disableTOTP() } } label: {
                HStack {
                    if isProcessing { ProgressView().tint(.white) }
                    else { Text("Disable Two-Factor Auth").font(.body).fontWeight(.semibold) }
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
                    .font(.subheadline)
                    .foregroundColor(theme.textTertiary)
            }
        }
    }

    // MARK: - Regenerate Confirm

    private var regenerateConfirmPage: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 12)

            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.largeTitle)
                .foregroundColor(theme.warning)

            Text("This will invalidate your current recovery codes and generate new ones. Enter your current 2FA code to confirm.")
                .font(.subheadline)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                Text("Current 2FA Code")
                    .font(.footnote).fontWeight(.semibold)
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
                    .font(.footnote)
                    .foregroundColor(theme.danger)
            }

            Button { Task { await regenerateCodes() } } label: {
                HStack {
                    if isProcessing { ProgressView() }
                    else { Text("Regenerate Codes") }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(theme.accentLight)
            .disabled(totpCode.count != 6 || isProcessing)

            Button { withAnimation { page = .menu } } label: {
                Text("Back")
                    .font(.subheadline)
                    .foregroundColor(theme.textTertiary)
            }
        }
    }

    // MARK: - Recovery Codes

    private var recoveryCodesPage: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 8)

            Image(systemName: "list.bullet.rectangle.portrait.fill")
                .font(.largeTitle)
                .foregroundColor(theme.warning)

            VStack(spacing: 6) {
                Text("New Recovery Codes")
                    .font(.title3).fontWeight(.bold).fontDesign(.rounded)
                    .foregroundColor(theme.textPrimary)
                Text("Your old recovery codes are now invalid. Save these new codes somewhere safe.")
                    .font(.footnote)
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 0) {
                ForEach(Array(recoveryCodes.enumerated()), id: \.offset) { i, code in
                    HStack {
                        Text("\(i + 1).")
                            .font(.caption)
                            .foregroundColor(theme.textTertiary)
                            .frame(width: 20, alignment: .trailing)
                        Text(code)
                            .font(.subheadline).fontWeight(.semibold).fontDesign(.monospaced)
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
                        .font(.subheadline).fontWeight(.medium)
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
                    .font(.largeTitle)
                    .foregroundColor(theme.warning)
            }
            .shadow(color: theme.warning.opacity(0.3), radius: 20)

            Text("Two-factor auth disabled")
                .font(.title3).fontWeight(.bold).fontDesign(.rounded)
                .foregroundColor(theme.textPrimary)

            Text("Your account is no longer protected by two-factor authentication. You can re-enable it from Settings.")
                .font(.subheadline)
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
        } catch is CancellationError {
            await MainActor.run { isProcessing = false }
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
        } catch is CancellationError {
            await MainActor.run { isProcessing = false }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isProcessing = false
            }
        }
    }
}
