import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var baseURL  = ""
    @State private var email    = ""
    @State private var password = ""
    @State private var error    = ""
    @State private var isLoading = false
    @FocusState private var focusedField: Field?

    enum Field { case url, email, password }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#0F0C29") ?? .black,
                         Color(hex: "#302B63") ?? .indigo,
                         Color(hex: "#24243E") ?? .black],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 80)

                    // Logo
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [Color(hex: "#A78BFA") ?? .purple, Color(hex: "#6366F1") ?? .indigo],
                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 80, height: 80)
                            Text("✦")
                                .font(.system(size: 36))
                                .foregroundColor(.white)
                        }
                        .shadow(color: Color(hex: "#A78BFA")!.opacity(0.6), radius: 20)

                        Text("Sheaf")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("Sign in to your system")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.55))
                    }

                    Spacer().frame(height: 48)

                    // Form card
                    VStack(spacing: 20) {
                        formField(icon: "link", label: "API Base URL",
                                  placeholder: "https://your-api.example.com",
                                  value: $baseURL, field: .url, keyboard: .URL)

                        formField(icon: "envelope.fill", label: "Email",
                                  placeholder: "you@example.com",
                                  value: $email, field: .email, keyboard: .emailAddress)

                        secureField(icon: "lock.fill", label: "Password",
                                    placeholder: "••••••••", value: $password)

                        if !error.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(Color(hex: "#F87171")!)
                                Text(error)
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "#F87171")!)
                            }
                            .padding(.horizontal, 4)
                        }

                        Button { connect() } label: {
                            HStack {
                                if isLoading { ProgressView().tint(.white) }
                                else {
                                    Text("Sign In")
                                        .font(.system(size: 17, weight: .semibold))
                                    Image(systemName: "arrow.right")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "#A78BFA") ?? .purple, Color(hex: "#6366F1") ?? .indigo],
                                    startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(14)
                            .shadow(color: Color(hex: "#A78BFA")!.opacity(0.4), radius: 12, y: 4)
                        }
                        .disabled(baseURL.isEmpty || email.isEmpty || password.isEmpty || isLoading)
                        .opacity((baseURL.isEmpty || email.isEmpty || password.isEmpty) ? 0.5 : 1)
                    }
                    .padding(24)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(24)
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 60)
                }
            }
        }
    }

    private func formField(icon: String, label: String, placeholder: String,
                           value: Binding<String>, field: Field, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(label, systemImage: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
            TextField(placeholder, text: value)
                .focused($focusedField, equals: field)
                .keyboardType(keyboard)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .padding(14)
                .background(Color.white.opacity(0.08))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(focusedField == field ? Color(hex: "#A78BFA")! : Color.white.opacity(0.15), lineWidth: 1.5))
                .foregroundColor(.white)
        }
    }

    private func secureField(icon: String, label: String, placeholder: String, value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(label, systemImage: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
            SecureField(placeholder, text: value)
                .focused($focusedField, equals: .password)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .padding(14)
                .background(Color.white.opacity(0.08))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(focusedField == .password ? Color(hex: "#A78BFA")! : Color.white.opacity(0.15), lineWidth: 1.5))
                .foregroundColor(.white)
        }
    }

    private func connect() {
        guard !baseURL.isEmpty, !email.isEmpty, !password.isEmpty else { return }
        error = ""

        var cleanURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanURL.hasSuffix("/") { cleanURL = String(cleanURL.dropLast()) }

        guard cleanURL.lowercased().hasPrefix("http") else {
            error = "URL must start with http:// or https://"
            return
        }
        guard URL(string: cleanURL + "/v1/auth/login") != nil else {
            error = "Invalid URL — check for spaces or special characters"
            return
        }

        isLoading = true

        // Use a temporary AuthManager so we never flip isAuthenticated until login succeeds
        let tempAuth = AuthManager()
        tempAuth.baseURL = cleanURL
        let api = APIClient(auth: tempAuth)

        Task {
            do {
                let tokens = try await api.login(email: email, password: password)
                // Briefly apply token so we can call /auth/me to check TOTP status
                tempAuth.accessToken = tokens.accessToken
                let me = try await api.getMe()
                await MainActor.run {
                    if me.totpEnabled {
                        // Park credentials — show TOTP screen before finalising
                        authManager.awaitTOTP(baseURL: cleanURL, tokens: tokens)
                    } else {
                        authManager.save(baseURL: cleanURL, tokens: tokens)
                    }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}
