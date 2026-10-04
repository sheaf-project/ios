import SwiftUI

struct FilesView: View {
    @Environment(\.theme) var theme
    @Environment(\.apiBaseURL) private var baseURL
    @EnvironmentObject var store: SystemStore

    @State private var files: [UploadedFile] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var avatars: [UploadedFile] { files.filter { $0.purpose == "avatar" } }
    private var banners: [UploadedFile] { files.filter { $0.purpose == "banner" } }

    var body: some View {
        ZStack {
            theme.backgroundPrimary.ignoresSafeArea()

            if isLoading {
                ProgressView().tint(theme.accentLight)
            } else if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundColor(theme.danger)
                    .padding(24)
            } else if avatars.isEmpty && banners.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.largeTitle)
                        .foregroundColor(theme.textTertiary)
                    Text("No files saved")
                        .font(.body).fontWeight(.medium).fontDesign(.rounded)
                        .foregroundColor(theme.textTertiary)
                }
            } else {
                List {
                    if !avatars.isEmpty {
                        section("Avatars", avatars)
                    }
                    if !banners.isEmpty {
                        section("Banners", banners)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable { await load() }
            }
        }
        .navigationTitle("Files")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func section(_ title: LocalizedStringKey, _ items: [UploadedFile]) -> some View {
        Section {
            ForEach(items) { f in
                row(f)
            }
        } header: {
            Text(title)
                .font(.caption).fontWeight(.semibold)
                .foregroundColor(theme.textTertiary)
                .textCase(nil)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func row(_ f: UploadedFile) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: resolveAvatarURL(f.url, baseURL: baseURL)) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                theme.backgroundElevated
            }
            .frame(width: f.purpose == "banner" ? 88 : 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: f.purpose == "banner" ? 8 : 24))

            VStack(alignment: .leading, spacing: 2) {
                Text(ByteCountFormatter.string(fromByteCount: Int64(f.sizeBytes), countStyle: .file))
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundColor(theme.textPrimary)
                Text(f.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
                if f.pendingDeleteAt != nil {
                    Text("Pending deletion")
                        .font(.caption)
                        .foregroundColor(theme.warning)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func load() async {
        guard let api = store.api else { return }
        do {
            files = try await api.listFiles()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
