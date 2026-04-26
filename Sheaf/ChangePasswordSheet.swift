import SwiftUI

struct ChangePasswordSheet: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var store: SystemStore

    let totpEnabled: Bool

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
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
                        Text("All other sessions will be revoked when you change your password.")
                            .font(.subheadline)
                            .foregroundColor(theme.textSecondary)
                            .padding(.horizontal, 4)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current Password")
                                .font(.footnote).fontWeight(.semibold)
                                .foregroundColor(theme.textSecondary)
                            SecureField("Enter current password", text: $currentPassword)
                                .textContentType(.password)
                                .padding(14)
                                .background(theme.inputBackground)
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12)
                                    .stroke(theme.inputBorder, lineWidth: 1.5))
                                .foregroundColor(theme.textPrimary)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("New Password")
                                .font(.footnote).fontWeight(.semibold)
                                .foregroundColor(theme.textSecondary)
                            SecureField("At least 8 characters", text: $newPassword)
                                .textContentType(.newPassword)
                                .padding(14)
                                .background(theme.inputBackground)
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12)
                                    .stroke(theme.inputBorder, lineWidth: 1.5))
                                .foregroundColor(theme.textPrimary)
                        }

                        if !newPassword.isEmpty {
                            PasswordStrengthBar(password: newPassword)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Confirm New Password")
                                .font(.footnote).fontWeight(.semibold)
                                .foregroundColor(theme.textSecondary)
                            SecureField("Re-enter new password", text: $confirmPassword)
                                .textContentType(.newPassword)
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
            .navigationTitle("Change Password")
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
            .alert("Password Changed", isPresented: $showSuccess) {
                Button("OK") { dismiss() }
            } message: {
                if revokedSessions > 0 {
                    Text("Your password has been updated. \(revokedSessions) other session(s) were signed out.")
                } else {
                    Text("Your password has been updated successfully.")
                }
            }
        }
        .presentationDetents([.large])
    }

    private var canSave: Bool {
        !currentPassword.isEmpty && newPassword.count >= 8 && newPassword == confirmPassword
    }

    private func save() async {
        guard newPassword == confirmPassword else {
            error = "Passwords don't match"
            return
        }
        guard newPassword.count >= 8 else {
            error = "New password must be at least 8 characters"
            return
        }
        guard let api = store.api else { return }
        isSaving = true
        error = ""
        do {
            let revoked = try await api.changePassword(
                currentPassword: currentPassword,
                newPassword: newPassword,
                totpCode: totpCode.isEmpty ? nil : totpCode
            )
            _ = try? await api.refreshTokens()
            await MainActor.run {
                revokedSessions = revoked
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
