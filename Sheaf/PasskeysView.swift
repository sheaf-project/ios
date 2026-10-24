import SwiftUI

// MARK: - Passkeys

struct PasskeysView: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    let totpEnabled: Bool

    @State private var passkeys: [PasskeyRead] = []
    @State private var isLoading = true
    @State private var unavailable = false
    @State private var error: String?
    @State private var showAdd = false
    @State private var renaming: PasskeyRead?
    @State private var renameText = ""
    @State private var showRename = false
    @State private var removing: PasskeyRead?
    @State private var showRemove = false

    var body: some View {
        List {
            Section {
                Text("Sign in with your face, fingerprint, passcode, or a hardware key instead of typing your password. Your password keeps working, and deleting a member or publishing your profile will still ask for it.")
                    .font(.footnote)
                    .foregroundColor(theme.textSecondary)
                    .listRowBackground(Color.clear)
            }

            if let error {
                Section {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(theme.danger)
                        .listRowBackground(theme.backgroundCard)
                }
            }

            if unavailable {
                Section {
                    Text("This server doesn't offer passkeys.")
                        .font(.subheadline)
                        .foregroundColor(theme.textTertiary)
                        .listRowBackground(theme.backgroundCard)
                }
            } else if isLoading {
                Section {
                    HStack { Spacer(); ProgressView().tint(theme.accentLight); Spacer() }
                        .listRowBackground(Color.clear)
                }
            } else {
                Section {
                    if passkeys.isEmpty {
                        Text("No passkeys yet")
                            .font(.subheadline)
                            .foregroundColor(theme.textTertiary)
                            .frame(maxWidth: .infinity)
                            .listRowBackground(Color.clear)
                    }
                    ForEach(passkeys) { key in
                        row(key)
                            .listRowBackground(theme.backgroundCard)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    removing = key
                                    showRemove = true
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    renaming = key
                                    renameText = key.nickname ?? ""
                                    showRename = true
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                .tint(theme.accentLight)
                            }
                    }
                }

                Section {
                    Button { showAdd = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                            Text("Add a passkey")
                        }
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundColor(theme.accentLight)
                    }
                    .listRowBackground(theme.backgroundCard)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.backgroundPrimary)
        .navigationTitle("Passkeys")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(isPresented: $showAdd) {
            AddPasskeySheet(totpEnabled: totpEnabled) { key in
                passkeys.append(key)
            }
            .environmentObject(store)
        }
        .alert("Rename passkey", isPresented: $showRename) {
            TextField("Name", text: $renameText)
            Button("Save") { Task { await rename() } }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Remove passkey?", isPresented: $showRemove, presenting: removing) { key in
            Button("Remove", role: .destructive) { Task { await remove(key) } }
            Button("Cancel", role: .cancel) {}
        } message: { key in
            Text("\(key.nickname ?? String(localized: "This passkey")) will no longer sign in to your account. Your password is not affected.")
        }
    }

    private func row(_ key: PasskeyRead) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: key.usable ? "key.fill" : "key.slash")
                .foregroundColor(key.usable ? theme.accentLight : theme.danger)
                .frame(width: 20)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(key.nickname ?? String(localized: "Passkey"))
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundColor(theme.textPrimary)
                Text(key.backupEligible ? "Synced passkey" : "Single-device key")
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
                HStack(spacing: 4) {
                    Text("Added \(key.createdAt.formatted(date: .abbreviated, time: .omitted))")
                    Text("·")
                    if let used = key.lastUsedAt {
                        Text("last used \(used.formatted(date: .abbreviated, time: .omitted))")
                    } else {
                        Text("never used")
                    }
                }
                .font(.caption)
                .foregroundColor(theme.textTertiary)
                if !key.usable {
                    Text("Created for \(key.rpID), a previous address of this server, so it no longer works. Remove it and add a new one.")
                        .font(.caption)
                        .foregroundColor(theme.danger)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func load() async {
        guard let api = store.api else { return }
        isLoading = true
        if let config = try? await api.getAuthConfig(),
           config["passkeys_available"] as? Bool == false {
            unavailable = true
            isLoading = false
            return
        }
        do {
            passkeys = try await api.getPasskeys()
        } catch {
            if (error as NSError).code == 404 {
                unavailable = true
            } else {
                self.error = error.userFacingMessage ?? String(localized: "Failed to load passkeys")
            }
        }
        isLoading = false
    }

    private func rename() async {
        guard let api = store.api, let key = renaming else { return }
        let name = renameText.trimmingCharacters(in: .whitespaces)
        do {
            let updated = try await api.renamePasskey(id: key.id, nickname: name.isEmpty ? nil : name)
            if let i = passkeys.firstIndex(where: { $0.id == updated.id }) {
                passkeys[i] = updated
            }
        } catch {
            self.error = error.userFacingMessage ?? String(localized: "Failed to rename passkey")
        }
    }

    private func remove(_ key: PasskeyRead) async {
        guard let api = store.api else { return }
        do {
            try await api.deletePasskey(id: key.id)
            passkeys.removeAll { $0.id == key.id }
        } catch {
            self.error = error.userFacingMessage ?? String(localized: "Failed to remove passkey")
        }
    }
}

// MARK: - Add Passkey Sheet

struct AddPasskeySheet: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    let totpEnabled: Bool
    let onAdded: (PasskeyRead) -> Void

    @State private var password = ""
    @State private var code = ""
    @State private var nickname = ""
    @State private var isWorking = false
    @State private var error: String?
    @State private var authenticator = PasskeyAuthenticator()

    private var canContinue: Bool {
        !password.isEmpty && (!totpEnabled || !code.trimmingCharacters(in: .whitespaces).isEmpty) && !isWorking
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(totpEnabled
                         ? "Confirm it's you with your password and two-factor code."
                         : "Confirm it's you with your password.")
                        .font(.footnote)
                        .foregroundColor(theme.textSecondary)
                        .listRowBackground(Color.clear)
                }
                Section {
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .listRowBackground(theme.backgroundCard)
                    if totpEnabled {
                        TextField("Two-factor or recovery code", text: $code)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .listRowBackground(theme.backgroundCard)
                    }
                    TextField("Name (optional)", text: $nickname, prompt: Text("e.g. My phone"))
                        .onChange(of: nickname) { _, v in
                            if v.count > 128 { nickname = String(v.prefix(128)) }
                        }
                        .listRowBackground(theme.backgroundCard)
                }
                if let error {
                    Section {
                        Text(error)
                            .font(.footnote)
                            .foregroundColor(theme.danger)
                            .listRowBackground(theme.backgroundCard)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.backgroundPrimary)
            .navigationTitle("Add a passkey")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isWorking)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(theme.accentLight)
                        .disabled(isWorking)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await add() }
                    } label: {
                        if isWorking {
                            ProgressView().tint(theme.accentLight)
                        } else {
                            Text("Continue")
                                .fontWeight(.semibold)
                                .foregroundColor(canContinue ? theme.accentLight : theme.textTertiary)
                        }
                    }
                    .disabled(!canContinue)
                }
            }
        }
    }

    private func add() async {
        guard let api = store.api else { return }
        isWorking = true
        error = nil
        do {
            let trimmedCode = code.trimmingCharacters(in: .whitespaces)
            let options = try await api.beginPasskeyRegistration(
                password: password,
                totpCode: totpEnabled && !trimmedCode.isEmpty ? trimmedCode : nil
            )
            let credential = try await authenticator.register(options: options)
            let name = nickname.trimmingCharacters(in: .whitespaces)
            let created = try await api.completePasskeyRegistration(credential: credential, nickname: name.isEmpty ? nil : name)
            onAdded(created)
            dismiss()
        } catch PasskeyError.cancelled {
            // Left the sheet open so they can try again.
        } catch {
            let ns = error as NSError
            if ns.domain == "APIError", ns.code == 401 {
                let text = ns.localizedDescription.lowercased()
                if text.contains("password") {
                    self.error = String(localized: "Incorrect password")
                } else if text.contains("required") {
                    self.error = String(localized: "Enter your two-factor code")
                } else {
                    self.error = String(localized: "Invalid two-factor code")
                }
            } else {
                self.error = error.userFacingMessage ?? String(localized: "Couldn't add the passkey")
            }
        }
        isWorking = false
    }
}
