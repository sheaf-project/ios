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
    static let confirmPassword = "Confirm Password"
    static let apiBaseURL = "API Base URL"
    static let signInToYourSystem = "Sign in to your system"
    static let createYourAccount = "Create your account"
    static let dontHaveAccount = "Don't have an account?"
    static let alreadyHaveAccount = "Already have an account?"
    static let createAccount = "Create Account"
    static let backToLogin = "Back to login"
    
    // MARK: - Two-Factor Auth
    static let twoFactorAuth = "Two-Factor Auth"
    static let twoFactorAuthPrompt = "Enter the 6-digit code from your authenticator app"
    static let verify = "Verify"
    static let incorrectCode = "Incorrect code — please try again"
    static let twoFactorEnabled = "Enabled"
    static let twoFactorDisabled = "Disabled"
    static let setUpTwoFactorAuth = "Set Up Two-Factor Auth"
    static let manageTwoFactorAuth = "Manage Two-Factor Auth"
    
    // MARK: - Tabs
    static let home = "Home"
    static let members = "Members"
    static let groups = "Groups"
    static let history = "History"
    static let settings = "Settings"
    
    // MARK: - Home
    static func welcomeName(_ name: String) -> String {
        String(format: NSLocalizedString("Welcome, %@!", comment: "Welcome message with name"), name)
    }
    static func since(_ time: String) -> String {
        String(format: NSLocalizedString("Since %@", comment: "Time indicator"), time)
    }
    static let quickSwitch = "Quick Switch"
    static let more = "More"
    static let remove = "Remove"
    static let noOneFronting = "No one fronting"
    
    // MARK: - Settings
    static let connection = "Connection"
    static let appearance = "Appearance"
    static let security = "Security"
    static let importData = "Import"
    static let apiURL = "API URL"
    static let token = "Token"
    static let editConnection = "Edit Connection"
    static let importFromSimplyPlural = "Import from Simply Plural"
    static let logout = "Log Out"
    static let logoutConfirmation = "Are you sure you want to log out?"
    
    // MARK: - Theme
    static let systemTheme = "System"
    static let darkTheme = "Dark"
    static let lightTheme = "Light"
    
    // MARK: - Password Strength
    static let passwordWeak = "Weak"
    static let passwordFair = "Fair"
    static let passwordGood = "Good"
    static let passwordStrong = "Strong"
    
    // MARK: - Form Labels
    static let atLeast8Characters = "At least 8 characters"
    
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
    static let yes = "Yes"
    static let no = "No"
    
    // MARK: - Errors
    static let errorTitle = "Error"
    static let unknownError = "An unknown error occurred"
    static let passwordsDontMatch = "Passwords don't match"
    static let passwordTooShort = "Password must be at least 8 characters"
    static let urlMustStartWithHTTP = "URL must start with http:// or https://"
    static let invalidURL = "Invalid URL"
}

// MARK: - LocalizedStringKey Extension
extension LocalizedStringKey {
    /// Creates a LocalizedStringKey from a String constant
    init(_ value: String) {
        self.init(stringLiteral: value)
    }
}
