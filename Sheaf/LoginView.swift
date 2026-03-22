import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.theme) var theme
    @State private var isRegistering = false

    var body: some View {
        ZStack {
            theme.loginGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 80)

                    // Logo
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [theme.accentLight, theme.accent],
                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 80, height: 80)
                            Text("✦")
                                .font(.system(size: 36))
                                .foregroundColor(.white)
                        }
                        .shadow(color: theme.accentLight.opacity(0.6), radius: 20)

                        Text("Sheaf")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(theme.textPrimary)

                        Text(isRegistering ? String(localized: "Create your account") : String(localized: "Sign in to your system"))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(theme.textSecondary)
                            .animation(.default, value: isRegistering)
                    }

                    Spacer().frame(height: 48)

                    // Form card — swaps between sign in and register
                    if isRegistering {
                        RegisterForm(onSwitch: { isRegistering = false })
                    } else {
                        SignInForm(onSwitch: { isRegistering = true })
                    }

                    Spacer().frame(height: 60)
                }
            }
        }
    }
}

// MARK: - Sign In Form
struct SignInForm: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.theme) var theme
    let onSwitch: () -> Void

    @State private var baseURL  = ""
    @State private var email    = ""
    @State private var password = ""
    @State private var totpCode = ""
    @State private var error    = ""
    @State private var isLoading = false
    @State private var needsTOTP = false
    @FocusState private var focused: Field?
    enum Field { case url, email, password, totp }

    var body: some View {
        VStack(spacing: 20) {
            formField(icon: "link",         label: String(localized: "API Base URL"),  placeholder: String(localized: "https://your-server.com"), value: $baseURL,   field: .url,      keyboard: .URL)
            formField(icon: "envelope.fill", label: String(localized: "Email"),         placeholder: String(localized: "you@example.com"),              value: $email,    field: .email,    keyboard: .emailAddress)
            secureField(                     label: String(localized: "Password"),       placeholder: String(localized: "••••••••"),                     value: $password, field: .password)
            
            // Show TOTP field if needed
            if needsTOTP {
                formField(icon: "lock.shield", label: "2FA Code", placeholder: "000000", value: $totpCode, field: .totp, keyboard: .numberPad)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if !error.isEmpty { errorLabel(error) }

            // Sign In button
            Button { signIn() } label: {
                buttonContent(label: String(localized: "Sign In"), icon: "arrow.right", loading: isLoading)
            }
            .disabled(baseURL.isEmpty || email.isEmpty || password.isEmpty || isLoading || (needsTOTP && totpCode.count != 6))
            .opacity(baseURL.isEmpty || email.isEmpty || password.isEmpty || (needsTOTP && totpCode.count != 6) ? 0.5 : 1)

            // Switch to register
            Button(action: onSwitch) {
                HStack(spacing: 4) {
                    Text("Don't have an account?")
                        .foregroundColor(theme.textSecondary)
                    Text("Register")
                        .foregroundColor(theme.accentLight)
                        .fontWeight(.semibold)
                }
                .font(.system(size: 14))
            }
        }
        .padding(24)
        .background(theme.backgroundCard)
        .cornerRadius(24)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(theme.border, lineWidth: 1))
        .padding(.horizontal, 24)
    }

    private func signIn() {
        error = ""
        var cleanURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanURL.hasSuffix("/") { cleanURL = String(cleanURL.dropLast()) }
        guard cleanURL.lowercased().hasPrefix("http") else { error = String(localized: "URL must start with http:// or https://"); return }
        guard URL(string: cleanURL + "/v1/auth/login") != nil else { error = String(localized: "Invalid URL"); return }
        isLoading = true
        let tempAuth = AuthManager()
        tempAuth.baseURL = cleanURL
        let api = APIClient(auth: tempAuth)
        Task {
            do {
                NSLog("📱 Login: Starting login request... (TOTP: \(totpCode.isEmpty ? "no" : "yes"))")
                // Pass TOTP code if available
                let tokens = try await api.login(email: email, password: password, totpCode: totpCode.isEmpty ? nil : totpCode)
                NSLog("📱 Login: Login successful, got tokens")
                
                // Login succeeded, save credentials
                await MainActor.run {
                    authManager.save(baseURL: cleanURL, tokens: tokens)
                    isLoading = false
                }
            } catch let loginError as NSError {
                // Check if login failed due to TOTP requirement
                let errorMessage = loginError.localizedDescription.lowercased()
                NSLog("📱 Login: Login failed")
                NSLog("📱 Login: Error message: \(loginError.localizedDescription)")
                
                if errorMessage.contains("totp") || errorMessage.contains("code required") {
                    // The server requires TOTP - show the TOTP field
                    NSLog("📱 Login: TOTP required, showing 2FA field")
                    await MainActor.run {
                        withAnimation {
                            needsTOTP = true
                        }
                        error = "Please enter your 6-digit authenticator code"
                        focused = .totp
                        isLoading = false
                    }
                } else {
                    // Some other error - show it
                    NSLog("📱 Login: Other login error, showing to user")
                    await MainActor.run {
                        error = loginError.localizedDescription
                        isLoading = false
                    }
                }
            }
        }
    }

    // MARK: Shared helpers
    func formField(icon: String, label: String, placeholder: String,
                   value: Binding<String>, field: Field, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(label, systemImage: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.textSecondary)
            TextField(placeholder, text: value)
                .focused($focused, equals: field)
                .keyboardType(keyboard)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .padding(14)
                .background(theme.inputBackground)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(focused == field ? theme.accentLight : theme.inputBorder, lineWidth: 1.5))
                .foregroundColor(theme.textPrimary)
        }
    }

    func secureField(label: String, placeholder: String, value: Binding<String>, field: Field) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(label, systemImage: "lock.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.textSecondary)
            SecureField(placeholder, text: value)
                .focused($focused, equals: field)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .padding(14)
                .background(theme.inputBackground)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(focused == field ? theme.accentLight : theme.inputBorder, lineWidth: 1.5))
                .foregroundColor(theme.textPrimary)
        }
    }

    func errorLabel(_ msg: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(theme.danger)
            Text(msg).font(.system(size: 13)).foregroundColor(theme.danger)
        }
        .padding(.horizontal, 4)
    }

    func buttonContent(label: String, icon: String, loading: Bool) -> some View {
        HStack {
            if loading { ProgressView().tint(.white) }
            else {
                Text(label).font(.system(size: 17, weight: .semibold))
                Image(systemName: icon)
            }
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(LinearGradient(colors: [theme.accentLight, theme.accent],
                                   startPoint: .leading, endPoint: .trailing))
        .cornerRadius(14)
        .shadow(color: theme.accentLight.opacity(0.4), radius: 12, y: 4)
    }
}

// MARK: - Register Form
struct RegisterForm: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.theme) var theme
    let onSwitch: () -> Void

    @State private var baseURL          = ""
    @State private var email            = ""
    @State private var password         = ""
    @State private var confirmPassword  = ""
    @State private var error            = ""
    @State private var isLoading        = false
    @FocusState private var focused: Field?
    enum Field { case url, email, password, confirm }

    var body: some View {
        VStack(spacing: 20) {
            formField(icon: "link",          label: String(localized: "API Base URL"),      placeholder: String(localized: "https://your-server.com"), value: $baseURL,         field: .url,     keyboard: .URL)
            formField(icon: "envelope.fill", label: String(localized: "Email"),              placeholder: String(localized: "you@example.com"),              value: $email,           field: .email,   keyboard: .emailAddress)
            secureField(                     label: String(localized: "Password"),            placeholder: String(localized: "At least 8 characters"),        value: $password,        field: .password)
            secureField(                     label: String(localized: "Confirm Password"),    placeholder: String(localized: "••••••••"),                     value: $confirmPassword, field: .confirm)

            // Password strength indicator
            if !password.isEmpty {
                PasswordStrengthBar(password: password)
            }

            if !error.isEmpty { errorLabel(error) }

            // Register button
            Button { register() } label: {
                buttonContent(label: String(localized: "Create Account"), icon: "person.badge.plus", loading: isLoading)
            }
            .disabled(baseURL.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty || isLoading)
            .opacity(baseURL.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty ? 0.5 : 1)

            // Switch to sign in
            Button(action: onSwitch) {
                HStack(spacing: 4) {
                    Text("Already have an account?")
                        .foregroundColor(theme.textSecondary)
                    Text("Sign In")
                        .foregroundColor(theme.accentLight)
                        .fontWeight(.semibold)
                }
                .font(.system(size: 14))
            }
        }
        .padding(24)
        .background(theme.backgroundCard)
        .cornerRadius(24)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(theme.border, lineWidth: 1))
        .padding(.horizontal, 24)
    }

    private func register() {
        error = ""
        guard password == confirmPassword else { error = String(localized: "Passwords don't match"); return }
        guard password.count >= 8 else { error = String(localized: "Password must be at least 8 characters"); return }
        var cleanURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanURL.hasSuffix("/") { cleanURL = String(cleanURL.dropLast()) }
        guard cleanURL.lowercased().hasPrefix("http") else { error = String(localized: "URL must start with http:// or https://"); return }
        guard URL(string: cleanURL + "/v1/auth/register") != nil else { error = String(localized: "Invalid URL"); return }
        isLoading = true
        let tempAuth = AuthManager()
        tempAuth.baseURL = cleanURL
        let api = APIClient(auth: tempAuth)
        Task {
            do {
                let tokens = try await api.register(email: email, password: password)
                await MainActor.run {
                    authManager.save(baseURL: cleanURL, tokens: tokens)
                    isLoading = false
                }
            } catch {
                await MainActor.run { self.error = error.localizedDescription; isLoading = false }
            }
        }
    }

    func formField(icon: String, label: String, placeholder: String,
                   value: Binding<String>, field: Field, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(label, systemImage: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.textSecondary)
            TextField(placeholder, text: value)
                .focused($focused, equals: field)
                .keyboardType(keyboard)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .padding(14)
                .background(theme.inputBackground)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(focused == field ? theme.accentLight : theme.inputBorder, lineWidth: 1.5))
                .foregroundColor(theme.textPrimary)
        }
    }

    func secureField(label: String, placeholder: String, value: Binding<String>, field: Field) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(label, systemImage: "lock.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.textSecondary)
            SecureField(placeholder, text: value)
                .focused($focused, equals: field)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .padding(14)
                .background(theme.inputBackground)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(focused == field ? theme.accentLight : theme.inputBorder, lineWidth: 1.5))
                .foregroundColor(theme.textPrimary)
        }
    }

    func errorLabel(_ msg: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(theme.danger)
            Text(msg).font(.system(size: 13)).foregroundColor(theme.danger)
        }
        .padding(.horizontal, 4)
    }

    func buttonContent(label: String, icon: String, loading: Bool) -> some View {
        HStack {
            if loading { ProgressView().tint(.white) }
            else {
                Text(label).font(.system(size: 17, weight: .semibold))
                Image(systemName: icon)
            }
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(LinearGradient(colors: [theme.accentLight, theme.accent],
                                   startPoint: .leading, endPoint: .trailing))
        .cornerRadius(14)
        .shadow(color: theme.accentLight.opacity(0.4), radius: 12, y: 4)
    }
}

// MARK: - Password Strength Bar
struct PasswordStrengthBar: View {
    @Environment(\.theme) var theme
    let password: String

    private var strength: Int {
        var score = 0
        if password.count >= 8  { score += 1 }
        if password.count >= 12 { score += 1 }
        if password.range(of: "[A-Z]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[0-9]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil { score += 1 }
        return score
    }

    private var label: String {
        switch strength {
        case 0, 1: return String(localized: "Weak")
        case 2, 3: return String(localized: "Fair")
        case 4:    return String(localized: "Good")
        default:   return String(localized: "Strong")
        }
    }

    private var color: Color {
        switch strength {
        case 0, 1: return theme.danger
        case 2, 3: return theme.warning
        case 4:    return theme.accentLight
        default:   return theme.success
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i < strength ? color : theme.backgroundElevated)
                        .frame(height: 4)
                        .animation(.spring(response: 0.3), value: strength)
                }
            }
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(color)
        }
    }
}
