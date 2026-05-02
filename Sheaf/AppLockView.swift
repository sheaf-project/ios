import SwiftUI

// MARK: - App Lock Settings Row
struct AppLockRow: View {
    @ObservedObject var lockManager: AppLockManager
    @Binding var showPasscodeAlert: Bool
    @Environment(\.theme) var theme
    @State private var isEnabled: Bool

    init(lockManager: AppLockManager, showPasscodeAlert: Binding<Bool>) {
        self.lockManager = lockManager
        self._showPasscodeAlert = showPasscodeAlert
        self._isEnabled = State(initialValue: lockManager.isEnabled)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: lockManager.lockIcon)
                .foregroundColor(theme.accentLight)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text("App Lock")
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundColor(theme.textPrimary)
                Text(lockManager.lockMethodLabel)
                    .font(.caption)
                    .foregroundColor(theme.textTertiary)
            }
            Spacer()
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .tint(theme.accentLight)
                .onChange(of: isEnabled) {
                    handleToggle(isEnabled)
                }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }

    private func handleToggle(_ newValue: Bool) {
        if newValue {
            guard lockManager.isPasscodeSet else {
                isEnabled = false
                showPasscodeAlert = true
                return
            }
            Task {
                let success = await lockManager.authenticateToEnable()
                if success {
                    lockManager.isEnabled = true
                } else {
                    isEnabled = false
                }
            }
        } else {
            lockManager.isEnabled = false
        }
    }
}

// MARK: - App Lock Screen
struct AppLockView: View {
    @ObservedObject var lockManager = AppLockManager.shared
    @Environment(\.theme) var theme

    var body: some View {
        ZStack {
            theme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(theme.accentLight)

                    Text("Sheaf is Locked")
                        .font(.title2).fontWeight(.bold).fontDesign(.rounded)
                        .foregroundColor(theme.textPrimary)

                    Text("Authenticate to continue")
                        .font(.subheadline)
                        .foregroundColor(theme.textSecondary)
                }

                Button {
                    lockManager.authenticate()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: lockManager.lockIcon)
                            .font(.body.weight(.medium))
                        Text("Unlock")
                            .font(.body).fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(theme.accentLight)
                    .cornerRadius(14)
                }
                .padding(.horizontal, 48)

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            lockManager.authenticate()
        }
    }
}
