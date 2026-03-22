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
    static let appName = NSLocalizedString("Sheaf", comment: "App name")

    // MARK: - Authentication
    static let signIn = NSLocalizedString("Sign In", comment: "")
    static let register = NSLocalizedString("Register", comment: "")
    static let email = NSLocalizedString("Email", comment: "")
    static let password = NSLocalizedString("Password", comment: "")
    static let confirmPassword = NSLocalizedString("Confirm Password", comment: "")
    static let apiBaseURL = NSLocalizedString("API Base URL", comment: "")
    static let signInToYourSystem = NSLocalizedString("Sign in to your system", comment: "")
    static let createYourAccount = NSLocalizedString("Create your account", comment: "")
    static let dontHaveAccount = NSLocalizedString("Don't have an account?", comment: "")
    static let alreadyHaveAccount = NSLocalizedString("Already have an account?", comment: "")
    static let createAccount = NSLocalizedString("Create Account", comment: "")
    static let backToLogin = NSLocalizedString("Back to login", comment: "")

    // MARK: - Two-Factor Auth
    static let twoFactorAuth = NSLocalizedString("Two-Factor Auth", comment: "")
    static let twoFactorAuthPrompt = NSLocalizedString("Enter the 6-digit code from your authenticator app", comment: "")
    static let verify = NSLocalizedString("Verify", comment: "")
    static let incorrectCode = NSLocalizedString("Incorrect code — please try again", comment: "")
    static let twoFactorEnabled = NSLocalizedString("Enabled", comment: "")
    static let twoFactorDisabled = NSLocalizedString("Disabled", comment: "")
    static let setUpTwoFactorAuth = NSLocalizedString("Set Up Two-Factor Auth", comment: "")
    static let manageTwoFactorAuth = NSLocalizedString("Manage Two-Factor Auth", comment: "")

    // MARK: - Tabs
    static let home = NSLocalizedString("Home", comment: "Tab label")
    static let members = NSLocalizedString("Members", comment: "Tab label")
    static let groups = NSLocalizedString("Groups", comment: "Tab label")
    static let history = NSLocalizedString("History", comment: "Tab label")
    static let settings = NSLocalizedString("Settings", comment: "Tab label")

    // MARK: - Home
    static func welcomeName(_ name: String) -> String {
        String(format: NSLocalizedString("Welcome, %@!", comment: "Welcome message with name"), name)
    }
    static func since(_ time: String) -> String {
        String(format: NSLocalizedString("Since %@", comment: "Time indicator"), time)
    }
    static let quickSwitch = NSLocalizedString("Quick Switch", comment: "")
    static let more = NSLocalizedString("More", comment: "")
    static let remove = NSLocalizedString("Remove", comment: "")
    static let noOneFronting = NSLocalizedString("No one fronting", comment: "")

    // MARK: - Settings
    static let connection = NSLocalizedString("Connection", comment: "")
    static let appearance = NSLocalizedString("Appearance", comment: "")
    static let security = NSLocalizedString("Security", comment: "")
    static let importData = NSLocalizedString("Import", comment: "")
    static let apiURL = NSLocalizedString("API URL", comment: "")
    static let token = NSLocalizedString("Token", comment: "")
    static let editConnection = NSLocalizedString("Edit Connection", comment: "")
    static let importFromSimplyPlural = NSLocalizedString("Import from Simply Plural", comment: "")
    static let logout = NSLocalizedString("Log Out", comment: "")
    static let logoutConfirmation = NSLocalizedString("Are you sure you want to log out?", comment: "")

    // MARK: - Theme
    static let systemTheme = NSLocalizedString("System", comment: "Theme option")
    static let darkTheme = NSLocalizedString("Dark", comment: "Theme option")
    static let lightTheme = NSLocalizedString("Light", comment: "Theme option")

    // MARK: - Password Strength
    static let passwordWeak = NSLocalizedString("Weak", comment: "Password strength")
    static let passwordFair = NSLocalizedString("Fair", comment: "Password strength")
    static let passwordGood = NSLocalizedString("Good", comment: "Password strength")
    static let passwordStrong = NSLocalizedString("Strong", comment: "Password strength")

    // MARK: - Form Labels
    static let atLeast8Characters = NSLocalizedString("At least 8 characters", comment: "")

    // MARK: - Quick Actions
    static let addToFront = NSLocalizedString("Add to Front", comment: "")
    static let addMember = NSLocalizedString("Add Member", comment: "")

    // MARK: - Placeholders
    static let emailPlaceholder = NSLocalizedString("you@example.com", comment: "Email placeholder")
    static let passwordPlaceholder = NSLocalizedString("••••••••", comment: "Password placeholder")
    static let apiURLPlaceholder = NSLocalizedString("https://your-api.example.com", comment: "API URL placeholder")

    // MARK: - Watch
    static let fronting = NSLocalizedString("Fronting", comment: "")
    static let removeFromFront = NSLocalizedString("Remove from Front", comment: "")
    static func switchToOnly(_ name: String) -> String {
        String(format: NSLocalizedString("Switch to only %@", comment: "Switch to single fronter"), name)
    }
    static let noMembers = NSLocalizedString("No members", comment: "")
    static let addToFrontLabel = NSLocalizedString("Add to Front", comment: "")
    static func switchToOnlyFronter(_ name: String) -> String {
        String(format: NSLocalizedString("Switch to %@ as the only fronter", comment: "Context menu switch"), name)
    }
    static let switchToOnlyFronterButton = NSLocalizedString("Switch to Only Fronter", comment: "")
    static let switchFront = NSLocalizedString("Switch Front", comment: "")
    static let switchTitle = NSLocalizedString("Switch", comment: "")
    static let selectWhoIsFronting = NSLocalizedString("Select who is fronting", comment: "")
    static let switched = NSLocalizedString("Switched!", comment: "")
    static let clearFront = NSLocalizedString("Clear Front", comment: "")
    static func switchCount(_ count: Int) -> String {
        String(format: NSLocalizedString("Switch (%d)", comment: "Switch button with count"), count)
    }
    static let signOut = NSLocalizedString("Sign Out", comment: "")
    static let signOutConfirmation = NSLocalizedString("Sign out?", comment: "")
    static let refresh = NSLocalizedString("Refresh", comment: "")
    static let url = NSLocalizedString("URL", comment: "")

    // MARK: - Complications
    static func countFronting(_ count: Int) -> String {
        String(format: NSLocalizedString("%d fronting", comment: "Complication fronting count"), count)
    }
    static let noFront = NSLocalizedString("No front", comment: "Complication no fronters")
    static let coFronting = NSLocalizedString("Co-fronting", comment: "")
    static func plusMore(_ count: Int) -> String {
        String(format: NSLocalizedString("+%d more", comment: "Additional fronters count"), count)
    }
    static let noFronters = NSLocalizedString("No fronters", comment: "")
    static let frontingStatus = NSLocalizedString("Fronting Status", comment: "Widget display name")
    static let showsWhosFronting = NSLocalizedString("Shows who's currently fronting", comment: "Widget description")

    // MARK: - Common Actions
    static let cancel = NSLocalizedString("Cancel", comment: "")
    static let save = NSLocalizedString("Save", comment: "")
    static let delete = NSLocalizedString("Delete", comment: "")
    static let edit = NSLocalizedString("Edit", comment: "")
    static let done = NSLocalizedString("Done", comment: "")
    static let ok = NSLocalizedString("OK", comment: "")
    static let yes = NSLocalizedString("Yes", comment: "")
    static let no = NSLocalizedString("No", comment: "")

    // MARK: - Errors
    static let errorTitle = NSLocalizedString("Error", comment: "")
    static let unknownError = NSLocalizedString("An unknown error occurred", comment: "")
    static let passwordsDontMatch = NSLocalizedString("Passwords don't match", comment: "")
    static let passwordTooShort = NSLocalizedString("Password must be at least 8 characters", comment: "")
    static let urlMustStartWithHTTP = NSLocalizedString("URL must start with http:// or https://", comment: "")
    static let invalidURL = NSLocalizedString("Invalid URL", comment: "")
}

// MARK: - LocalizedStringKey Extension
extension LocalizedStringKey {
    /// Creates a LocalizedStringKey from a String constant
    init(_ value: String) {
        self.init(stringLiteral: value)
    }
}
