import SwiftUI

struct NotificationRedemptionSheet: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss

    let activationCode: String

    @State private var isRedeeming = false
    @State private var redeemed = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundPrimary.ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    if redeemed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 56))
                            .foregroundColor(theme.success)
                        Text("Subscription Activated")
                            .font(.title3).fontWeight(.bold).fontDesign(.rounded)
                            .foregroundColor(theme.textPrimary)
                        Text("You'll receive push notifications for this channel on your registered devices.")
                            .font(.subheadline)
                            .foregroundColor(theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    } else {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 56))
                            .foregroundColor(theme.accentLight)
                        Text("Activate Notification Channel")
                            .font(.title3).fontWeight(.bold).fontDesign(.rounded)
                            .foregroundColor(theme.textPrimary)
                        Text("Subscribe to this notification channel to receive push notifications on this device.")
                            .font(.subheadline)
                            .foregroundColor(theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        if let error = errorMessage {
                            Text(error)
                                .font(.footnote)
                                .foregroundColor(theme.danger)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }

                        Button {
                            Task { await redeem() }
                        } label: {
                            HStack {
                                if isRedeeming {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Activate")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(theme.accentLight)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isRedeeming)
                        .padding(.horizontal, 32)
                    }

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(redeemed ? "Done" : "Cancel") { dismiss() }
                        .foregroundColor(theme.accentLight)
                }
            }
        }
    }

    private func redeem() async {
        isRedeeming = true
        errorMessage = nil

        let api = APIClient(auth: authManager)
        do {
            try await api.redeemNotificationChannel(activationCode: activationCode)
            await MainActor.run {
                withAnimation { redeemed = true }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
        isRedeeming = false
    }
}
