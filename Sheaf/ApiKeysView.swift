import SwiftUI

// MARK: - API Keys View
struct ApiKeysView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var store: SystemStore

    @State private var keys: [ApiKeyRead] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var showCreate = false
    @State private var createdKey: ApiKeyCreated?
    @State private var showCreatedAlert = false
    @State private var copiedKey = false

    var body: some View {
        ZStack {
            theme.backgroundPrimary.ignoresSafeArea()

            if isLoading {
                ProgressView().tint(theme.accentLight)
            } else if keys.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "key.horizontal.fill")
                        .font(.largeTitle)
                        .foregroundColor(theme.textTertiary)
                    Text("No API Keys")
                        .font(.body).fontWeight(.semibold)
                        .foregroundColor(theme.textPrimary)
                    Text("Create an API key to access the Sheaf API programmatically.")
                        .font(.subheadline)
                        .foregroundColor(theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            } else {
                List {
                    ForEach(keys) { key in
                        apiKeyRow(key)
                            .listRowBackground(theme.backgroundCard)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 5, leading: 24, bottom: 5, trailing: 24))
                    }
                    .onDelete { indexSet in
                        Task {
                            for index in indexSet {
                                let key = keys[index]
                                try? await store.api?.revokeApiKey(id: key.id)
                            }
                            keys.remove(atOffsets: indexSet)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("API Keys")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreate = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(theme.accentLight)
                }
            }
        }
        .task { await loadKeys() }
        .sheet(isPresented: $showCreate, onDismiss: { Task { await loadKeys() } }) {
            CreateApiKeySheet { created in
                createdKey = created
                showCreate = false
                showCreatedAlert = true
                Task { await loadKeys() }
            }
            .environmentObject(authManager)
            .environmentObject(store)
        }
        .sheet(isPresented: $showCreatedAlert) {
            if let created = createdKey {
                apiKeyCreatedSheet(created)
            }
        }
    }

    private func loadKeys() async {
        guard let api = store.api else { return }
        isLoading = true
        keys = (try? await api.listApiKeys()) ?? []
        isLoading = false
    }

    private func apiKeyRow(_ key: ApiKeyRead) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(key.name)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(theme.textPrimary)
                Spacer()
                if let expires = key.expiresAt {
                    if expires < Date() {
                        Text("Expired")
                            .font(.caption2).fontWeight(.medium)
                            .foregroundColor(theme.danger)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(theme.danger.opacity(0.12))
                            .cornerRadius(6)
                    } else {
                        Text("Expires \(expires, style: .relative)")
                            .font(.caption2)
                            .foregroundColor(theme.textTertiary)
                    }
                }
            }

            // Scopes
            if !key.scopes.isEmpty {
                HStack(spacing: 6) {
                    ForEach(key.scopes, id: \.self) { scope in
                        Text(scope)
                            .font(.caption2).fontWeight(.medium).fontDesign(.monospaced)
                            .foregroundColor(theme.accentLight)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(theme.accentLight.opacity(0.1))
                            .cornerRadius(6)
                    }
                }
            }

            HStack(spacing: 16) {
                if let lastUsed = key.lastUsedAt {
                    Label("Used \(lastUsed, style: .relative) ago", systemImage: "clock")
                        .font(.caption2)
                        .foregroundColor(theme.textTertiary)
                } else {
                    Label("Never used", systemImage: "clock")
                        .font(.caption2)
                        .foregroundColor(theme.textTertiary)
                }
                Spacer()
                Text("Created \(key.createdAt, style: .date)")
                    .font(.caption2)
                    .foregroundColor(theme.textTertiary)
            }
        }
        .padding(14)
        .background(theme.backgroundCard)
        .cornerRadius(14)
    }

    private func apiKeyCreatedSheet(_ created: ApiKeyCreated) -> some View {
        ZStack {
            theme.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "key.horizontal.fill")
                    .font(.largeTitle)
                    .foregroundColor(theme.success)
                    .padding(.top, 8)

                Text("API Key Created")
                    .font(.title2).fontWeight(.bold).fontDesign(.rounded)
                    .foregroundColor(theme.textPrimary)

                Text("Copy this key now. You won't be able to see it again.")
                    .font(.subheadline)
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                VStack(spacing: 8) {
                    Text(created.key)
                        .font(.footnote).fontWeight(.medium).fontDesign(.monospaced)
                        .foregroundColor(theme.textPrimary)
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(theme.backgroundCard)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.border, lineWidth: 1))

                    Button {
                        UIPasteboard.general.string = created.key
                        copiedKey = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedKey = false }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: copiedKey ? "checkmark" : "doc.on.doc")
                            Text(copiedKey ? "Copied!" : "Copy Key")
                                .font(.subheadline).fontWeight(.medium)
                        }
                        .foregroundColor(copiedKey ? theme.success : theme.accentLight)
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(theme.backgroundCard)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                Button {
                    showCreatedAlert = false
                    createdKey = nil
                } label: {
                    Text("Done")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(theme.accentLight)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Create API Key Sheet
struct CreateApiKeySheet: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var store: SystemStore
    @Environment(\.dismiss) var dismiss

    let onCreate: (ApiKeyCreated) -> Void

    @State private var name = ""
    @State private var selectedScopes: Set<String> = []
    @State private var hasExpiry = false
    @State private var expiresAt = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var isCreating = false
    @State private var error: String?

    private let availableScopes = [
        "members:read", "members:write",
        "fronts:read", "fronts:write",
        "groups:read", "groups:write",
        "system:read", "system:write",
        "fields:read", "fields:write",
        "tags:read", "tags:write",
        "files:read", "files:write",
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Name
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Name")
                                .font(.footnote).fontWeight(.semibold)
                                .foregroundColor(theme.textSecondary)
                            TextField("My API Key", text: $name)
                                .autocorrectionDisabled()
                                .padding(12)
                                .background(theme.backgroundCard)
                                .cornerRadius(12)
                                .foregroundColor(theme.textPrimary)
                        }

                        // Scopes
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Scopes")
                                .font(.footnote).fontWeight(.semibold)
                                .foregroundColor(theme.textSecondary)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                ForEach(availableScopes, id: \.self) { scope in
                                    Button {
                                        if selectedScopes.contains(scope) {
                                            selectedScopes.remove(scope)
                                        } else {
                                            selectedScopes.insert(scope)
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: selectedScopes.contains(scope) ? "checkmark.circle.fill" : "circle")
                                                .font(.subheadline)
                                                .foregroundColor(selectedScopes.contains(scope) ? theme.accentLight : theme.textTertiary)
                                            Text(scope)
                                                .font(.caption).fontWeight(.medium).fontDesign(.monospaced)
                                                .foregroundColor(theme.textPrimary)
                                                .lineLimit(1)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 10).padding(.vertical, 8)
                                        .background(selectedScopes.contains(scope)
                                                     ? theme.accentLight.opacity(0.1)
                                                     : theme.backgroundCard)
                                        .cornerRadius(10)
                                        .overlay(RoundedRectangle(cornerRadius: 10)
                                            .stroke(selectedScopes.contains(scope)
                                                    ? theme.accentLight.opacity(0.3)
                                                    : theme.border, lineWidth: 1))
                                    }
                                }
                            }
                        }

                        // Expiry
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle(isOn: $hasExpiry) {
                                Text("Set Expiry")
                                    .font(.subheadline).fontWeight(.medium)
                                    .foregroundColor(theme.textPrimary)
                            }
                            .tint(theme.accentLight)

                            if hasExpiry {
                                DatePicker("Expires", selection: $expiresAt,
                                           in: Date()...,
                                           displayedComponents: [.date])
                                    .datePickerStyle(.compact)
                                    .tint(theme.accentLight)
                                    .foregroundColor(theme.textPrimary)
                            }
                        }
                        .padding(14)
                        .background(theme.backgroundCard)
                        .cornerRadius(12)

                        if let error {
                            Text(error)
                                .font(.footnote)
                                .foregroundColor(theme.danger)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 80)
                }
            }
            .navigationTitle("Create API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(theme.accentLight)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await createKey() }
                    } label: {
                        if isCreating {
                            ProgressView().tint(theme.accentLight)
                        } else {
                            Text("Create")
                                .fontWeight(.semibold)
                                .foregroundColor(canCreate ? theme.accentLight : theme.textTertiary)
                        }
                    }
                    .disabled(!canCreate || isCreating)
                }
            }
        }
    }

    private var canCreate: Bool {
        !name.isEmpty && !selectedScopes.isEmpty
    }

    private func createKey() async {
        guard let api = store.api else { return }
        isCreating = true
        error = nil
        do {
            let create = ApiKeyCreate(
                name: name,
                scopes: Array(selectedScopes).sorted(),
                expiresAt: hasExpiry ? expiresAt : nil
            )
            let created = try await api.createApiKey(create)
            await MainActor.run {
                isCreating = false
                onCreate(created)
            }
        } catch is CancellationError {
            await MainActor.run { isCreating = false }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isCreating = false
            }
        }
    }
}
