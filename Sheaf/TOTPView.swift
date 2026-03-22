import SwiftUI

struct TOTPView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.theme) var theme
    @State private var digits: [String] = Array(repeating: "", count: 6)
    @State private var error: String = ""
    @State private var isVerifying = false
    @State private var shakeOffset: CGFloat = 0
    @FocusState private var focusedIndex: Int?

    private var code: String { digits.joined() }
    private var isComplete: Bool { code.count == 6 }

    var body: some View {
        ZStack {
            theme.loginGradient
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [theme.accentLight, theme.accent],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 72, height: 72)
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 30))
                        .foregroundColor(theme.textPrimary)
                }
                .shadow(color: theme.accentLight.opacity(0.5), radius: 20)

                Spacer().frame(height: 24)

                Text("Two-Factor Auth")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textPrimary)

                Spacer().frame(height: 8)

                Text("Enter the 6-digit code from your authenticator app")
                    .font(.system(size: 14))
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 48)

                Spacer().frame(height: 40)

                // 6-digit input boxes
                HStack(spacing: 10) {
                    ForEach(0..<6, id: \.self) { i in
                        DigitBox(
                            digit: $digits[i],
                            isFocused: focusedIndex == i,
                            hasError: !error.isEmpty
                        )
                        .focused($focusedIndex, equals: i)
                        .onChange(of: digits[i]) { _, new in
                            handleInput(index: i, value: new)
                        }
                    }
                }
                .offset(x: shakeOffset)
                .padding(.horizontal, 24)

                Spacer().frame(height: 16)

                // Error
                if !error.isEmpty {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(theme.danger)
                        .transition(.opacity)
                }

                Spacer().frame(height: 32)

                // Verify button
                Button { verify() } label: {
                    HStack {
                        if isVerifying { ProgressView().tint(.white) }
                        else {
                            Text("Verify")
                                .font(.system(size: 17, weight: .semibold))
                            Image(systemName: "checkmark")
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(
                        Group {
                            if isComplete {
                                LinearGradient(colors: [theme.accentLight, theme.accent],
                                               startPoint: .leading, endPoint: .trailing)
                            } else {
                                theme.backgroundElevated
                            }
                        }
                    )
                    .cornerRadius(14)
                    .shadow(color: isComplete ? theme.accentLight.opacity(0.4) : .clear, radius: 12, y: 4)
                }
                .disabled(!isComplete || isVerifying)
                .padding(.horizontal, 24)

                Spacer().frame(height: 16)

                // Cancel
                Button {
                    authManager.cancelTOTP()
                } label: {
                    Text("Back to login")
                        .font(.system(size: 14))
                        .foregroundColor(theme.textTertiary)
                }

                Spacer()
            }
        }
        .onAppear { focusedIndex = 0 }
        .animation(.default, value: error)
    }

    // MARK: - Input handling

    private func handleInput(index: Int, value: String) {
        error = ""

        // Handle paste: if someone pastes a full 6-digit code into any box
        let stripped = value.filter { $0.isNumber }
        if stripped.count == 6 {
            for i in 0..<6 { digits[i] = String(stripped[stripped.index(stripped.startIndex, offsetBy: i)]) }
            focusedIndex = nil
            verify()
            return
        }

        // Keep only the last digit entered
        if value.count > 1 {
            digits[index] = String(value.last ?? Character(""))
        }

        // Only allow numbers
        digits[index] = digits[index].filter { $0.isNumber }

        // Advance focus
        if !digits[index].isEmpty && index < 5 {
            focusedIndex = index + 1
        }

        // Auto-submit when all 6 filled
        if isComplete { verify() }
    }

    // MARK: - Verify

    private func verify() {
        guard isComplete, !isVerifying else { return }
        isVerifying = true
        error = ""
        let api = APIClient(auth: authManager)
        Task {
            do {
                try await api.verifyTOTP(code: code)
                await MainActor.run {
                    authManager.completeTOTP()
                    isVerifying = false
                }
            } catch {
                await MainActor.run {
                    self.error = String(localized: "Incorrect code — please try again")
                    isVerifying = false
                    digits = Array(repeating: "", count: 6)
                    focusedIndex = 0
                    shake()
                }
            }
        }
    }

    private func shake() {
        withAnimation(.spring(response: 0.1, dampingFraction: 0.2).repeatCount(4, autoreverses: true)) {
            shakeOffset = 8
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { shakeOffset = 0 }
    }
}

// MARK: - Digit Box

struct DigitBox: View {
    @Environment(\.theme) var theme
    @Binding var digit: String
    let isFocused: Bool
    let hasError: Bool

    var borderColor: Color {
        if hasError { return theme.danger }
        if isFocused { return theme.accentLight }
        return Color.white.opacity(digit.isEmpty ? 0.15 : 0.35)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(isFocused ? 0.1 : 0.05))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(borderColor, lineWidth: 2))

            if digit.isEmpty && isFocused {
                // blinking cursor
                RoundedRectangle(cornerRadius: 1)
                    .fill(theme.accentLight)
                    .frame(width: 2, height: 22)
                    .opacity(isFocused ? 1 : 0)
            } else {
                Text(digit)
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(theme.textPrimary)
            }

            // Hidden text field driving the input
            TextField("", text: $digit)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .frame(width: 44, height: 52)
                .opacity(0.01)   // invisible but tappable/focusable
        }
        .frame(width: 44, height: 56)
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .animation(.spring(response: 0.2), value: isFocused)
    }
}
