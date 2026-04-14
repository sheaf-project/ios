# Contributing to Sheaf

Thanks for your interest in contributing! This guide covers the conventions and patterns used throughout the iOS and watchOS client. For a high-level project overview, see [`README.md`](README.md).

## Code style

- **Naming**: PascalCase for types, camelCase for properties/methods.
- **State**: `@State private var` for local view state, `let` for constants.
- **Formatting**: 4-space indentation.
- **Imports**: Minimal imports at top of file.
- **Types**: Leverage Swift's type system. Avoid force unwrapping.
- **Comments**: Only where logic is non-obvious.
- **Testing**: Use the Swift Testing framework (`import Testing`) for unit tests.

## Architecture

- **SwiftUI** for all UI on both iOS and watchOS.
- **MVVM** with `@StateObject`/`@EnvironmentObject` for dependency injection.
- **Swift Concurrency** (`async`/`await`, `Task`) for all async work. Avoid Combine for new code.
- **SystemStore** is the central data store. Views read from its `@Published` properties.
- **APIClient** handles all HTTP with automatic 401 token refresh (with request coalescing).
- **App Group** (`group.systems.lupine.sheaf`) shares data between the iOS app, watch app, and widget extension.
- **WatchConnectivity** syncs credentials to the watch via `updateApplicationContext`, `transferUserInfo`, and `sendMessage`.

## Key patterns

### Authentication flow
Login/register returns `TokenResponse` (access + refresh tokens). Tokens are saved to Keychain (iCloud synced) and UserDefaults. On 401, `APIClient` automatically refreshes the token and retries. Multiple concurrent refreshes are coalesced into a single request.

### Theme system
`ThemeManager` stores the mode (system/light/dark). `Theme` struct provides all colors. Injected via `@Environment(\.theme)`. Always use theme colors instead of hardcoded values.

### Localization
All user-facing strings go through `LocalizedStrings` (type-safe enum) backed by `Localizable.xcstrings`. Use the existing pattern when adding new strings.

### Data models
All models are `Codable` with `CodingKeys` mapping snake_case JSON to camelCase Swift. Dates use ISO 8601 via custom `JSONDecoder.iso` / `JSONEncoder.iso`.

## API

The app talks to a REST API. Base URL is user-configured. Key endpoint groups:

- `/v1/auth/*` — login, register, refresh, TOTP setup/verify, me
- `/v1/systems/me` — system profile
- `/v1/members/*` — CRUD members, custom field values
- `/v1/fronts/*` — fronting entries, current front
- `/v1/groups/*` — groups + member assignments
- `/v1/tags/*`, `/v1/fields/*` — tags and custom fields
- `/v1/import/simplyplural` — Simply Plural import with preview
- `/v1/files/upload` — avatar uploads (multipart)
- `/v1/export` — full data export

## App Group & entitlements

- App Group: `group.systems.lupine.sheaf`
- Keychain sharing enabled (iCloud Keychain sync for watch)
- Entitlements files: `Sheaf.entitlements` (release), `SheafDebug.entitlements` (debug), plus separate entitlements for watch app and widget extension

## Build & distribution

CI builds an unsigned IPA (no code signing, no provisioning profiles). Users sign with their own Apple ID via AltStore, Sideloadly, or SideStore. The workflow is in `.github/workflows/build-and-release.yml`.
