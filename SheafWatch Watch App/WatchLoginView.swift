import SwiftUI

struct WatchLoginView: View {
    @EnvironmentObject var authManager: WatchAuthManager
    @State private var baseURL  = ""
    @State private var email    = ""
    @State private var password = ""
    @State private var error    = ""
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Icon
                Image(systemName: "sparkles")
                    .font(.system(size: 28))
                    .foregroundColor(.purple)

                Text("Sheaf")
                    .font(.system(size: 17, weight: .bold, design: .rounded))

                TextField("API URL", text: $baseURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                SecureField("Password", text: $password)

                if !error.isEmpty {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task { await connect() }
                } label: {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Sign In")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .disabled(baseURL.isEmpty || email.isEmpty || password.isEmpty || isLoading)
            }
            .padding()
        }
    }

    private func connect() async {
        var clean = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasSuffix("/") { clean = String(clean.dropLast()) }
        guard clean.lowercased().hasPrefix("http") else {
            error = "URL must start with http(s)://"
            return
        }
        isLoading = true
        error = ""
        let tempAuth = WatchAuthManager()
        tempAuth.baseURL = clean
        let api = WatchAPIClient(auth: tempAuth)
        do {
            let tokens = try await api.login(email: email, password: password)
            await MainActor.run {
                authManager.save(baseURL: clean,
                                 accessToken: tokens.accessToken,
                                 refreshToken: tokens.refreshToken)
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
