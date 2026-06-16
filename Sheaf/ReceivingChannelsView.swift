import SwiftUI

// MARK: - ReceivingChannelsView

struct ReceivingChannelsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme

    @State private var channels: [ReceivingChannel] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var unsubscribeTarget: ReceivingChannel?

    var body: some View {
        ZStack {
            theme.backgroundPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    if isLoading && channels.isEmpty {
                        ProgressView()
                            .tint(theme.accentLight)
                            .padding(.top, 60)
                    } else if channels.isEmpty {
                        emptyState
                    } else {
                        header
                        channelList
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 80)
            }
            .refreshable { await loadData() }
        }
        .navigationTitle("Receiving")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadData() }
        .confirmationDialog(
            unsubscribeTarget.map { "Unsubscribe from \"\($0.channelName)\"?" } ?? "Unsubscribe?",
            isPresented: Binding(
                get: { unsubscribeTarget != nil },
                set: { if !$0 { unsubscribeTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Unsubscribe", role: .destructive) {
                if let target = unsubscribeTarget {
                    Task { await unsubscribe(target) }
                }
            }
            Button("Cancel", role: .cancel) { unsubscribeTarget = nil }
        } message: {
            if let target = unsubscribeTarget {
                let suffix = target.systemLabel.map { " from \($0)" } ?? ""
                Text("\"\(target.channelName)\"\(suffix) will stop delivering to this account.")
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var header: some View {
        Text("Notification channels delivering to this account.")
            .font(.subheadline)
            .foregroundColor(theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 48))
                .foregroundColor(theme.textTertiary)
            Text("No Active Subscriptions")
                .font(.headline)
                .foregroundColor(theme.textPrimary)
            Text("Open an activation link from a system you want to follow, and it'll show up here.")
                .font(.subheadline)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 60)
    }

    private var channelList: some View {
        VStack(spacing: 0) {
            ForEach(Array(channels.enumerated()), id: \.element.id) { index, channel in
                channelRow(channel)
                if index < channels.count - 1 {
                    Divider().background(theme.divider).padding(.leading, 52)
                }
            }
        }
        .background(theme.backgroundCard)
        .cornerRadius(16)
        .padding(.horizontal, 24)
    }

    private func channelRow(_ channel: ReceivingChannel) -> some View {
        let muted = channel.destinationState == .disabled || channel.pausedBySender
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: channel.destinationType.icon)
                .foregroundColor(muted ? theme.textTertiary : theme.accentLight)
                .frame(width: 20)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(channel.channelName)
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundColor(theme.textPrimary)

                if let label = channel.systemLabel, !label.isEmpty {
                    Text("from \(label)")
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                }

                HStack(spacing: 6) {
                    Text(channel.destinationType.label)
                        .font(.caption)
                        .foregroundColor(statusColor(for: channel))
                    if let suffix = statusSuffix(for: channel) {
                        Text("·")
                            .font(.caption)
                            .foregroundColor(theme.textTertiary)
                        Text(suffix)
                            .font(.caption)
                            .foregroundColor(statusColor(for: channel))
                    }
                }

                if let lastDelivered = channel.lastDeliveredAt {
                    Text("Last delivered \(lastDelivered, style: .relative) ago")
                        .font(.caption)
                        .foregroundColor(theme.textTertiary)
                }
            }

            Spacer()

            // Unsubscribe is still valid while paused (the recipient may
            // want out regardless of whether the sender resumes). Disabled
            // rows can't be unsubscribed — there's nothing live to leave.
            if channel.destinationState != .disabled {
                Button { unsubscribeTarget = channel } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundColor(theme.danger)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }

    private func statusSuffix(for channel: ReceivingChannel) -> String? {
        if channel.pausedBySender { return "paused by sender" }
        if channel.destinationState == .disabled { return "disabled" }
        return nil
    }

    private func statusColor(for channel: ReceivingChannel) -> Color {
        // Paused is a soft state (sender controls it), so use the neutral
        // tone. Disabled means "this won't work without your action".
        if channel.destinationState == .disabled { return theme.danger }
        return theme.textTertiary
    }

    private func loadData() async {
        guard let api = store.api else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            channels = try await api.listReceivingChannels()
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    private func unsubscribe(_ channel: ReceivingChannel) async {
        guard let api = store.api else { return }
        unsubscribeTarget = nil
        do {
            try await api.unsubscribeReceivingChannel(channelID: channel.channelID)
            channels.removeAll { $0.channelID == channel.channelID }
        } catch {
            errorMessage = error.userFacingMessage
        }
    }
}
