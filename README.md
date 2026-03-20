# Sheaf

<p align="center">
  <img src="https://img.shields.io/badge/Platform-iOS%2017%2B%20%7C%20watchOS%2010%2B-blue" alt="Platform">
  <img src="https://img.shields.io/badge/Swift-6.0-orange" alt="Swift 6.0">
  <img src="https://img.shields.io/badge/SwiftUI-Native-brightgreen" alt="SwiftUI">
  <img src="https://github.com/fullynocturnal/sheaf-ios/actions/workflows/build-and-release.yml/badge.svg" alt="Build Status">
  <a href="https://github.com/fullynocturnal/sheaf-ios/releases/tag/dev"><img src="https://img.shields.io/badge/Download-Dev%20Build-blueviolet" alt="Download Dev Build"></a>
</p>

A native iOS and watchOS companion app for managing plural systems. Sheaf provides a beautiful, privacy-focused interface for tracking fronting history, managing members, organizing groups, and staying connected across devices.

## Features

### 📱 iOS App

- **System Management**
  - View and edit system profile
  - Track current fronters with real-time updates
  - Browse fronting history with timeline views
  - Manage member profiles with custom avatars and colors

- **Member Organization**
  - Create and manage system members
  - Customize member profiles (name, pronouns, description, birthday)
  - Privacy controls (public, friends, private)
  - Group organization with hierarchical support

- **Authentication & Security**
  - Secure token-based authentication
  - TOTP (Two-Factor Authentication) support
  - Refresh token auto-renewal
  - Secure credential storage in Keychain

- **User Experience**
  - Dark mode and light mode support
  - Customizable theme settings (system, light, dark)
  - Quick actions for common tasks
  - App Intents and Shortcuts support
  - Full localization support with String Catalog
  - Simply Plural import functionality

### ⌚ watchOS App

- **Glanceable Information**
  - View current fronters at a glance
  - Browse member list
  - Check system information
  - Seamless sync with iOS app

- **Watch-Specific Features**
  - Optimized for small screen
  - Automatic credential sync from iPhone
  - Independent authentication state
  - Native watchOS UI patterns

### 🔄 Cross-Platform Features

- **Watch Connectivity**
  - Automatic credential synchronization
  - Real-time data sync between iPhone and Watch
  - Background data transfer
  - Session-based communication

- **App Intents & Shortcuts**
  - Quick front switching
  - Add member shortcuts
  - Siri integration
  - Home Screen quick actions

## Architecture

Sheaf is built with modern Swift best practices and Apple platform technologies:

- **SwiftUI**: 100% SwiftUI interface across iOS and watchOS
- **Swift Concurrency**: Async/await for all network operations
- **MVVM Pattern**: Clear separation of concerns with observable objects
- **Watch Connectivity**: Seamless data sync between devices
- **App Intents**: Deep integration with iOS system features

### Key Components

#### Data Layer

- **`Models.swift`**: Core data models (Member, SystemProfile, FrontEntry, SystemGroup)
- **`APIClient.swift`**: Network layer with authentication and API communication
- **`SystemStore`**: Central data store with caching and state management
- **`AuthManager`**: Authentication state and token management

#### iOS App

- **`SheafApp.swift`**: Main app entry point with dependency injection
- **`ContentView`**: Tab-based navigation (Home, Members, Groups, History, Settings)
- **`LoginView`** & **`TOTPView`**: Authentication flows
- **`QuickActions.swift`**: 3D Touch / Haptic Touch quick actions
- **`Theme.swift`**: Theming system with custom color support

#### watchOS App

- **`SheafWatchApp.swift`**: Watch app entry point
- **`WatchStore`**: Watch-optimized data store
- **`WatchConnectivityManager`**: Device-to-device communication
- **`WatchTabView`**: Tab-based navigation for Watch

#### Shared

- **`PhoneConnectivityManager`**: iOS-side Watch Connectivity
- **`SheafShortcuts.swift`**: App Intents and Shortcuts support
- **`LocalizationHelpers.swift`**: Type-safe localization utilities

## Requirements

- **iOS**: 17.0 or later
- **watchOS**: 10.0 or later
- **Xcode**: 16.0 or later
- **Swift**: 6.0

## Getting Started

### Prerequisites

You'll need:
1. A Sheaf-compatible API server endpoint
2. Valid account credentials
3. Xcode 16.0+ installed
4. An iPhone running iOS 17+ (and optionally Apple Watch with watchOS 10+)

### Download Pre-Built App

**🚀 Quick Start**: Download the latest **unsigned** development build from the [dev release](https://github.com/fullynocturnal/sheaf-ios/releases/tag/dev).

**Installation (Easy with AltStore):**
1. Install [AltStore](https://altstore.io/) on your iPhone (free, no paid developer account needed)
2. Download the unsigned `.ipa` from the [dev release](https://github.com/fullynocturnal/sheaf-ios/releases/tag/dev)
3. Open the `.ipa` in AltStore
4. AltStore signs and installs automatically with your Apple ID
5. Trust the app in Settings → General → VPN & Device Management
6. Launch and enjoy!

**Alternative signing tools:**
- [Sideloadly](https://sideloadly.io/) - Popular desktop sideloading tool
- [SideStore](https://sidestore.io/) - No computer needed after setup
- See the `SIGNING_GUIDE.md` in the release for all methods

> **Note**: The IPA is unsigned so users can sign with their own Apple ID. Works on any device - no UDID restrictions! Free Apple IDs work (7-day validity, auto-refreshed by AltStore). Paid accounts get 1-year validity.

### Building from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/fullynocturnal/sheaf-ios.git
   cd sheaf-ios
   ```

2. Open the project in Xcode:
   ```bash
   open Sheaf.xcodeproj
   ```

3. Select your target:
   - **Sheaf** for iOS app
   - **SheafWatch Watch App** for watchOS app

4. Build and run (⌘R)

### First Launch

1. Launch the app on your iPhone
2. Enter your API server URL
3. Sign in with your credentials
4. If TOTP is enabled, enter your verification code
5. Start managing your system!

The Watch app will automatically sync credentials from your iPhone.

## Configuration

### API Endpoint

The app stores your API base URL securely in UserDefaults. On first launch, you'll be prompted to enter:
- Server URL (e.g., `https://api.example.com`)
- Email/username
- Password
- TOTP code (if enabled)

### Theme Settings

Access theme settings from the Settings tab:
- **System**: Follows iOS appearance settings
- **Light**: Always light mode
- **Dark**: Always dark mode

### Privacy Levels

Members and system profile support three privacy levels:
- **Public**: Visible to everyone
- **Friends**: Visible to friends only
- **Private**: Visible only to you

## Localization

Sheaf includes comprehensive localization support:

- **String Catalog**: `Localizable.xcstrings` with translator comments
- **Type-Safe Strings**: `LocalizedStrings` enum prevents typos
- **Formatted Strings**: Support for parameterized localization
- **90+ Strings**: Full coverage of UI elements

### Adding Translations

1. Open `Localizable.xcstrings` in Xcode
2. Add your language in the String Catalog editor
3. Translate each string using the provided context comments
4. Build and test

## Quick Actions

Sheaf supports 3D Touch / Haptic Touch quick actions from the Home Screen:

- **Switch Front**: Quickly update who's fronting
- **Add Member**: Jump directly to member creation

## App Intents

Sheaf integrates with Siri and Shortcuts:

- Query current fronters
- Switch fronting members
- Add new members
- Access via Shortcuts app

## Watch App Features

The Watch app provides:

- **Home Tab**: Current fronters and quick actions
- **Members Tab**: Browse all system members
- **Settings Tab**: View system profile and sign out

All data syncs automatically from your iPhone via Watch Connectivity.

## Project Structure

```
Sheaf/
├── Sheaf/                          # iOS App
│   ├── SheafApp.swift             # App entry point
│   ├── Models.swift               # Data models
│   ├── APIClient.swift            # Network layer
│   ├── SystemStore.swift          # Data store
│   ├── AuthManager.swift          # Authentication
│   ├── Theme.swift                # Theming system
│   ├── QuickActions.swift         # Home Screen actions
│   ├── SheafShortcuts.swift       # App Intents
│   ├── LocalizationHelpers.swift  # Localization utilities
│   ├── Views/
│   │   ├── LoginView.swift
│   │   ├── TOTPView.swift
│   │   ├── ContentView.swift      # Main tab view
│   │   ├── HomeView.swift
│   │   ├── MembersView.swift
│   │   ├── GroupsView.swift
│   │   ├── HistoryView.swift
│   │   ├── SettingsView.swift
│   │   └── ...
│   ├── Components/
│   │   ├── AvatarView.swift
│   │   └── ...
│   └── Localizable.xcstrings       # String Catalog
│
└── SheafWatch Watch App/           # watchOS App
    ├── SheafWatchApp.swift        # Watch app entry
    ├── WatchStore.swift           # Watch data store
    ├── WatchAuthManager.swift     # Watch authentication
    ├── WatchAPIClient.swift       # Watch network layer
    ├── WatchConnectivityManager.swift
    ├── PhoneConnectivityManager.swift
    └── Views/
        ├── WatchTabView.swift
        ├── WatchHomeView.swift
        ├── WatchMembersView.swift
        └── WatchSettingsView.swift
```

## Privacy & Security

Sheaf takes your privacy seriously:

- **Local Storage**: Credentials stored securely in UserDefaults (migrate to Keychain recommended)
- **No Analytics**: No tracking or analytics
- **No Third-Party**: No external dependencies or SDKs
- **Privacy Controls**: Granular privacy settings for members and system
- **Secure Communication**: HTTPS-only API communication
- **Token-Based Auth**: No passwords stored after authentication

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Development Guidelines

1. Follow Swift API Design Guidelines
2. Use SwiftUI best practices
3. Maintain async/await for all async operations
4. Add localization strings to `Localizable.xcstrings`
5. Test on both iOS and watchOS when applicable
6. Update documentation for new features

## Roadmap

- [ ] Migrate to Keychain for credential storage
- [ ] Add widgets for Home Screen and Lock Screen
- [ ] Add complications for watchOS
- [ ] iCloud sync support
- [ ] Offline mode with local caching
- [ ] Custom notifications for system events
- [ ] macOS companion app

## Known Issues

- Multiple `Localizable.xcstrings` target membership can cause build errors (ensure one per target)
- Watch app requires iPhone app to be configured first
- Large member lists may impact performance (pagination planned)

## Acknowledgments

- Built with SwiftUI and Swift Concurrency
- Designed for plural systems and their communities
- Inspired by the need for privacy-focused system management tools

## Support

For questions, issues, or feature requests:
- Open an issue on GitHub
- Join our Discord
