import SwiftUI

struct FilesView: View {
    @Environment(\.theme) var theme
    @Environment(\.apiBaseURL) private var baseURL
    @EnvironmentObject var store: SystemStore

    @State private var files: [UploadedFile] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var fileToDelete: UploadedFile?
    @State private var showDeleteConfirm = false
    @State private var showDeleteAuthSheet = false
    @State private var deleteQueuedInfo: DeleteQueued?
    @State private var showDeleteQueued = false

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
                .scrollContentBackground(.hidden)
                .refreshable { await load() }
            }
        }
        .navigationTitle("Files")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .deleteAlert(
            store.deletePrompt(\.appliesToImages, title: "Delete this file?", message: "Anything still using this image will lose it.", subject: String(localized: "This file")),
            isPresented: $showDeleteConfirm, presenting: fileToDelete
        ) { f in
            Task { await delete(f, confirmation: nil) }
        }
        .sheet(isPresented: $showDeleteAuthSheet) {
            if let f = fileToDelete {
                DeleteConfirmSheet(resourceName: fileLabel(f), actionLabel: "Delete File", category: \.appliesToImages) { confirmation in
                    Task { await delete(f, confirmation: confirmation) }
                }
                .environmentObject(store)
            }
        }
        .alert("Deletion Queued", isPresented: $showDeleteQueued) {
            Button("OK", role: .cancel) { deleteQueuedInfo = nil }
        } message: {
            if let info = deleteQueuedInfo {
                Text("This deletion has been queued and will finalize \(info.finalizeAfter, style: .relative). You can cancel it from System Safety settings.")
            }
        }
    }

    private func section(_ title: LocalizedStringKey, _ items: [UploadedFile]) -> some View {
        Section {
            ForEach(items) { f in
                row(f)
                    .listRowBackground(theme.backgroundCard)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            requestDelete(f)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        } header: {
            Text(title)
                .font(.caption).fontWeight(.semibold)
                .foregroundColor(theme.textTertiary)
                .textCase(nil)
        }
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
                if let at = f.pendingDeleteAt {
                    Text("Deletes \(at, style: .relative)")
                        .font(.caption)
                        .foregroundColor(theme.warning)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func fileLabel(_ f: UploadedFile) -> String {
        let kind = f.purpose == "banner" ? String(localized: "Banner") : String(localized: "Avatar")
        return "\(kind), \(f.createdAt.formatted(date: .abbreviated, time: .omitted))"
    }

    private func requestDelete(_ f: UploadedFile) {
        fileToDelete = f
        if store.deleteConfirmation == .none {
            showDeleteConfirm = true
        } else {
            showDeleteAuthSheet = true
        }
    }

    private func delete(_ f: UploadedFile, confirmation: MemberDeleteConfirm?) async {
        guard let api = store.api else { return }
        do {
            let queued = try await api.deleteFile(id: f.id, confirmation: confirmation)
            if let queued {
                deleteQueuedInfo = queued
                showDeleteQueued = store.deleteConfirmation != .none
                await load()
            } else {
                files.removeAll { $0.id == f.id }
            }
        } catch {
            store.errorMessage = error.userFacingMessage
        }
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
