import SwiftUI
import PhotosUI

struct EditSystemProfileSheet: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss

    @State private var name        = ""
    @State private var description = ""
    @State private var tag         = ""
    @State private var avatarURL   = ""
    @State private var colorHex    = "#8B5CF6"
    @State private var privacy: PrivacyLevel = .private
    @State private var isSaving    = false
    @State private var error: String?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isUploadingAvatar = false
    @State private var avatarMode: AvatarInputMode = .url

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    field("System Name", placeholder: "Your system's name", value: $name)
                    field("Tag", placeholder: "Short tag, e.g. SYS", value: $tag)
                        .autocapitalization(.allCharacters)
                }

                Section("Avatar") {
                    AvatarInputSection(
                        avatarURL: $avatarURL,
                        mode: $avatarMode,
                        selectedPhoto: $selectedPhoto,
                        isUploading: $isUploadingAvatar,
                        api: store.api
                    )
                }

                Section("About") {
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                        .foregroundColor(theme.textPrimary)
                }

                Section("Display") {
                    HStack {
                        Text("Color")
                            .foregroundColor(theme.textPrimary)
                        Spacer()
                        ColorPicker("", selection: Binding(
                            get: { Color(hex: colorHex) ?? .purple },
                            set: { colorHex = $0.toHex() }
                        ))
                        .labelsHidden()
                    }

                    HStack {
                        Text("Privacy")
                            .foregroundColor(theme.textPrimary)
                        Spacer()
                        Picker("Privacy", selection: $privacy) {
                            ForEach(PrivacyLevel.allCases, id: \.self) { level in
                                Text(level.rawValue.capitalized).tag(level)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(theme.accentLight)
                    }
                }

                if let error {
                    Section {
                        Text(error)
                            .foregroundColor(theme.danger)
                            .font(.system(size: 13))
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.backgroundPrimary)
            .navigationTitle("Edit System")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(theme.accentLight)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving { ProgressView().tint(theme.accentLight) }
                        else {
                            Text("Save")
                                .fontWeight(.semibold)
                                .foregroundColor(name.isEmpty ? theme.textTertiary : theme.accentLight)
                        }
                    }
                    .disabled(name.isEmpty || isSaving)
                }
            }
        }
        .onAppear { populate() }
    }

    private func field(_ label: String, placeholder: String,
                       value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(placeholder, text: value)
                .foregroundColor(theme.textPrimary)
                .autocorrectionDisabled()
        }
    }

    private func populate() {
        guard let profile = store.systemProfile else { return }
        name        = profile.name
        description = profile.description ?? ""
        tag         = profile.tag ?? ""
        avatarURL   = profile.avatarURL ?? ""
        if avatarURL.hasPrefix("/") { avatarMode = .upload }
        colorHex    = profile.color ?? "#8B5CF6"
        privacy     = profile.privacy
    }

    private func save() async {
        isSaving = true
        error = nil
        await store.updateSystem(SystemUpdate(
            name:        name.isEmpty        ? nil : name,
            description: description.isEmpty ? nil : description,
            tag:         tag.isEmpty         ? nil : tag,
            avatarURL:   avatarURL.isEmpty   ? nil : avatarURL,
            color:       colorHex,
            privacy:     privacy
        ))
        isSaving = false
        dismiss()
    }
}
