import SwiftUI

struct ChangeEmailSheet: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var store: SystemStore

    let totpEnabled: Bool

    @State private var newEmail = ""
    @State private var password = ""
    @State private var totpCode = ""
    @State private var isSaving = false
    @State private var error = ""
    @State private var showSuccess = false
    @State private var revokedSessions = 0

    var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        Text("You will need to re-verify your new email address. All other sessions will be revoked.")
                            .font(.subheadline)
                            .foregroundColor(theme.textSecondary)
                            .padding(.horizontal, 4)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("New Email")
                                .font(.footnote).fontWeight(.semibold)
                                .foregroundColor(theme.textSecondary)
                            TextField("you@example.com", text: $newEmail)
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(14)
                                .background(theme.inputBackground)
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12)
                                    .stroke(theme.inputBorder, lineWidth: 1.5))
                                .foregroundColor(theme.textPrimary)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current Password")
                                .font(.footnote).fontWeight(.semibold)
                                .foregroundColor(theme.textSecondary)
                            SecureField("Enter your password", text: $password)
                                .textContentType(.password)
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
                                    .font(.footnote).fontWeight(.semibold)
                                    .foregroundColor(theme.textSecondary)
                                TextField("6-digit code", text: $totpCode)
                                    .keyboardType(.numberPad)
                                    .textContentType(.oneTimeCode)
                                    .padding(14)
                                    .background(theme.inputBackground)
                                    .cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12)
                                        .stroke(theme.inputBorder, lineWidth: 1.5))
                                    .foregroundColor(theme.textPrimary)
                            }
                        }

                        if !error.isEmpty {
                            Text(error)
                                .font(.footnote)
                                .foregroundColor(theme.danger)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Change Email")
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
                                .font(.body).fontWeight(.semibold)
                                .foregroundColor(canSave ? theme.accentLight : theme.textTertiary)
                        }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
            .alert("Email Changed", isPresented: $showSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("A verification email has been sent to \(newEmail). Please check your inbox.")
            }
        }
        .presentationDetents([.large])
    }

    private var canSave: Bool {
        !newEmail.isEmpty && newEmail.contains("@") && !password.isEmpty
    }

    private func save() async {
        guard let api = store.api else { return }
        isSaving = true
        error = ""
        do {
            let revoked = try await api.changeEmail(
                newEmail: newEmail.trimmingCharacters(in: .whitespacesAndNewlines),
                currentPassword: password,
                totpCode: totpCode.isEmpty ? nil : totpCode
            )
            _ = try? await api.refreshTokens()
            await MainActor.run {
                revokedSessions = revoked
                authManager.emailVerified = false
                isSaving = false
                showSuccess = true
            }
        } catch is CancellationError {
            await MainActor.run { isSaving = false }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isSaving = false
            }
        }
    }
}
