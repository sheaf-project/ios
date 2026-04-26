import SwiftUI

struct TrustedDevicesView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var store: SystemStore

    @State private var devices: [TrustedDevice] = []
    @State private var isLoading = true
    @State private var showRevokeAllConfirm = false
    @State private var renameDeviceId: String?
    @State private var renameText = ""
    @State private var showRenameAlert = false

    var body: some View {
        ZStack {
            theme.backgroundPrimary.ignoresSafeArea()

            if isLoading {
                ProgressView().tint(theme.accentLight)
            } else if devices.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.shield")
                        .font(.largeTitle)
                        .foregroundColor(theme.textTertiary)
                    Text("No Trusted Devices")
                        .font(.body).fontWeight(.semibold).fontDesign(.rounded)
                        .foregroundColor(theme.textSecondary)
                    Text("When you log in with \"Remember this device\" enabled, the device will appear here.")
                        .font(.footnote)
                        .foregroundColor(theme.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            } else {
                List {
                    ForEach(devices) { device in
                        deviceRow(device)
                            .listRowBackground(theme.backgroundPrimary)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 5, leading: 24, bottom: 5, trailing: 24))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if !device.isCurrent {
                                    Button(role: .destructive) {
                                        Task { await revoke(device) }
                                    } label: {
                                        Label("Revoke", systemImage: "xmark.circle")
                                    }
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable { await load() }
            }
        }
        .navigationTitle("Trusted Devices")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(role: .destructive) {
                        showRevokeAllConfirm = true
                    } label: {
                        Label("Revoke All", systemImage: "xmark.shield")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundColor(theme.accentLight)
                }
            }
        }
        .confirmationDialog("Revoke All Trusted Devices?", isPresented: $showRevokeAllConfirm, titleVisibility: .visible) {
            Button("Revoke All", role: .destructive) {
                Task { await revokeAll() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will need to enter your 2FA code on every future login from all devices.")
        }
        .alert("Rename Device", isPresented: $showRenameAlert) {
            TextField("Nickname", text: $renameText)
            Button("Save") {
                if let id = renameDeviceId {
                    Task { await rename(id: id, nickname: renameText) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Give this device a name to identify it.")
        }
        .task { await load() }
    }

    private func deviceRow(_ device: TrustedDevice) -> some View {
        Button {
            renameDeviceId = device.id
            renameText = device.nickname ?? ""
            showRenameAlert = true
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: iconForDevice(device))
                        .font(.callout)
                        .foregroundColor(device.isCurrent ? theme.success : theme.accentLight)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(device.nickname ?? deviceLabel(device))
                                .font(.subheadline).fontWeight(.medium)
                                .foregroundColor(theme.textPrimary)
                                .lineLimit(1)
                            if device.isCurrent {
                                Text("Current")
                                    .font(.caption2).fontWeight(.bold)
                                    .foregroundColor(theme.success)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(theme.success.opacity(0.15))
                                    .cornerRadius(4)
                            }
                        }
                        if let ip = device.lastUsedIp ?? device.createdIp {
                            Text(ip)
                                .font(.caption)
                                .foregroundColor(theme.textTertiary)
                        }
                    }

                    Spacer()
                }

                HStack(spacing: 16) {
                    if let lastUsed = device.lastUsedAt {
                        Text("Used \(lastUsed, style: .relative) ago")
                            .font(.caption2)
                            .foregroundColor(theme.textTertiary)
                    }
                    Spacer()
                    Text("Expires \(device.expiresAt, style: .date)")
                        .font(.caption2)
                        .foregroundColor(device.expiresAt < Date() ? theme.danger : theme.textTertiary)
                }
                .padding(.leading, 32)
            }
            .padding(14)
            .background(theme.backgroundCard)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(device.isCurrent ? theme.success.opacity(0.4) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func deviceLabel(_ device: TrustedDevice) -> String {
        let ua = (device.userAgent ?? "").lowercased()
        if ua.contains("iphone") || ua.contains("ios") { return "iPhone" }
        if ua.contains("ipad") { return "iPad" }
        if ua.contains("mac") { return "Mac" }
        if ua.contains("android") { return "Android" }
        if ua.contains("windows") { return "Windows" }
        if ua.contains("linux") { return "Linux" }
        return "Unknown Device"
    }

    private func iconForDevice(_ device: TrustedDevice) -> String {
        let ua = (device.userAgent ?? "").lowercased()
        if ua.contains("iphone") || ua.contains("ios") { return "iphone" }
        if ua.contains("ipad") { return "ipad" }
        if ua.contains("mac") { return "laptopcomputer" }
        if ua.contains("android") { return "phone" }
        if ua.contains("safari") || ua.contains("firefox") || ua.contains("chrome") { return "globe" }
        return "desktopcomputer"
    }

    private func load() async {
        guard let api = store.api else { return }
        do {
            let loaded = try await api.listTrustedDevices()
            await MainActor.run {
                devices = loaded.sorted {
                    if $0.isCurrent != $1.isCurrent { return $0.isCurrent }
                    return ($0.lastUsedAt ?? $0.createdAt) > ($1.lastUsedAt ?? $1.createdAt)
                }
                isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }

    private func revoke(_ device: TrustedDevice) async {
        guard let api = store.api else { return }
        do {
            try await api.revokeTrustedDevice(id: device.id)
            await MainActor.run {
                withAnimation { devices.removeAll { $0.id == device.id } }
            }
        } catch {}
    }

    private func revokeAll() async {
        guard let api = store.api else { return }
        do {
            _ = try await api.revokeAllTrustedDevices()
            await MainActor.run {
                withAnimation { devices.removeAll() }
            }
        } catch {}
    }

    private func rename(id: String, nickname: String) async {
        guard let api = store.api else { return }
        do {
            let updated = try await api.renameTrustedDevice(id: id, nickname: nickname)
            await MainActor.run {
                if let i = devices.firstIndex(where: { $0.id == id }) {
                    devices[i] = updated
                }
            }
        } catch {}
    }
}
