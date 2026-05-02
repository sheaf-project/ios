import Combine
import LocalAuthentication
import SwiftUI

final class AppLockManager: ObservableObject {
    static let shared = AppLockManager()
    @Published var isLocked = false

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "sheaf_app_lock_enabled") }
        set {
            UserDefaults.standard.set(newValue, forKey: "sheaf_app_lock_enabled")
            objectWillChange.send()
            if !newValue { isLocked = false }
        }
    }

    var biometryType: LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        return context.biometryType
    }

    var biometryLabel: String {
        switch biometryType {
        case .faceID:     return String(localized: "Face ID")
        case .touchID:    return String(localized: "Touch ID")
        case .opticID:    return String(localized: "Optic ID")
        case .none:       return String(localized: "Passcode")
        @unknown default: return String(localized: "Biometrics")
        }
    }

    var lockMethodLabel: String {
        switch biometryType {
        case .none:      return String(localized: "Device Passcode")
        default:         return "\(biometryLabel) & Passcode"
        }
    }

    var lockIcon: String {
        switch biometryType {
        case .faceID:     return "faceid"
        case .touchID:    return "touchid"
        case .opticID:    return "opticid"
        case .none:       return "lock.fill"
        @unknown default: return "lock.fill"
        }
    }

    func lockIfEnabled() {
        if isEnabled { isLocked = true }
    }

    func authenticate() {
        let context = LAContext()
        context.localizedCancelTitle = String(localized: "Cancel")

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            isLocked = false
            return
        }

        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: String(localized: "Unlock Sheaf")
        ) { success, _ in
            DispatchQueue.main.async {
                if success { self.isLocked = false }
            }
        }
    }

    var isPasscodeSet: Bool {
        let context = LAContext()
        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
        if !canEvaluate, let laError = error as? LAError, laError.code == .passcodeNotSet {
            return false
        }
        return canEvaluate
    }

    func authenticateToEnable() async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = String(localized: "Cancel")

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return false
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: String(localized: "Enable App Lock")
            )
            return success
        } catch {
            return false
        }
    }
}
