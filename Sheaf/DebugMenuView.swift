#if DEBUG
import SwiftUI

struct DebugMenuView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme

    var body: some View {
        ZStack {
            theme.backgroundPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    section(title: "Screens") {
                        VStack(spacing: 0) {
                            Button { authManager.needsOnboarding = true } label: {
                                row(icon: "sparkles", label: "Test Onboarding")
                                .foregroundColor(theme.accentLight)
                            }
                        }
                    }
                }
                .padding(.vertical, 16)
            }
        }
        .navigationTitle("Debug Menu")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helpers

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption).fontWeight(.semibold)
                .foregroundColor(theme.textSecondary)
                .textCase(.uppercase)
                .kerning(0.8)
                .padding(.horizontal, 24)
            VStack(spacing: 0) { content() }
                .background(theme.backgroundCard)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.backgroundCard, lineWidth: 1))
                .padding(.horizontal, 24)
        }
    }

    private func row(icon: String, label: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(theme.warning)
                .frame(width: 20)
            Text(label)
                .font(.subheadline).fontWeight(.medium)
                .foregroundColor(theme.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(theme.textTertiary)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }
}
#endif
