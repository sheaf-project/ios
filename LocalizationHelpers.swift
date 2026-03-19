import SwiftUI

// MARK: - String Extension for Localization
extension String {
    /// Localizes the string using the main bundle's localization resources
    var localized: String {
        NSLocalizedString(self, comment: "")
    }
    
    /// Localizes the string with format arguments
    func localized(_ arguments: CVarArg...) -> String {
        String(format: NSLocalizedString(self, comment: ""), arguments: arguments)
    }
}

// MARK: - Common Localized Strings
/// Centralized location for commonly used localized strings
enum LocalizedStrings {
    // MARK: - App
    static let appName = "Sheaf"
    
    // MARK: - Authentication
    static let signIn = "Sign In"
    static let register = "Register"
    static let email = "Email"
    static let password = "Password"
    static let apiBaseURL = "API Base URL"
    static let signInToYourSystem = "Sign in to your system"
    static let createYourAccount = "Create your account"
    static let dontHaveAccount = "Don't have an account?"
    
    // MARK: - Quick Actions
    static let addToFront = "Add to Front"
    static let addMember = "Add Member"
    
    // MARK: - Placeholders
    static let emailPlaceholder = "you@example.com"
    static let passwordPlaceholder = "••••••••"
    static let apiURLPlaceholder = "https://your-api.example.com"
    
    // MARK: - Common Actions
    static let cancel = "Cancel"
    static let save = "Save"
    static let delete = "Delete"
    static let edit = "Edit"
    static let done = "Done"
    static let ok = "OK"
    
    // MARK: - Errors
    static let errorTitle = "Error"
    static let unknownError = "An unknown error occurred"
}

// MARK: - LocalizedStringKey Extension
extension LocalizedStringKey {
    /// Creates a LocalizedStringKey from a String constant
    init(_ value: String) {
        self.init(stringLiteral: value)
    }
}
