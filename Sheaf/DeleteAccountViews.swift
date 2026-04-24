import SwiftUI

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
                            .font(.subheadline)
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
                                    .font(.footnote).fontWeight(.semibold)
                                    .foregroundColor(theme.textSecondary)
                                SecureField("Password", text: $password)
                                    .textInputAutocapitalization(.never)
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
                                        .font(.footnote).fontWeight(.semibold)
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
                                .font(.footnote)
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
                                .font(.body).fontWeight(.semibold)
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
                    .font(.title3)
                    .foregroundColor(selectedLevel == level ? theme.accentLight : theme.textTertiary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundColor(theme.textPrimary)
                    Text(desc)
                        .font(.caption)
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
                                .font(.largeTitle)
                                .foregroundColor(theme.danger)

                            Text("Delete Your Account")
                                .font(.title3).fontWeight(.bold)
                                .foregroundColor(theme.textPrimary)

                            if let days = authManager.deletionGraceDays {
                                Text("This will schedule your account for deletion. After \(days) days, all your data — members, fronting history, groups, and files — will be permanently removed.")
                                    .font(.subheadline)
                                    .foregroundColor(theme.textSecondary)
                                    .multilineTextAlignment(.center)
                            } else {
                                Text("This will schedule your account for deletion. All your data — members, fronting history, groups, and files — will be permanently removed.")
                                    .font(.subheadline)
                                    .foregroundColor(theme.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.top, 20)
                        .padding(.horizontal, 24)

                        VStack(spacing: 16) {
                            // Password field
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Password")
                                    .font(.footnote).fontWeight(.medium)
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
                                        .font(.footnote).fontWeight(.medium)
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
                                    .font(.footnote)
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
                                    .font(.body).fontWeight(.semibold)
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
                if let days = authManager.deletionGraceDays {
                    Text("This action cannot be easily undone. Your account and all associated data will be permanently deleted after \(days) days.")
                } else {
                    Text("This action cannot be easily undone. Your account and all associated data will be scheduled for permanent deletion.")
                }
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
        } catch is CancellationError {
            isDeleting = false
        } catch {
            errorMessage = error.localizedDescription
            isDeleting = false
        }
    }
}
