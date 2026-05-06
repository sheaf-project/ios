import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var systemStore: SystemStore
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.theme) var theme

    @State private var currentStep = 0
    @State private var showTOTPSetup = false
    @State private var showSafetySheet = false
    @State private var showSPImportSheet = false
    @State private var showPKImportSheet = false

    var body: some View {
        ZStack {
            theme.loginGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 80)

                    Image("SheafLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)
                        .shadow(color: theme.accentLight.opacity(0.6), radius: 20)

                    Spacer().frame(height: 12)

                    Text("Welcome to Sheaf")
                        .font(.title2).fontWeight(.bold).fontDesign(.rounded)
                        .foregroundColor(theme.textPrimary)

                    Text("Let's get your account set up")
                        .font(.subheadline)
                        .foregroundColor(theme.textSecondary)

                    Spacer().frame(height: 32)

                    stepIndicator

                    Spacer().frame(height: 32)

                    switch currentStep {
                    case 0: twoFactorCard
                    case 1: safetyCard
                    default: importCard
                    }

                    Spacer().frame(height: 60)
                }
            }
        }
        .task {
            systemStore.configure(auth: authManager, themeManager: themeManager)
        }
        .sheet(isPresented: $showTOTPSetup) {
            TOTPSetupSheet()
                .environmentObject(authManager)
        }
        .sheet(isPresented: $showSafetySheet) {
            NavigationStack {
                SystemSafetyView()
                    .environmentObject(authManager)
                    .environmentObject(systemStore)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showSafetySheet = false }
                                .foregroundColor(theme.accentLight)
                        }
                    }
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showSPImportSheet) {
            SimplyPluralImportSheet()
                .environmentObject(systemStore)
        }
        .sheet(isPresented: $showPKImportSheet) {
            PluralKitImportSheet()
                .environmentObject(systemStore)
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(i == currentStep ? theme.accentLight : theme.textTertiary.opacity(0.3))
                    .frame(width: i == currentStep ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.3), value: currentStep)
            }
        }
    }

    // MARK: - Step Cards

    private var twoFactorCard: some View {
        onboardingCard(
            icon: "lock.shield.fill",
            title: String(localized: "Secure Your Account"),
            description: String(localized: "Add an extra layer of security with two-factor authentication using an authenticator app."),
            actionLabel: String(localized: "Set Up 2FA"),
            action: { showTOTPSetup = true },
            isLastStep: false
        )
    }

    private var safetyCard: some View {
        onboardingCard(
            icon: "shield.lefthalf.filled.badge.checkmark",
            title: String(localized: "System Safety"),
            description: String(localized: "Set up grace periods and re-authentication for destructive actions to protect your data."),
            actionLabel: String(localized: "Configure Safety"),
            action: { showSafetySheet = true },
            isLastStep: false
        )
    }

    private var importCard: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [theme.accentLight, theme.accent],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 72, height: 72)
                Image(systemName: "square.and.arrow.down.fill")
                    .font(.title)
                    .foregroundColor(.white)
            }
            .shadow(color: theme.accentLight.opacity(0.5), radius: 20)

            Text("Import Your Data")
                .font(.title3).fontWeight(.bold).fontDesign(.rounded)
                .foregroundColor(theme.textPrimary)

            Text("Coming from Simply Plural or PluralKit? Import your members, groups, and front history.")
                .font(.subheadline)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 8)

            Button { showSPImportSheet = true } label: {
                HStack {
                    Text("Import from Simply Plural")
                    Image(systemName: "chevron.right")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(theme.accentLight)

            Button { showPKImportSheet = true } label: {
                HStack {
                    Text("Import from PluralKit")
                    Image(systemName: "chevron.right")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(theme.accentLight)

            Button { authManager.needsOnboarding = false } label: {
                Text("Get Started")
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundColor(theme.accentLight)
            }
        }
        .padding(24)
        .background(theme.backgroundCard)
        .cornerRadius(24)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(theme.border, lineWidth: 1))
        .padding(.horizontal, 24)
    }

    // MARK: - Card Builder

    private func onboardingCard(
        icon: String,
        title: String,
        description: String,
        actionLabel: String,
        action: @escaping () -> Void,
        isLastStep: Bool
    ) -> some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [theme.accentLight, theme.accent],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 72, height: 72)
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(.white)
            }
            .shadow(color: theme.accentLight.opacity(0.5), radius: 20)

            Text(title)
                .font(.title3).fontWeight(.bold).fontDesign(.rounded)
                .foregroundColor(theme.textPrimary)

            Text(description)
                .font(.subheadline)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 8)

            Button(action: action) {
                HStack {
                    Text(actionLabel)
                    Image(systemName: "chevron.right")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(theme.accentLight)

            if isLastStep {
                Button { authManager.needsOnboarding = false } label: {
                    Text("Get Started")
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundColor(theme.accentLight)
                }
            } else {
                Button {
                    withAnimation(.spring(response: 0.4)) {
                        currentStep += 1
                    }
                } label: {
                    Text("Skip")
                        .font(.subheadline)
                        .foregroundColor(theme.textTertiary)
                }
            }
        }
        .padding(24)
        .background(theme.backgroundCard)
        .cornerRadius(24)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(theme.border, lineWidth: 1))
        .padding(.horizontal, 24)
    }
}
