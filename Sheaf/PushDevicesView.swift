import SwiftUI

struct PushDevicesView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var store: SystemStore

    @State private var devices: [PushDevice] = []
    @State private var isLoading = true
    @State private var permissionGranted = false

    var body: some View {
        ZStack {
            theme.backgroundPrimary.ignoresSafeArea()

            if isLoading {
                ProgressView().tint(theme.accentLight)
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        if !permissionGranted {
                            permissionBanner
                        }

                        if devices.isEmpty {
                            emptyState
                        } else {
                            deviceList
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                }
                .refreshable { await load() }
            }
        }
        .navigationTitle("Push Devices")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await PushNotificationManager.shared.checkPermissionStatus()
            permissionGranted = PushNotificationManager.shared.permissionGranted
            await load()
        }
    }

    private var permissionBanner: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.slash")
                .font(.title2)
                .foregroundColor(theme.warning)
            Text("Notifications Disabled")
                .font(.subheadline).fontWeight(.semibold)
                .foregroundColor(theme.textPrimary)
            Text("Enable notifications in Settings to receive push notifications on this device.")
                .font(.caption)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.subheadline).fontWeight(.medium)
            .foregroundColor(theme.accentLight)
        }
        .padding(16)
        .background(theme.backgroundCard)
        .cornerRadius(14)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "iphone.badge.play")
                .font(.largeTitle)
                .foregroundColor(theme.textTertiary)
            Text("No Registered Devices")
                .font(.body).fontWeight(.semibold).fontDesign(.rounded)
                .foregroundColor(theme.textSecondary)
            Text("Devices are registered automatically when you log in with push notifications enabled.")
                .font(.footnote)
                .foregroundColor(theme.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .padding(.top, 40)
    }

    private var deviceList: some View {
        VStack(spacing: 10) {
            ForEach(devices) { device in
                deviceRow(device)
            }
        }
    }

    private func deviceRow(_ device: PushDevice) -> some View {
        let isCurrent = isCurrentDevice(device)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: iconForPlatform(device.platform))
                    .font(.callout)
                    .foregroundColor(isCurrent ? theme.success : theme.accentLight)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(labelForPlatform(device.platform))
                            .font(.subheadline).fontWeight(.medium)
                            .foregroundColor(theme.textPrimary)
                            .lineLimit(1)
                        if isCurrent {
                            Text("This Device")
                                .font(.caption2).fontWeight(.bold)
                                .foregroundColor(theme.success)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(theme.success.opacity(0.15))
                                .cornerRadius(4)
                        }
                    }
                    if let version = device.appVersion {
                        Text("v\(version)")
                            .font(.caption)
                            .foregroundColor(theme.textTertiary)
                    }
                }

                Spacer()

                if isCurrent {
                    Button(role: .destructive) {
                        Task { await removeCurrentDevice(device) }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(theme.textTertiary)
                    }
                }
            }

            HStack(spacing: 16) {
                Text("Last seen \(device.lastSeenAt, style: .relative) ago")
                    .font(.caption2)
                    .foregroundColor(theme.textTertiary)
                Spacer()
                Text("Registered \(device.createdAt, style: .date)")
                    .font(.caption2)
                    .foregroundColor(theme.textTertiary)
            }
            .padding(.leading, 32)
        }
        .padding(14)
        .background(theme.backgroundCard)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(isCurrent ? theme.success.opacity(0.4) : Color.clear, lineWidth: 1))
    }

    private func isCurrentDevice(_ device: PushDevice) -> Bool {
        guard let localInstallId = PushNotificationManager.shared.installId else { return false }
        return device.installId == localInstallId
    }

    private func iconForPlatform(_ platform: PushDevicePlatform) -> String {
        switch platform {
        case .apnsDev, .apnsProd: return "iphone"
        case .fcm: return "phone"
        }
    }

    private func labelForPlatform(_ platform: PushDevicePlatform) -> String {
        switch platform {
        case .apnsDev: return "iOS (Development)"
        case .apnsProd: return "iOS"
        case .fcm: return "Android"
        }
    }

    private func load() async {
        guard let api = store.api else { return }
        do {
            let loaded = try await api.listPushDevices()
            await MainActor.run {
                devices = loaded.sorted {
                    if isCurrentDevice($0) != isCurrentDevice($1) { return isCurrentDevice($0) }
                    return $0.lastSeenAt > $1.lastSeenAt
                }
                isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }

    private func removeCurrentDevice(_ device: PushDevice) async {
        guard let api = store.api else { return }
        guard let tokenHex = KeychainHelper.get(key: "sheaf_push_device_token") else { return }
        do {
            try await api.unregisterPushDevice(token: tokenHex)
            PushNotificationManager.shared.clearInstallId()
            await MainActor.run {
                withAnimation { devices.removeAll { $0.id == device.id } }
            }
        } catch {}
    }
}
