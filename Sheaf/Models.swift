import Foundation
import SwiftUI

// MARK: - Account Status
enum AccountStatus: String, Codable {
    case active = "active"
    case pendingApproval = "pending_approval"
    case suspended = "suspended"
    case banned = "banned"
    case pendingDeletion = "pending_deletion"
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = AccountStatus(rawValue: raw) ?? .unknown
    }
}

// MARK: - Privacy Level
enum PrivacyLevel: String, Codable, CaseIterable {
    case `public` = "public"
    case friends  = "friends"
    case `private` = "private"
}

// MARK: - Member
struct Member: Identifiable, Codable, Hashable {
    let id: String
    let systemID: String
    var name: String
    var displayName: String?
    var description: String?
    var pronouns: String?
    var avatarURL: String?
    var color: String?
    var birthday: String?
    var emoji: String?
    var pluralkitID: String?
    var isCustomFront: Bool
    var privacy: PrivacyLevel
    var note: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case systemID      = "system_id"
        case name
        case displayName   = "display_name"
        case description
        case pronouns
        case avatarURL     = "avatar_url"
        case color
        case birthday
        case emoji
        case pluralkitID   = "pluralkit_id"
        case isCustomFront = "is_custom_front"
        case privacy
        case note
        case createdAt     = "created_at"
        case updatedAt     = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decode(String.self, forKey: .id)
        systemID      = try c.decode(String.self, forKey: .systemID)
        name          = try c.decode(String.self, forKey: .name)
        displayName   = try c.decodeIfPresent(String.self, forKey: .displayName)
        description   = try c.decodeIfPresent(String.self, forKey: .description)
        pronouns      = try c.decodeIfPresent(String.self, forKey: .pronouns)
        avatarURL     = try c.decodeIfPresent(String.self, forKey: .avatarURL)
        color         = try c.decodeIfPresent(String.self, forKey: .color)
        birthday      = try c.decodeIfPresent(String.self, forKey: .birthday)
        emoji         = try c.decodeIfPresent(String.self, forKey: .emoji)
        pluralkitID   = try c.decodeIfPresent(String.self, forKey: .pluralkitID)
        isCustomFront = try c.decodeIfPresent(Bool.self, forKey: .isCustomFront) ?? false
        privacy       = try c.decode(PrivacyLevel.self, forKey: .privacy)
        note          = try c.decodeIfPresent(String.self, forKey: .note)
        createdAt     = try c.decode(Date.self, forKey: .createdAt)
        updatedAt     = try c.decode(Date.self, forKey: .updatedAt)
    }

    init(id: String, systemID: String, name: String, displayName: String? = nil,
         description: String? = nil, pronouns: String? = nil, avatarURL: String? = nil,
         color: String? = nil, birthday: String? = nil, emoji: String? = nil,
         pluralkitID: String? = nil, isCustomFront: Bool = false,
         privacy: PrivacyLevel, note: String? = nil, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.systemID = systemID
        self.name = name
        self.displayName = displayName
        self.description = description
        self.pronouns = pronouns
        self.avatarURL = avatarURL
        self.color = color
        self.birthday = birthday
        self.emoji = emoji
        self.pluralkitID = pluralkitID
        self.isCustomFront = isCustomFront
        self.privacy = privacy
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var displayColor: Color {
        Color(hex: color ?? "#8B5CF6") ?? .purple
    }

    var initials: String {
        let n = displayName ?? name
        let parts = n.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1)) + String(parts[1].prefix(1))
        }
        return String(n.prefix(2)).uppercased()
    }
}

// MARK: - MemberCreate
struct MemberCreate: Codable {
    var name: String
    var displayName: String?
    var description: String?
    var pronouns: String?
    var avatarURL: String?
    var color: String?
    var birthday: String?
    var emoji: String?
    var isCustomFront: Bool?
    var privacy: PrivacyLevel?
    var note: String?

    enum CodingKeys: String, CodingKey {
        case name
        case displayName   = "display_name"
        case description
        case pronouns
        case avatarURL     = "avatar_url"
        case color
        case birthday
        case emoji
        case isCustomFront = "is_custom_front"
        case privacy
        case note
    }
}

// MARK: - MemberUpdate (all optional for PATCH)
struct MemberUpdate: Codable {
    var name: String?
    var displayName: String?
    var description: String?
    var pronouns: String?
    var avatarURL: String?
    var color: String?
    var birthday: String?
    var emoji: String?
    var isCustomFront: Bool?
    var privacy: PrivacyLevel?
    var note: String?

    enum CodingKeys: String, CodingKey {
        case name
        case displayName   = "display_name"
        case description
        case pronouns
        case avatarURL     = "avatar_url"
        case color
        case birthday
        case emoji
        case isCustomFront = "is_custom_front"
        case privacy
        case note
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        // Form-controlled fields are encoded unconditionally so cleared
        // values are sent to the server as JSON null (which the API treats
        // as "clear this field"). Skipping them would leave the prior value
        // in place.
        try c.encodeIfPresent(name, forKey: .name)
        try c.encode(displayName, forKey: .displayName)
        try c.encode(description, forKey: .description)
        try c.encode(pronouns, forKey: .pronouns)
        try c.encode(avatarURL, forKey: .avatarURL)
        try c.encode(color, forKey: .color)
        try c.encode(birthday, forKey: .birthday)
        try c.encode(emoji, forKey: .emoji)
        try c.encodeIfPresent(isCustomFront, forKey: .isCustomFront)
        try c.encodeIfPresent(privacy, forKey: .privacy)
        try c.encode(note, forKey: .note)
    }
}

// MARK: - SystemRead
// MARK: - Delete Confirmation
enum DeleteConfirmation: String, Codable {
    case none = "none"
    case password = "password"
    case totp = "totp"
    case both = "both"
}

// MARK: - Date Format
enum DateFormat: String, Codable {
    case dmy = "dmy"
    case mdy = "mdy"
    case ymd = "ymd"
}

struct SystemProfile: Identifiable, Codable {
    let id: String
    var name: String
    var description: String?
    var note: String?
    var tag: String?
    var avatarURL: String?
    var color: String?
    var privacy: PrivacyLevel
    var deleteConfirmation: DeleteConfirmation
    var dateFormat: DateFormat
    var replaceFrontsDefault: Bool
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, description, note, tag, color, privacy
        case avatarURL            = "avatar_url"
        case deleteConfirmation   = "delete_confirmation"
        case dateFormat           = "date_format"
        case replaceFrontsDefault = "replace_fronts_default"
        case createdAt            = "created_at"
        case updatedAt            = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                   = try c.decode(String.self, forKey: .id)
        name                 = try c.decode(String.self, forKey: .name)
        description          = try c.decodeIfPresent(String.self, forKey: .description)
        note                 = try c.decodeIfPresent(String.self, forKey: .note)
        tag                  = try c.decodeIfPresent(String.self, forKey: .tag)
        avatarURL            = try c.decodeIfPresent(String.self, forKey: .avatarURL)
        color                = try c.decodeIfPresent(String.self, forKey: .color)
        privacy              = try c.decode(PrivacyLevel.self, forKey: .privacy)
        deleteConfirmation   = try c.decodeIfPresent(DeleteConfirmation.self, forKey: .deleteConfirmation) ?? .none
        dateFormat           = try c.decodeIfPresent(DateFormat.self, forKey: .dateFormat) ?? .mdy
        replaceFrontsDefault = try c.decodeIfPresent(Bool.self, forKey: .replaceFrontsDefault) ?? false
        createdAt            = try c.decode(Date.self, forKey: .createdAt)
        updatedAt            = try c.decode(Date.self, forKey: .updatedAt)
    }
}

// MARK: - FrontRead
struct FrontEntry: Identifiable, Codable {
    let id: String
    let systemID: String
    var startedAt: Date
    var endedAt: Date?
    var memberIDs: [String]
    var customStatus: String?

    enum CodingKeys: String, CodingKey {
        case id
        case systemID     = "system_id"
        case startedAt    = "started_at"
        case endedAt      = "ended_at"
        case memberIDs    = "member_ids"
        case customStatus = "custom_status"
    }
}

// MARK: - FrontCreate
struct FrontCreate: Codable {
    var memberIDs: [String]
    var startedAt: Date?
    var replaceFronts: Bool?
    var customStatus: String?

    enum CodingKeys: String, CodingKey {
        case memberIDs     = "member_ids"
        case startedAt     = "started_at"
        case replaceFronts = "replace_fronts"
        case customStatus  = "custom_status"
    }
}

// MARK: - FrontUpdate
struct FrontUpdate: Codable {
    var startedAt: Date?
    var endedAt: Date?
    var memberIDs: [String]?
    var customStatus: String?

    enum CodingKeys: String, CodingKey {
        case startedAt    = "started_at"
        case endedAt      = "ended_at"
        case memberIDs    = "member_ids"
        case customStatus = "custom_status"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(startedAt, forKey: .startedAt)
        try c.encode(endedAt, forKey: .endedAt)
        try c.encodeIfPresent(memberIDs, forKey: .memberIDs)
        try c.encodeIfPresent(customStatus, forKey: .customStatus)
    }
}

// MARK: - Fronting Analytics

struct MemberFrontingStats: Codable, Identifiable {
    let memberID: String
    let isCustomFront: Bool
    var totalSeconds: Int
    var percentOfWindow: Double
    var sessionCount: Int
    var longestSessionSeconds: Int
    var hourOfDaySeconds: [Int]

    var id: String { memberID }

    enum CodingKeys: String, CodingKey {
        case memberID              = "member_id"
        case isCustomFront         = "is_custom_front"
        case totalSeconds          = "total_seconds"
        case percentOfWindow       = "percent_of_window"
        case sessionCount          = "session_count"
        case longestSessionSeconds = "longest_session_seconds"
        case hourOfDaySeconds      = "hour_of_day_seconds"
    }
}

struct FrontingAnalytics: Codable {
    let since: Date
    let until: Date
    let tz: String
    let windowSeconds: Int
    let members: [MemberFrontingStats]

    enum CodingKeys: String, CodingKey {
        case since, until, tz
        case windowSeconds = "window_seconds"
        case members
    }
}

// MARK: - GroupRead
struct SystemGroup: Identifiable, Codable, Hashable {
    let id: String
    let systemID: String
    var name: String
    var description: String?
    var color: String?
    var parentID: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, description, color
        case systemID  = "system_id"
        case parentID  = "parent_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var displayColor: Color {
        Color(hex: color ?? "#6366F1") ?? .indigo
    }
}

// MARK: - GroupCreate
struct GroupCreate: Codable {
    var name: String
    var description: String?
    var color: String?
    var parentID: String?

    enum CodingKeys: String, CodingKey {
        case name, description, color
        case parentID = "parent_id"
    }
}

// MARK: - GroupUpdate
struct GroupUpdate: Codable {
    var name: String?
    var description: String?
    var color: String?
    var parentID: String?

    enum CodingKeys: String, CodingKey {
        case name, description, color
        case parentID = "parent_id"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(description, forKey: .description)
        try c.encode(color, forKey: .color)
        try c.encode(parentID, forKey: .parentID)
    }
}

// MARK: - GroupMemberUpdate
struct GroupMemberUpdate: Codable {
    var memberIDs: [String]

    enum CodingKeys: String, CodingKey {
        case memberIDs = "member_ids"
    }
}

// MARK: - TagRead
struct Tag: Identifiable, Codable, Hashable {
    let id: String
    let systemID: String
    var name: String
    var color: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, color
        case systemID  = "system_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - TagCreate
struct TagCreate: Codable {
    var name: String
    var color: String?
}

// MARK: - FieldType
enum FieldType: String, Codable, CaseIterable {
    case text        = "text"
    case number      = "number"
    case date        = "date"
    case boolean     = "boolean"
    case select      = "select"
    case multiselect = "multiselect"
}

// MARK: - CustomFieldOptions
// Per-field-type options. For select / multiselect, `choices` carries
// the predefined values the user can pick from; nil = freeform tag
// mode (any string accepted server-side). Other field types don't
// carry options today.
struct CustomFieldOptions: Codable, Equatable {
    var choices: [String]?
}

// MARK: - CustomFieldRead
struct CustomField: Identifiable, Codable {
    let id: String
    let systemID: String
    var name: String
    var fieldType: FieldType
    var options: CustomFieldOptions?
    var order: Int
    var privacy: PrivacyLevel
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, options, order, privacy
        case systemID  = "system_id"
        case fieldType = "field_type"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - CustomFieldCreate
struct CustomFieldCreate: Codable {
    var name: String
    var fieldType: FieldType
    var options: CustomFieldOptions?
    var order: Int?
    var privacy: PrivacyLevel?

    enum CodingKeys: String, CodingKey {
        case name, options, order, privacy
        case fieldType = "field_type"
    }
}

// MARK: - CustomFieldValueRead
struct CustomFieldValue: Codable {
    let fieldID: String
    let memberID: String
    var value: AnyCodable

    enum CodingKeys: String, CodingKey {
        case value
        case fieldID  = "field_id"
        case memberID = "member_id"
    }
}

// MARK: - CustomFieldValueSet
struct CustomFieldValueSet: Codable {
    var fieldID: String
    var value: AnyCodable

    enum CodingKeys: String, CodingKey {
        case value
        case fieldID = "field_id"
    }
}

// MARK: - Auth
struct UserLogin: Codable {
    var email: String
    var password: String
    var totpCode: String?
    var captcha: String?
    var rememberDevice: Bool?

    enum CodingKeys: String, CodingKey {
        case email, password, captcha
        case totpCode = "totp_code"
        case rememberDevice = "remember_device"
    }
}

struct TOTPVerify: Codable {
    var code: String
}

struct TOTPSetupResponse: Codable {
    let secret: String
    let provisioningUri: String
    let recoveryCodes: [String]

    enum CodingKeys: String, CodingKey {
        case secret
        case provisioningUri  = "provisioning_uri"
        case recoveryCodes    = "recovery_codes"
    }
}

struct UserRead: Codable {
    let id: String
    let email: String
    let totpEnabled: Bool
    let isAdmin: Bool
    let tier: String
    let accountStatus: AccountStatus
    let emailVerified: Bool
    let newsletterOptIn: Bool
    let createdAt: Date
    let lastLoginAt: Date?
    let deletionRequestedAt: Date?
    let deletionScheduledFor: Date?

    enum CodingKeys: String, CodingKey {
        case id, email, tier
        case totpEnabled          = "totp_enabled"
        case isAdmin              = "is_admin"
        case accountStatus        = "account_status"
        case emailVerified        = "email_verified"
        case newsletterOptIn      = "newsletter_opt_in"
        case createdAt            = "created_at"
        case lastLoginAt          = "last_login_at"
        case deletionRequestedAt  = "deletion_requested_at"
        case deletionScheduledFor = "deletion_scheduled_for"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                   = try c.decode(String.self, forKey: .id)
        email                = try c.decode(String.self, forKey: .email)
        totpEnabled          = try c.decode(Bool.self, forKey: .totpEnabled)
        isAdmin              = try c.decode(Bool.self, forKey: .isAdmin)
        tier                 = try c.decode(String.self, forKey: .tier)
        accountStatus        = try c.decodeIfPresent(AccountStatus.self, forKey: .accountStatus) ?? .active
        emailVerified        = try c.decodeIfPresent(Bool.self, forKey: .emailVerified) ?? true
        newsletterOptIn      = try c.decodeIfPresent(Bool.self, forKey: .newsletterOptIn) ?? false
        createdAt            = try c.decode(Date.self, forKey: .createdAt)
        lastLoginAt          = try c.decodeIfPresent(Date.self, forKey: .lastLoginAt)
        deletionRequestedAt  = try c.decodeIfPresent(Date.self, forKey: .deletionRequestedAt)
        deletionScheduledFor = try c.decodeIfPresent(Date.self, forKey: .deletionScheduledFor)
    }
}

struct UserUpdate: Codable {
    var newsletterOptIn: Bool?

    enum CodingKeys: String, CodingKey {
        case newsletterOptIn = "newsletter_opt_in"
    }
}

struct DeleteAccountRequest: Codable {
    let password: String
    let totpCode: String?

    enum CodingKeys: String, CodingKey {
        case password
        case totpCode = "totp_code"
    }
}

struct UserRegister: Codable {
    var email: String
    var password: String
    var inviteCode: String?
    var captcha: String?

    enum CodingKeys: String, CodingKey {
        case email, password, captcha
        case inviteCode = "invite_code"
    }
}

struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken  = "access_token"
        case refreshToken = "refresh_token"
        case tokenType    = "token_type"
    }
}

/// Returned by POST /v1/auth/sessions/secondary — same as TokenResponse but
/// also carries the new session id so the phone can track its paired watch.
struct SecondarySessionResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let sessionId: String

    enum CodingKeys: String, CodingKey {
        case accessToken  = "access_token"
        case refreshToken = "refresh_token"
        case tokenType    = "token_type"
        case sessionId    = "session_id"
    }
}

struct SecondarySessionRequest: Codable {
    var clientName: String?

    enum CodingKeys: String, CodingKey {
        case clientName = "client_name"
    }
}

struct TokenRefresh: Codable {
    var refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

// MARK: - API Keys
struct ApiKeyRead: Identifiable, Codable {
    let id: String
    let name: String
    let scopes: [String]
    let lastUsedAt: Date?
    let expiresAt: Date?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, scopes
        case lastUsedAt = "last_used_at"
        case expiresAt  = "expires_at"
        case createdAt  = "created_at"
    }
}

struct ApiKeyCreate: Codable {
    var name: String
    var scopes: [String]
    var expiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case name, scopes
        case expiresAt = "expires_at"
    }
}

struct ApiKeyCreated: Codable {
    let id: String
    let name: String
    let scopes: [String]
    let lastUsedAt: Date?
    let expiresAt: Date?
    let createdAt: Date
    let key: String

    enum CodingKeys: String, CodingKey {
        case id, name, scopes, key
        case lastUsedAt = "last_used_at"
        case expiresAt  = "expires_at"
        case createdAt  = "created_at"
    }
}

// MARK: - Sessions
struct SessionRead: Identifiable, Codable {
    let id: String
    let createdIp: String?
    let lastActiveIp: String?
    let userAgent: String?
    let clientName: String?
    let nickname: String?
    let isCurrent: Bool
    let createdAt: Date
    let lastActiveAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, nickname
        case createdIp    = "created_ip"
        case lastActiveIp = "last_active_ip"
        case userAgent    = "user_agent"
        case clientName   = "client_name"
        case isCurrent    = "is_current"
        case createdAt    = "created_at"
        case lastActiveAt = "last_active_at"
    }
}

struct SessionUpdate: Codable {
    let nickname: String
}

// MARK: - AnyCodable
struct AnyCodable: Codable, Hashable {
    let value: Any

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool { false }
    func hash(into hasher: inout Hasher) {}

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil()                          { value = NSNull(); return }
        // Bool before Int so JSON true/false doesn't get mistaken for a number.
        if let v = try? c.decode(Bool.self)       { value = v; return }
        if let v = try? c.decode(Int.self)        { value = v; return }
        if let v = try? c.decode(Double.self)     { value = v; return }
        if let v = try? c.decode(String.self)     { value = v; return }
        if let v = try? c.decode([String].self)   { value = v; return }
        value = NSNull()
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case is NSNull:          try c.encodeNil()
        case let v as Bool:      try c.encode(v)
        case let v as Int:       try c.encode(v)
        case let v as Double:    try c.encode(v)
        case let v as String:    try c.encode(v)
        case let v as [String]:  try c.encode(v)
        default:                 try c.encodeNil()
        }
    }
}

// MARK: - Color helpers
extension Color {
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h = String(h.dropFirst()) }
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return nil }
        let r = Double((val >> 16) & 0xFF) / 255
        let g = Double((val >> 8)  & 0xFF) / 255
        let b = Double(val & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    func toHex() -> String {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r*255), Int(g*255), Int(b*255))
    }
}

// MARK: - API Base URL Environment Key

struct APIBaseURLKey: EnvironmentKey {
    static let defaultValue = ""
}

struct APIAccessTokenKey: EnvironmentKey {
    static let defaultValue = ""
}

extension EnvironmentValues {
    var apiBaseURL: String {
        get { self[APIBaseURLKey.self] }
        set { self[APIBaseURLKey.self] = newValue }
    }

    var apiAccessToken: String {
        get { self[APIAccessTokenKey.self] }
        set { self[APIAccessTokenKey.self] = newValue }
    }
}

// MARK: - Avatar URL Resolution

/// Resolves an avatar URL string into a full URL.
/// Handles three cases:
/// - Relative paths (`/v1/files/...`) — prepends the API base URL
/// - Absolute URLs (`https://...`) — used as-is
/// - Nil/empty — returns nil
func resolveAvatarURL(_ avatarURL: String?, baseURL: String) -> URL? {
    guard let avatarURL, !avatarURL.isEmpty else { return nil }
    if avatarURL.hasPrefix("/") {
        return URL(string: baseURL + avatarURL)
    }
    return URL(string: avatarURL)
}

// MARK: - Admin Models

enum UserTier: String, Codable, CaseIterable {
    case free = "free"
    case plus = "plus"
    case selfHosted = "self_hosted"
    case unknown = "unknown"

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = UserTier(rawValue: raw) ?? .unknown
    }
}

struct AdminUserRead: Codable, Identifiable {
    let id: String
    let email: String
    let tier: UserTier
    let isAdmin: Bool
    let accountStatus: AccountStatus
    let emailVerified: Bool
    let totpEnabled: Bool
    let signupIp: String?
    let memberLimit: Int?
    let storageUsedBytes: Int
    let memberCount: Int
    let createdAt: Date
    let lastLoginAt: Date?
    let suspendedUntil: Date?
    let suspendedReason: String?

    enum CodingKeys: String, CodingKey {
        case id, email, tier
        case isAdmin          = "is_admin"
        case accountStatus    = "account_status"
        case emailVerified    = "email_verified"
        case totpEnabled      = "totp_enabled"
        case signupIp         = "signup_ip"
        case memberLimit      = "member_limit"
        case storageUsedBytes = "storage_used_bytes"
        case memberCount      = "member_count"
        case createdAt        = "created_at"
        case lastLoginAt      = "last_login_at"
        case suspendedUntil   = "suspended_until"
        case suspendedReason  = "suspended_reason"
    }
}

// MARK: - Admin Moderation Requests / Responses

struct AdminReasonRequest: Codable {
    let reason: String
}

struct AdminSuspendRequest: Codable {
    let reason: String
    let durationDays: Int?

    enum CodingKeys: String, CodingKey {
        case reason
        case durationDays = "duration_days"
    }
}

struct AdminSuspendResult: Codable {
    let suspended: Bool
    let suspendedUntil: Date?
    let sessionsRevoked: Int?

    enum CodingKeys: String, CodingKey {
        case suspended
        case suspendedUntil = "suspended_until"
        case sessionsRevoked = "sessions_revoked"
    }
}

struct AdminUnsuspendResult: Codable {
    let unsuspended: Bool
    let reason: String?
}

struct AdminBanResult: Codable {
    let banned: Bool
    let sessionsRevoked: Int

    enum CodingKeys: String, CodingKey {
        case banned
        case sessionsRevoked = "sessions_revoked"
    }
}

struct AdminUnbanResult: Codable {
    let unbanned: Bool
    let reason: String?
}

struct AdminResetSafetyResult: Codable {
    let reset: Bool
    let changedFields: [String]

    enum CodingKeys: String, CodingKey {
        case reset
        case changedFields = "changed_fields"
    }
}

struct AdminBypassPendingResult: Codable {
    let finalizedCount: Int
    let byType: [String: Int]

    enum CodingKeys: String, CodingKey {
        case finalizedCount = "finalized_count"
        case byType = "by_type"
    }
}

struct AdminRotateApiKeysResult: Codable {
    let revokedCount: Int

    enum CodingKeys: String, CodingKey {
        case revokedCount = "revoked_count"
    }
}

struct AdminUserUpdate: Codable {
    var tier: UserTier?
    var isAdmin: Bool?
    var memberLimit: Int?
    var clearMemberLimit: Bool?

    enum CodingKeys: String, CodingKey {
        case tier
        case isAdmin         = "is_admin"
        case memberLimit     = "member_limit"
        case clearMemberLimit = "clear_member_limit"
    }
}

struct AdminAuthStatus {
    let level: String    // "none", "password", "totp"
    let verified: Bool
    let totpEnabled: Bool
}

struct AdminStats {
    var totalUsers: Int
    var totalMembers: Int
    var totalStorageBytes: Int
    var usersByTier: [String: Int]
}

struct AdminStepUpVerify: Codable {
    var password: String?
    var totpCode: String?

    enum CodingKeys: String, CodingKey {
        case password
        case totpCode = "totp_code"
    }
}

struct MemberLimitOverride: Codable {
    var memberLimit: Int?

    enum CodingKeys: String, CodingKey {
        case memberLimit = "member_limit"
    }
}

// MARK: - Password Reset
struct PasswordResetRequest: Codable {
    let email: String
}

struct PasswordReset: Codable {
    let token: String
    let newPassword: String

    enum CodingKeys: String, CodingKey {
        case token
        case newPassword = "new_password"
    }
}

struct AdminResetPasswordRequest: Codable {
    let newPassword: String?

    enum CodingKeys: String, CodingKey {
        case newPassword = "new_password"
    }
}

struct AdminChangeEmailRequest: Codable {
    let newEmail: String

    enum CodingKeys: String, CodingKey {
        case newEmail = "new_email"
    }
}

// MARK: - Delete Confirmation Update
struct DeleteConfirmationUpdate: Codable {
    let level: DeleteConfirmation
    let password: String
    let totpCode: String?

    enum CodingKeys: String, CodingKey {
        case level, password
        case totpCode = "totp_code"
    }
}

// MARK: - Tag Update
struct TagUpdate: Codable {
    var name: String?
    var color: String?
}

// MARK: - Journal Entry
struct JournalEntry: Identifiable, Codable, Hashable {
    let id: String
    let systemID: String
    var memberID: String?
    var title: String?
    var body: String
    var visibility: String
    var authorUserID: String?
    var authorMemberIDs: [String]
    var authorMemberNames: [String]
    let createdAt: Date
    let updatedAt: Date
    var revisionCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, title, body, visibility
        case systemID          = "system_id"
        case memberID          = "member_id"
        case authorUserID      = "author_user_id"
        case authorMemberIDs   = "author_member_ids"
        case authorMemberNames = "author_member_names"
        case createdAt         = "created_at"
        case updatedAt         = "updated_at"
        case revisionCount     = "revision_count"
    }
}

// MARK: - JournalEntryCreate
struct JournalEntryCreate: Codable {
    var memberID: String?
    var title: String?
    var body: String
    var visibility: String = "system"
    var authorMemberIDs: [String]?

    enum CodingKeys: String, CodingKey {
        case title, body, visibility
        case memberID        = "member_id"
        case authorMemberIDs = "author_member_ids"
    }
}

// MARK: - JournalEntryUpdate
struct JournalEntryUpdate: Codable {
    var title: String?
    var body: String?
    var visibility: String?
    var authorMemberIDs: [String]?

    enum CodingKeys: String, CodingKey {
        case title, body, visibility
        case authorMemberIDs = "author_member_ids"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(title, forKey: .title)
        try c.encode(body, forKey: .body)
        try c.encode(visibility, forKey: .visibility)
        try c.encode(authorMemberIDs, forKey: .authorMemberIDs)
    }
}

// MARK: - JournalListResponse
struct JournalListResponse: Codable {
    let items: [JournalEntry]
    let nextCursor: Date?

    enum CodingKeys: String, CodingKey {
        case items
        case nextCursor = "next_cursor"
    }
}

// MARK: - Content Revision
struct ContentRevision: Identifiable, Codable {
    let id: String
    let targetType: String
    let targetID: String
    var userID: String?
    var editorMemberIDs: [String]
    var editorMemberNames: [String]
    var title: String?
    var body: String
    let createdAt: Date
    var pinnedAt: Date?

    var isPinned: Bool { pinnedAt != nil }

    enum CodingKeys: String, CodingKey {
        case id, title, body
        case targetType = "target_type"
        case targetID = "target_id"
        case userID = "user_id"
        case editorMemberIDs = "editor_member_ids"
        case editorMemberNames = "editor_member_names"
        case createdAt = "created_at"
        case pinnedAt = "pinned_at"
    }
}

struct RestoreRevisionRequest: Codable {
    let revisionID: String

    enum CodingKeys: String, CodingKey {
        case revisionID = "revision_id"
    }
}

struct PinRevisionRequest: Codable {
    let revisionID: String

    enum CodingKeys: String, CodingKey {
        case revisionID = "revision_id"
    }
}

struct UnpinRevisionRequest: Codable {
    let revisionID: String
    var password: String?
    var totpCode: String?

    enum CodingKeys: String, CodingKey {
        case revisionID = "revision_id"
        case password
        case totpCode = "totp_code"
    }
}

struct UnpinRevisionResponse: Codable {
    var revision: ContentRevision?
    var pendingActionID: String?
    var finalizeAfter: Date?

    enum CodingKeys: String, CodingKey {
        case revision
        case pendingActionID = "pending_action_id"
        case finalizeAfter = "finalize_after"
    }
}

// MARK: - Custom Field Update
struct CustomFieldUpdate: Codable {
    var name: String?
    var options: CustomFieldOptions?
    var order: Int?
    var privacy: PrivacyLevel?
}

// MARK: - Member Delete Confirmation
struct MemberDeleteConfirm: Codable {
    var password: String?
    var totpCode: String?

    enum CodingKeys: String, CodingKey {
        case password
        case totpCode = "totp_code"
    }
}

// MARK: - Invite Codes (Admin)
struct InviteCodeRead: Codable, Identifiable {
    let id: String
    let code: String
    let createdByEmail: String?
    let maxUses: Int
    let useCount: Int
    let note: String?
    let expiresAt: Date?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, code, note
        case createdByEmail = "created_by_email"
        case maxUses        = "max_uses"
        case useCount       = "use_count"
        case expiresAt      = "expires_at"
        case createdAt      = "created_at"
    }

    var isExpired: Bool {
        if let exp = expiresAt { return exp < Date() }
        return false
    }

    var isExhausted: Bool {
        maxUses > 0 && useCount >= maxUses
    }
}

struct InviteCodeCreate: Codable {
    var maxUses: Int?
    var note: String?
    var expiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case maxUses   = "max_uses"
        case note
        case expiresAt = "expires_at"
    }
}

// MARK: - Pending User (Admin Approvals)
struct PendingUserRead: Codable, Identifiable {
    let id: String
    let email: String
    let emailVerified: Bool
    let signupIp: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, email
        case emailVerified = "email_verified"
        case signupIp      = "signup_ip"
        case createdAt     = "created_at"
    }
}

// MARK: - Simply Plural Import Models
struct SPPreviewMember: Codable, Identifiable {
    let id: String
    let name: String
}

struct SPPreviewCustomFront: Codable, Identifiable {
    let id: String
    let name: String
}

struct SPPreviewSummary: Codable {
    var systemName: String?
    var memberCount: Int
    var members: [SPPreviewMember]
    var customFrontCount: Int
    var customFronts: [SPPreviewCustomFront]
    var frontHistoryCount: Int
    var groupCount: Int
    var customFieldCount: Int
    var noteCount: Int

    enum CodingKeys: String, CodingKey {
        case members
        case customFronts      = "custom_fronts"
        case systemName        = "system_name"
        case memberCount       = "member_count"
        case customFrontCount  = "custom_front_count"
        case frontHistoryCount = "front_history_count"
        case groupCount        = "group_count"
        case customFieldCount  = "custom_field_count"
        case noteCount         = "note_count"
    }
}

struct SPImportResult: Codable {
    var membersImported:      Int
    var customFrontsImported: Int
    var frontsImported:       Int
    var groupsImported:       Int
    var customFieldsImported: Int
    var notesSkipped:         Int
    var warnings:             [String]

    enum CodingKeys: String, CodingKey {
        case warnings
        case membersImported      = "members_imported"
        case customFrontsImported = "custom_fronts_imported"
        case frontsImported       = "fronts_imported"
        case groupsImported       = "groups_imported"
        case customFieldsImported = "custom_fields_imported"
        case notesSkipped         = "notes_skipped"
    }
}

// MARK: - PluralKit Import Models
struct PKPreviewMember: Codable, Identifiable {
    let id: String
    let name: String
}

struct PKPreviewSummary: Codable {
    var systemName: String?
    var memberCount: Int
    var members: [PKPreviewMember]
    var groupCount: Int
    var switchCount: Int
    var earliestSwitch: Date?
    var latestSwitch: Date?

    enum CodingKeys: String, CodingKey {
        case members
        case systemName     = "system_name"
        case memberCount    = "member_count"
        case groupCount     = "group_count"
        case switchCount    = "switch_count"
        case earliestSwitch = "earliest_switch"
        case latestSwitch   = "latest_switch"
    }
}

struct PKImportResult: Codable {
    var membersImported: Int
    var groupsImported:  Int
    var frontsImported:  Int
    var warnings:        [String]

    enum CodingKeys: String, CodingKey {
        case warnings
        case membersImported = "members_imported"
        case groupsImported  = "groups_imported"
        case frontsImported  = "fronts_imported"
    }
}

// MARK: - Tupperbox Import Models
struct TBPreviewMember: Codable, Identifiable {
    let id: String
    let name: String
}

struct TBPreviewSummary: Codable {
    var memberCount: Int
    var members: [TBPreviewMember]
    var groupCount: Int

    enum CodingKeys: String, CodingKey {
        case members
        case memberCount = "member_count"
        case groupCount  = "group_count"
    }
}

struct TBImportResult: Codable {
    var membersImported: Int
    var groupsImported:  Int
    var warnings:        [String]

    enum CodingKeys: String, CodingKey {
        case warnings
        case membersImported = "members_imported"
        case groupsImported  = "groups_imported"
    }
}

// MARK: - Async Import Jobs
//
// The backend retired the synchronous per-source import endpoints in favour of
// a unified async job runner: submit returns a job, and the client polls until
// it reaches a terminal state. The legacy *ImportResult / *PreviewSummary models
// above are still used for the preview step (unchanged, still synchronous) and
// for presenting the final counts once a job completes.

enum ImportJobStatus: String, Codable {
    case pending
    case running
    case complete
    case failed
    case cancelled

    var isTerminal: Bool {
        self == .complete || self == .failed || self == .cancelled
    }
}

struct ImportJobEvent: Codable, Identifiable {
    // The backend doesn't assign event IDs; synthesize one for SwiftUI lists.
    let id = UUID()
    var level: String
    var stage: String
    var message: String
    var recordRef: String?

    enum CodingKeys: String, CodingKey {
        case level, stage, message
        case recordRef = "record_ref"
    }
}

struct ImportJobRead: Codable, Identifiable {
    let id: String
    let source: String
    var status: ImportJobStatus
    var counts: [String: Int]
    var events: [ImportJobEvent]
    var startedAt: Date?
    var finishedAt: Date?
    var lastError: String?
    var archivedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, source, status, counts, events
        case startedAt  = "started_at"
        case finishedAt = "finished_at"
        case lastError  = "last_error"
        case archivedAt = "archived_at"
        case createdAt  = "created_at"
        case updatedAt  = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id         = try c.decode(String.self, forKey: .id)
        source     = try c.decode(String.self, forKey: .source)
        status     = try c.decode(ImportJobStatus.self, forKey: .status)
        counts     = try c.decodeIfPresent([String: Int].self, forKey: .counts) ?? [:]
        events     = try c.decodeIfPresent([ImportJobEvent].self, forKey: .events) ?? []
        startedAt  = try c.decodeIfPresent(Date.self, forKey: .startedAt)
        finishedAt = try c.decodeIfPresent(Date.self, forKey: .finishedAt)
        lastError  = try c.decodeIfPresent(String.self, forKey: .lastError)
        archivedAt = try c.decodeIfPresent(Date.self, forKey: .archivedAt)
        createdAt  = try c.decode(Date.self, forKey: .createdAt)
        updatedAt  = try c.decode(Date.self, forKey: .updatedAt)
    }

    /// Warnings surfaced by the runner, formatted for display.
    var warnings: [String] {
        events
            .filter { $0.level == "warning" }
            .map { ev in
                if let ref = ev.recordRef, !ref.isEmpty { return "\(ref): \(ev.message)" }
                return ev.message
            }
    }
}

/// Lighter list-row version of `ImportJobRead` — drops the (potentially huge)
/// `events` array. Used by the import history list; fetch the full
/// `ImportJobRead` for the detail view.
struct ImportJobSummary: Codable, Identifiable {
    let id: String
    let source: String
    var status: ImportJobStatus
    var counts: [String: Int]
    var startedAt: Date?
    var finishedAt: Date?
    var archivedAt: Date?
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, source, status, counts
        case startedAt  = "started_at"
        case finishedAt = "finished_at"
        case archivedAt = "archived_at"
        case createdAt  = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id         = try c.decode(String.self, forKey: .id)
        source     = try c.decode(String.self, forKey: .source)
        status     = try c.decode(ImportJobStatus.self, forKey: .status)
        counts     = try c.decodeIfPresent([String: Int].self, forKey: .counts) ?? [:]
        startedAt  = try c.decodeIfPresent(Date.self, forKey: .startedAt)
        finishedAt = try c.decodeIfPresent(Date.self, forKey: .finishedAt)
        archivedAt = try c.decodeIfPresent(Date.self, forKey: .archivedAt)
        createdAt  = try c.decode(Date.self, forKey: .createdAt)
    }
}

struct ImportJobList: Codable {
    var items: [ImportJobSummary]
    var nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case items
        case nextCursor = "next_cursor"
    }
}

// MARK: Mapping job counts back to the legacy result models
//
// The runner emits the same `counts` keys the old synchronous *ImportResult
// schemas used, so we keep those models and read keys from the dict.

extension SPImportResult {
    init(job: ImportJobRead) {
        let c = job.counts
        self.init(
            membersImported:      c["members_imported"]       ?? 0,
            customFrontsImported: c["custom_fronts_imported"] ?? 0,
            frontsImported:       c["fronts_imported"]        ?? 0,
            groupsImported:       c["groups_imported"]        ?? 0,
            customFieldsImported: c["custom_fields_imported"] ?? 0,
            notesSkipped:         c["notes_skipped"]          ?? 0,
            warnings:             job.warnings
        )
    }
}

extension PKImportResult {
    init(job: ImportJobRead) {
        let c = job.counts
        self.init(
            membersImported: c["members_imported"] ?? 0,
            groupsImported:  c["groups_imported"]  ?? 0,
            frontsImported:  c["fronts_imported"]  ?? 0,
            warnings:        job.warnings
        )
    }
}

extension TBImportResult {
    init(job: ImportJobRead) {
        let c = job.counts
        self.init(
            membersImported: c["members_imported"] ?? 0,
            groupsImported:  c["groups_imported"]  ?? 0,
            warnings:        job.warnings
        )
    }
}

// MARK: - Announcements

enum AnnouncementSeverity: String, Codable {
    case info     = "info"
    case warning  = "warning"
    case critical = "critical"
}

struct Announcement: Identifiable, Codable {
    let id: String
    let title: String
    let body: String
    let severity: AnnouncementSeverity
    let dismissible: Bool
    let startsAt: Date?
    let expiresAt: Date?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, body, severity, dismissible
        case startsAt  = "starts_at"
        case expiresAt = "expires_at"
        case createdAt = "created_at"
    }
}

struct AnnouncementRead: Identifiable, Codable {
    let id: String
    let title: String
    let body: String
    let severity: AnnouncementSeverity
    let dismissible: Bool
    let active: Bool
    let startsAt: Date?
    let expiresAt: Date?
    let createdAt: Date
    let createdBy: String?
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, body, severity, dismissible, active
        case startsAt   = "starts_at"
        case expiresAt  = "expires_at"
        case createdAt  = "created_at"
        case createdBy  = "created_by"
        case updatedAt  = "updated_at"
    }
}

struct AnnouncementCreate: Codable {
    var title: String
    var body: String
    var severity: AnnouncementSeverity = .info
    var dismissible: Bool = true
    var active: Bool = true
    var startsAt: Date?
    var expiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case title, body, severity, dismissible, active
        case startsAt  = "starts_at"
        case expiresAt = "expires_at"
    }
}

struct AnnouncementUpdate: Codable {
    var title: String?
    var body: String?
    var severity: AnnouncementSeverity?
    var dismissible: Bool?
    var active: Bool?
    var startsAt: Date?
    var expiresAt: Date?
    var clearStartsAt: Bool?
    var clearExpiresAt: Bool?

    enum CodingKeys: String, CodingKey {
        case title, body, severity, dismissible, active
        case startsAt      = "starts_at"
        case expiresAt     = "expires_at"
        case clearStartsAt = "clear_starts_at"
        case clearExpiresAt = "clear_expires_at"
    }
}

// MARK: - Change Password
struct PasswordChange: Codable {
    let currentPassword: String
    let newPassword: String
    let totpCode: String?

    enum CodingKeys: String, CodingKey {
        case currentPassword = "current_password"
        case newPassword     = "new_password"
        case totpCode        = "totp_code"
    }
}

// MARK: - Change Email
struct EmailChange: Codable {
    let newEmail: String
    let currentPassword: String
    let totpCode: String?

    enum CodingKeys: String, CodingKey {
        case newEmail        = "new_email"
        case currentPassword = "current_password"
        case totpCode        = "totp_code"
    }
}

// MARK: - Trusted Devices
struct TrustedDevice: Identifiable, Codable {
    let id: String
    let nickname: String?
    let userAgent: String?
    let createdAt: Date
    let createdIp: String?
    let lastUsedAt: Date?
    let lastUsedIp: String?
    let expiresAt: Date
    let isCurrent: Bool

    enum CodingKeys: String, CodingKey {
        case id, nickname
        case userAgent  = "user_agent"
        case createdAt  = "created_at"
        case createdIp  = "created_ip"
        case lastUsedAt = "last_used_at"
        case lastUsedIp = "last_used_ip"
        case expiresAt  = "expires_at"
        case isCurrent  = "is_current"
    }
}

struct TrustedDeviceRename: Codable {
    let nickname: String
}

// MARK: - System Safety

struct SystemSafetySettings: Codable {
    var gracePeriodDays: Int
    var authTier: DeleteConfirmation
    var appliesToMembers: Bool
    var appliesToGroups: Bool
    var appliesToTags: Bool
    var appliesToFields: Bool
    var appliesToFronts: Bool
    var appliesToJournals: Bool
    var appliesToImages: Bool
    var appliesToRevisions: Bool
    var appliesToNotifications: Bool
    var appliesToReminders: Bool
    var appliesToPolls: Bool
    var appliesToMessages: Bool

    enum CodingKeys: String, CodingKey {
        case gracePeriodDays = "grace_period_days"
        case authTier = "auth_tier"
        case appliesToMembers = "applies_to_members"
        case appliesToGroups = "applies_to_groups"
        case appliesToTags = "applies_to_tags"
        case appliesToFields = "applies_to_fields"
        case appliesToFronts = "applies_to_fronts"
        case appliesToJournals = "applies_to_journals"
        case appliesToImages = "applies_to_images"
        case appliesToRevisions = "applies_to_revisions"
        case appliesToNotifications = "applies_to_notifications"
        case appliesToReminders = "applies_to_reminders"
        case appliesToPolls = "applies_to_polls"
        case appliesToMessages = "applies_to_messages"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        gracePeriodDays = try c.decode(Int.self, forKey: .gracePeriodDays)
        authTier = try c.decode(DeleteConfirmation.self, forKey: .authTier)
        appliesToMembers = try c.decode(Bool.self, forKey: .appliesToMembers)
        appliesToGroups = try c.decode(Bool.self, forKey: .appliesToGroups)
        appliesToTags = try c.decode(Bool.self, forKey: .appliesToTags)
        appliesToFields = try c.decode(Bool.self, forKey: .appliesToFields)
        appliesToFronts = try c.decode(Bool.self, forKey: .appliesToFronts)
        appliesToJournals = try c.decode(Bool.self, forKey: .appliesToJournals)
        appliesToImages = try c.decode(Bool.self, forKey: .appliesToImages)
        appliesToRevisions = try c.decode(Bool.self, forKey: .appliesToRevisions)
        appliesToNotifications = try c.decodeIfPresent(Bool.self, forKey: .appliesToNotifications) ?? false
        appliesToReminders = try c.decodeIfPresent(Bool.self, forKey: .appliesToReminders) ?? false
        appliesToPolls = try c.decodeIfPresent(Bool.self, forKey: .appliesToPolls) ?? false
        appliesToMessages = try c.decodeIfPresent(Bool.self, forKey: .appliesToMessages) ?? false
    }
}

struct SystemSafetyUpdate: Codable {
    var gracePeriodDays: Int?
    var authTier: DeleteConfirmation?
    var appliesToMembers: Bool?
    var appliesToGroups: Bool?
    var appliesToTags: Bool?
    var appliesToFields: Bool?
    var appliesToFronts: Bool?
    var appliesToJournals: Bool?
    var appliesToImages: Bool?
    var appliesToRevisions: Bool?
    var appliesToNotifications: Bool?
    var appliesToReminders: Bool?
    var appliesToPolls: Bool?
    var appliesToMessages: Bool?
    var password: String?
    var totpCode: String?

    enum CodingKeys: String, CodingKey {
        case gracePeriodDays = "grace_period_days"
        case authTier = "auth_tier"
        case appliesToMembers = "applies_to_members"
        case appliesToGroups = "applies_to_groups"
        case appliesToTags = "applies_to_tags"
        case appliesToFields = "applies_to_fields"
        case appliesToFronts = "applies_to_fronts"
        case appliesToJournals = "applies_to_journals"
        case appliesToImages = "applies_to_images"
        case appliesToRevisions = "applies_to_revisions"
        case appliesToNotifications = "applies_to_notifications"
        case appliesToReminders = "applies_to_reminders"
        case appliesToPolls = "applies_to_polls"
        case appliesToMessages = "applies_to_messages"
        case password
        case totpCode = "totp_code"
    }
}

struct PendingAction: Identifiable, Codable {
    let id: String
    let actionType: String
    let targetID: String
    let targetLabel: String
    let requestedAt: Date
    let requestedByUserID: String?
    let finalizeAfter: Date
    let frontingMemberIDs: [String]
    let frontingMemberNames: [String]
    let status: String

    enum CodingKeys: String, CodingKey {
        case id, status
        case actionType = "action_type"
        case targetID = "target_id"
        case targetLabel = "target_label"
        case requestedAt = "requested_at"
        case requestedByUserID = "requested_by_user_id"
        case finalizeAfter = "finalize_after"
        case frontingMemberIDs = "fronting_member_ids"
        case frontingMemberNames = "fronting_member_names"
    }
}

struct SafetyChangeRequest: Identifiable, Codable {
    let id: String
    let requestedAt: Date
    let requestedByUserID: String?
    let finalizeAfter: Date
    let changes: [String: AnyCodable]
    let status: String

    enum CodingKeys: String, CodingKey {
        case id, changes, status
        case requestedAt = "requested_at"
        case requestedByUserID = "requested_by_user_id"
        case finalizeAfter = "finalize_after"
    }
}

struct SystemSafetyResponse: Codable {
    var settings: SystemSafetySettings
    var pendingActions: [PendingAction]
    var pendingChanges: [SafetyChangeRequest]

    enum CodingKeys: String, CodingKey {
        case settings
        case pendingActions = "pending_actions"
        case pendingChanges = "pending_changes"
    }
}

struct SystemSafetyUpdateResponse: Codable {
    let settings: SystemSafetySettings
    let applied: [String]
    let deferred: [String]
    let pendingChange: SafetyChangeRequest?

    enum CodingKeys: String, CodingKey {
        case settings, applied, deferred
        case pendingChange = "pending_change"
    }
}

struct DeleteQueued: Codable {
    let pendingActionID: String
    let finalizeAfter: Date

    enum CodingKeys: String, CodingKey {
        case pendingActionID = "pending_action_id"
        case finalizeAfter = "finalize_after"
    }
}

// MARK: - Notification Channels

enum DestinationType: String, Codable, CaseIterable {
    case webhook = "webhook"
    case ntfy = "ntfy"
    case pushover = "pushover"
    case webPush = "web_push"
    case mobilePush = "mobile_push"
    // Legacy mobile types retained so channels created before the
    // mobile_push unification still decode for read-back. Channel
    // creation rejects these — use .mobilePush instead.
    case fcm = "fcm"
    case apnsDev = "apns_dev"
    case apnsProd = "apns_prod"
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = DestinationType(rawValue: raw) ?? .unknown
    }

    var label: String {
        switch self {
        case .webhook: return "Webhook"
        case .ntfy: return "ntfy"
        case .pushover: return "Pushover"
        case .webPush: return "Web Push"
        case .mobilePush: return "Mobile Push"
        case .fcm: return "Android Push"
        case .apnsDev: return "iPhone Push (Sandbox)"
        case .apnsProd: return "iPhone Push"
        case .unknown: return "Unknown"
        }
    }

    var icon: String {
        switch self {
        case .webhook: return "link"
        case .ntfy: return "bell.badge"
        case .pushover: return "iphone.radiowaves.left.and.right"
        case .webPush: return "globe"
        case .mobilePush: return "iphone.badge.play"
        case .fcm: return "bell.badge.fill"
        case .apnsDev, .apnsProd: return "iphone.badge.play"
        case .unknown: return "questionmark.circle"
        }
    }

    var isMobilePush: Bool {
        switch self {
        case .mobilePush, .apnsDev, .apnsProd, .fcm: return true
        default: return false
        }
    }

    static var creatableTypes: [DestinationType] {
        [.mobilePush, .ntfy, .pushover, .webhook]
    }
}

enum DestinationState: String, Codable {
    case pendingRegistration = "pending_registration"
    case active = "active"
    case disabled = "disabled"
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = DestinationState(rawValue: raw) ?? .unknown
    }

    var label: String {
        switch self {
        case .pendingRegistration: return "Pending"
        case .active: return "Active"
        case .disabled: return "Disabled"
        case .unknown: return "Unknown"
        }
    }
}

enum WebhookFormat: String, Codable, CaseIterable {
    case json = "json"
    case discord = "discord"
    case slack = "slack"
    case plaintext = "plaintext"

    var label: String {
        switch self {
        case .json: return "JSON (Sheaf)"
        case .discord: return "Discord"
        case .slack: return "Slack"
        case .plaintext: return "Plain Text"
        }
    }

    var supportsSignature: Bool {
        self == .json || self == .plaintext
    }
}

enum CofrontRedaction: String, Codable, CaseIterable {
    case count = "count"
    case someone = "someone"
    case suppress = "suppress"

    var label: String {
        switch self {
        case .count: return "Show count"
        case .someone: return "Say \"someone\""
        case .suppress: return "Suppress entirely"
        }
    }
}

enum PayloadSensitivity: String, Codable, CaseIterable {
    case full = "full"
    case minimal = "minimal"
    case bare = "bare"

    var label: String {
        switch self {
        case .full: return "Full"
        case .minimal: return "Minimal"
        case .bare: return "Bare"
        }
    }

    var description: String {
        switch self {
        case .full: return "Names and details"
        case .minimal: return "Counts only, no names"
        case .bare: return "\"A front changed.\""
        }
    }
}

struct WatchToken: Identifiable, Codable {
    let id: String
    let systemID: String
    var label: String?
    var revokedAt: Date?
    let createdAt: Date
    let updatedAt: Date
    var channelCount: Int

    enum CodingKeys: String, CodingKey {
        case id, label
        case systemID     = "system_id"
        case revokedAt    = "revoked_at"
        case createdAt    = "created_at"
        case updatedAt    = "updated_at"
        case channelCount = "channel_count"
    }
}

struct WatchTokenCreate: Codable {
    var label: String?
}

struct WatchTokenUpdate: Codable {
    var label: String?

    enum CodingKeys: String, CodingKey {
        case label
    }

    // Encode label unconditionally so a cleared label is sent as JSON null
    // (which the API treats as "clear this field"). The default synthesized
    // encoder uses encodeIfPresent, which would silently drop the change.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(label, forKey: .label)
    }
}

struct NotificationChannel: Identifiable, Codable {
    let id: String
    let watchTokenID: String
    var name: String
    var destinationType: DestinationType
    var destinationState: DestinationState
    var destinationConfig: [String: String]
    var triggerOnStart: Bool
    var triggerOnStop: Bool
    var triggerOnCofrontChange: Bool
    var cofrontRedaction: CofrontRedaction
    var payloadSensitivity: PayloadSensitivity
    var debounceSeconds: Int
    var baseAllMembers: Bool
    var baseIncludePrivate: Bool
    var lastDeliveredAt: Date?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name
        case watchTokenID          = "watch_token_id"
        case destinationType       = "destination_type"
        case destinationState      = "destination_state"
        case destinationConfig     = "destination_config"
        case triggerOnStart        = "trigger_on_start"
        case triggerOnStop         = "trigger_on_stop"
        case triggerOnCofrontChange = "trigger_on_cofront_change"
        case cofrontRedaction      = "cofront_redaction"
        case payloadSensitivity    = "payload_sensitivity"
        case debounceSeconds       = "debounce_seconds"
        case baseAllMembers        = "base_all_members"
        case baseIncludePrivate    = "base_include_private"
        case lastDeliveredAt       = "last_delivered_at"
        case createdAt             = "created_at"
        case updatedAt             = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                  = try c.decode(String.self, forKey: .id)
        watchTokenID        = try c.decode(String.self, forKey: .watchTokenID)
        name                = try c.decode(String.self, forKey: .name)
        destinationType     = try c.decode(DestinationType.self, forKey: .destinationType)
        destinationState    = try c.decode(DestinationState.self, forKey: .destinationState)
        destinationConfig   = (try? c.decode([String: String].self, forKey: .destinationConfig)) ?? [:]
        triggerOnStart      = try c.decode(Bool.self, forKey: .triggerOnStart)
        triggerOnStop       = try c.decode(Bool.self, forKey: .triggerOnStop)
        triggerOnCofrontChange = try c.decode(Bool.self, forKey: .triggerOnCofrontChange)
        cofrontRedaction    = try c.decode(CofrontRedaction.self, forKey: .cofrontRedaction)
        payloadSensitivity  = try c.decode(PayloadSensitivity.self, forKey: .payloadSensitivity)
        debounceSeconds     = try c.decode(Int.self, forKey: .debounceSeconds)
        baseAllMembers      = try c.decode(Bool.self, forKey: .baseAllMembers)
        baseIncludePrivate  = try c.decode(Bool.self, forKey: .baseIncludePrivate)
        lastDeliveredAt     = try c.decodeIfPresent(Date.self, forKey: .lastDeliveredAt)
        createdAt           = try c.decode(Date.self, forKey: .createdAt)
        updatedAt           = try c.decode(Date.self, forKey: .updatedAt)
    }
}

struct NotificationChannelCreate: Codable {
    var name: String
    var destinationType: DestinationType
    var destinationConfig: [String: String]?
    var webhookSecret: String?
    var triggerOnStart: Bool = true
    var triggerOnStop: Bool = false
    var triggerOnCofrontChange: Bool = false
    var cofrontRedaction: CofrontRedaction = .count
    var payloadSensitivity: PayloadSensitivity = .full
    var debounceSeconds: Int = 30
    var baseAllMembers: Bool = true
    var baseIncludePrivate: Bool = false

    enum CodingKeys: String, CodingKey {
        case name
        case destinationType       = "destination_type"
        case destinationConfig     = "destination_config"
        case webhookSecret         = "webhook_secret"
        case triggerOnStart        = "trigger_on_start"
        case triggerOnStop         = "trigger_on_stop"
        case triggerOnCofrontChange = "trigger_on_cofront_change"
        case cofrontRedaction      = "cofront_redaction"
        case payloadSensitivity    = "payload_sensitivity"
        case debounceSeconds       = "debounce_seconds"
        case baseAllMembers        = "base_all_members"
        case baseIncludePrivate    = "base_include_private"
    }
}

struct NotificationChannelUpdate: Codable {
    var name: String?
    var destinationConfig: [String: String]?
    var webhookSecret: String?
    var triggerOnStart: Bool?
    var triggerOnStop: Bool?
    var triggerOnCofrontChange: Bool?
    var cofrontRedaction: CofrontRedaction?
    var payloadSensitivity: PayloadSensitivity?
    var debounceSeconds: Int?
    var baseAllMembers: Bool?
    var baseIncludePrivate: Bool?

    enum CodingKeys: String, CodingKey {
        case name
        case destinationConfig     = "destination_config"
        case webhookSecret         = "webhook_secret"
        case triggerOnStart        = "trigger_on_start"
        case triggerOnStop         = "trigger_on_stop"
        case triggerOnCofrontChange = "trigger_on_cofront_change"
        case cofrontRedaction      = "cofront_redaction"
        case payloadSensitivity    = "payload_sensitivity"
        case debounceSeconds       = "debounce_seconds"
        case baseAllMembers        = "base_all_members"
        case baseIncludePrivate    = "base_include_private"
    }
}

struct ChannelCreateResponse: Codable {
    let channel: NotificationChannel
    var activationURL: String?
    var activationExpiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case channel
        case activationURL       = "activation_url"
        case activationExpiresAt = "activation_expires_at"
    }
}

struct ChannelActivationResponse: Codable {
    let activationURL: String
    var activationExpiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case activationURL       = "activation_url"
        case activationExpiresAt = "activation_expires_at"
    }
}

struct TestDispatchResponse: Codable {
    let delivered: Bool
    var error: String?
}

// MARK: - Push Device Tokens

enum PushDevicePlatform: String, Codable {
    case fcm = "fcm"
    case apnsDev = "apns_dev"
    case apnsProd = "apns_prod"
}

struct PushDevice: Identifiable, Codable {
    let id: String
    let platform: PushDevicePlatform
    let appVersion: String?
    let installId: String?
    let createdAt: Date
    let lastSeenAt: Date

    enum CodingKeys: String, CodingKey {
        case id, platform
        case appVersion = "app_version"
        case installId  = "install_id"
        case createdAt  = "created_at"
        case lastSeenAt = "last_seen_at"
    }
}

struct PushDeviceRegister: Codable {
    let platform: PushDevicePlatform
    let token: String
    var installId: String?
    var appVersion: String?

    enum CodingKeys: String, CodingKey {
        case platform, token
        case installId  = "install_id"
        case appVersion = "app_version"
    }
}

struct PushDeviceDelete: Codable {
    let token: String
}

// MARK: - Polls

enum PollKind: String, Codable, CaseIterable {
    case singleChoice = "single_choice"
    case multiChoice = "multi_choice"

    var label: String {
        switch self {
        case .singleChoice: return "Single Choice"
        case .multiChoice: return "Multiple Choice"
        }
    }
}

enum PollResultsVisibility: String, Codable, CaseIterable {
    case live = "live"
    case endOnly = "end_only"

    var label: String {
        switch self {
        case .live: return "Live"
        case .endOnly: return "After Closing"
        }
    }

    var description: String {
        switch self {
        case .live: return "Results visible while poll is open"
        case .endOnly: return "Results hidden until poll closes"
        }
    }
}

struct PollOption: Identifiable, Codable, Hashable {
    let id: String
    let text: String
    let position: Int
}

struct PollTallyEntry: Codable {
    let optionID: String
    let count: Int

    enum CodingKeys: String, CodingKey {
        case optionID = "option_id"
        case count
    }
}

struct PollVote: Codable {
    let votedAsMemberID: String
    let optionIDs: [String]
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case votedAsMemberID = "voted_as_member_id"
        case optionIDs = "option_ids"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct Poll: Identifiable, Codable {
    let id: String
    let systemID: String
    let question: String
    let description: String?
    let kind: PollKind
    let resultsVisibility: PollResultsVisibility
    let closesAt: Date
    let retentionDays: Int
    let includeCustomFronts: Bool
    let restrictVotingToFronters: Bool
    let options: [PollOption]
    let isClosed: Bool
    let closedSince: Date?
    let purgesAt: Date
    var totalVotes: Int
    var tally: [PollTallyEntry]?
    var votes: [PollVote]?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, question, description, kind, options
        case systemID = "system_id"
        case resultsVisibility = "results_visibility"
        case closesAt = "closes_at"
        case retentionDays = "retention_days"
        case includeCustomFronts = "include_custom_fronts"
        case restrictVotingToFronters = "restrict_voting_to_fronters"
        case isClosed = "is_closed"
        case closedSince = "closed_since"
        case purgesAt = "purges_at"
        case totalVotes = "total_votes"
        case tally, votes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                  = try c.decode(String.self, forKey: .id)
        systemID            = try c.decode(String.self, forKey: .systemID)
        question            = try c.decode(String.self, forKey: .question)
        description         = try c.decodeIfPresent(String.self, forKey: .description)
        kind                = try c.decode(PollKind.self, forKey: .kind)
        resultsVisibility   = try c.decode(PollResultsVisibility.self, forKey: .resultsVisibility)
        closesAt            = try c.decode(Date.self, forKey: .closesAt)
        retentionDays       = try c.decode(Int.self, forKey: .retentionDays)
        includeCustomFronts = try c.decodeIfPresent(Bool.self, forKey: .includeCustomFronts) ?? false
        restrictVotingToFronters = try c.decodeIfPresent(Bool.self, forKey: .restrictVotingToFronters) ?? false
        options             = try c.decode([PollOption].self, forKey: .options)
        isClosed            = try c.decode(Bool.self, forKey: .isClosed)
        closedSince         = try c.decodeIfPresent(Date.self, forKey: .closedSince)
        purgesAt            = try c.decode(Date.self, forKey: .purgesAt)
        totalVotes          = try c.decode(Int.self, forKey: .totalVotes)
        tally               = try c.decodeIfPresent([PollTallyEntry].self, forKey: .tally)
        votes               = try c.decodeIfPresent([PollVote].self, forKey: .votes)
        createdAt           = try c.decode(Date.self, forKey: .createdAt)
        updatedAt           = try c.decode(Date.self, forKey: .updatedAt)
    }

    /// Memberwise init — used for optimistic local construction (e.g. a poll
    /// the user just created while offline). The custom `init(from:)` decoder
    /// suppresses Swift's auto-synthesised one, so it's spelled out here.
    init(
        id: String, systemID: String, question: String, description: String?,
        kind: PollKind, resultsVisibility: PollResultsVisibility,
        closesAt: Date, retentionDays: Int, includeCustomFronts: Bool,
        restrictVotingToFronters: Bool,
        options: [PollOption], isClosed: Bool, closedSince: Date?,
        purgesAt: Date, totalVotes: Int,
        tally: [PollTallyEntry]?, votes: [PollVote]?,
        createdAt: Date, updatedAt: Date
    ) {
        self.id = id
        self.systemID = systemID
        self.question = question
        self.description = description
        self.kind = kind
        self.resultsVisibility = resultsVisibility
        self.closesAt = closesAt
        self.retentionDays = retentionDays
        self.includeCustomFronts = includeCustomFronts
        self.restrictVotingToFronters = restrictVotingToFronters
        self.options = options
        self.isClosed = isClosed
        self.closedSince = closedSince
        self.purgesAt = purgesAt
        self.totalVotes = totalVotes
        self.tally = tally
        self.votes = votes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct PollOptionCreate: Codable {
    let text: String
}

struct PollCreate: Codable {
    var question: String
    var description: String?
    var kind: PollKind
    var resultsVisibility: PollResultsVisibility
    var closesAt: Date
    var retentionDays: Int?
    var includeCustomFronts: Bool?
    var restrictVotingToFronters: Bool?
    var options: [PollOptionCreate]

    enum CodingKeys: String, CodingKey {
        case question, description, kind, options
        case resultsVisibility = "results_visibility"
        case closesAt = "closes_at"
        case retentionDays = "retention_days"
        case includeCustomFronts = "include_custom_fronts"
        case restrictVotingToFronters = "restrict_voting_to_fronters"
    }
}

struct VoteCast: Codable {
    let votedAsMemberID: String
    let optionIDs: [String]

    enum CodingKeys: String, CodingKey {
        case votedAsMemberID = "voted_as_member_id"
        case optionIDs = "option_ids"
    }
}

struct PollVoteRead: Codable {
    let votedAsMemberID: String
    let optionIDs: [String]
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case votedAsMemberID = "voted_as_member_id"
        case optionIDs = "option_ids"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Reminders

enum ReminderTriggerType: String, Codable, CaseIterable {
    case automated = "automated"
    case repeated = "repeated"

    var label: String {
        switch self {
        case .automated: return "Automated"
        case .repeated: return "Repeated"
        }
    }
}

enum ReminderTriggerEvent: String, Codable, CaseIterable {
    case start = "start"
    case stop = "stop"
    case any = "any"

    var label: String {
        switch self {
        case .start: return "Starts fronting"
        case .stop: return "Stops fronting"
        case .any: return "Any change"
        }
    }
}

enum ReminderScheduleKind: String, Codable, CaseIterable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"

    var label: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        }
    }
}

enum ReminderScope: String, Codable, CaseIterable {
    case system = "system"
    case member = "member"

    var label: String {
        switch self {
        case .system: return "Everyone"
        case .member: return "Specific members"
        }
    }
}

struct Reminder: Identifiable, Codable {
    let id: String
    let systemID: String
    let channelID: String
    var name: String
    var title: String
    var body: String?
    var enabled: Bool
    var triggerType: String

    var triggerMemberID: String?
    var triggerEvent: String?
    var delaySeconds: Int?

    var scheduleKind: String?
    var scheduleTime: String?
    var scheduleDowMask: Int?
    var scheduleDom: Int?
    var scheduleTz: String?
    var cronExpression: String?

    var scope: String?
    var scopeMemberIDs: [String]?
    var digestWhenAbsent: Bool?

    var lastFiredAt: Date?
    var pendingCount: Int?
    var nextFireAt: Date?

    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, title, body, enabled, scope
        case systemID = "system_id"
        case channelID = "channel_id"
        case triggerType = "trigger_type"
        case triggerMemberID = "trigger_member_id"
        case triggerEvent = "trigger_event"
        case delaySeconds = "delay_seconds"
        case scheduleKind = "schedule_kind"
        case scheduleTime = "schedule_time"
        case scheduleDowMask = "schedule_dow_mask"
        case scheduleDom = "schedule_dom"
        case scheduleTz = "schedule_tz"
        case cronExpression = "cron_expression"
        case scopeMemberIDs = "scope_member_ids"
        case digestWhenAbsent = "digest_when_absent"
        case lastFiredAt = "last_fired_at"
        case pendingCount = "pending_count"
        case nextFireAt = "next_fire_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        systemID = try c.decode(String.self, forKey: .systemID)
        channelID = try c.decode(String.self, forKey: .channelID)
        name = try c.decode(String.self, forKey: .name)
        title = try c.decode(String.self, forKey: .title)
        body = try c.decodeIfPresent(String.self, forKey: .body)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        triggerType = try c.decode(String.self, forKey: .triggerType)
        triggerMemberID = try c.decodeIfPresent(String.self, forKey: .triggerMemberID)
        triggerEvent = try c.decodeIfPresent(String.self, forKey: .triggerEvent)
        delaySeconds = try c.decodeIfPresent(Int.self, forKey: .delaySeconds)
        scheduleKind = try c.decodeIfPresent(String.self, forKey: .scheduleKind)
        scheduleTime = try c.decodeIfPresent(String.self, forKey: .scheduleTime)
        scheduleDowMask = try c.decodeIfPresent(Int.self, forKey: .scheduleDowMask)
        scheduleDom = try c.decodeIfPresent(Int.self, forKey: .scheduleDom)
        scheduleTz = try c.decodeIfPresent(String.self, forKey: .scheduleTz)
        cronExpression = try c.decodeIfPresent(String.self, forKey: .cronExpression)
        scope = try c.decodeIfPresent(String.self, forKey: .scope)
        scopeMemberIDs = try c.decodeIfPresent([String].self, forKey: .scopeMemberIDs)
        digestWhenAbsent = try c.decodeIfPresent(Bool.self, forKey: .digestWhenAbsent)
        lastFiredAt = try c.decodeIfPresent(Date.self, forKey: .lastFiredAt)
        pendingCount = try c.decodeIfPresent(Int.self, forKey: .pendingCount)
        nextFireAt = try c.decodeIfPresent(Date.self, forKey: .nextFireAt)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
    }

    var parsedTriggerType: ReminderTriggerType {
        ReminderTriggerType(rawValue: triggerType) ?? .automated
    }

    var parsedScheduleKind: ReminderScheduleKind? {
        scheduleKind.flatMap { ReminderScheduleKind(rawValue: $0) }
    }

    var scheduleDescription: String {
        if parsedTriggerType == .automated {
            let event = triggerEvent.flatMap { ReminderTriggerEvent(rawValue: $0) }?.label ?? "Any change"
            let delay = delaySeconds ?? 0
            var desc = event
            if delay > 0 {
                let minutes = delay / 60
                if minutes >= 60 {
                    desc += " + \(minutes / 60)h delay"
                } else if minutes > 0 {
                    desc += " + \(minutes)m delay"
                } else {
                    desc += " + \(delay)s delay"
                }
            }
            return desc
        }

        if let cron = cronExpression, !cron.isEmpty {
            return "Cron: \(cron)"
        }

        guard let kind = parsedScheduleKind, let time = scheduleTime else {
            return "Schedule not set"
        }

        switch kind {
        case .daily:
            return "Daily at \(time)"
        case .weekly:
            let days = dowMaskToLabels(scheduleDowMask ?? 0)
            return "Weekly \(days) at \(time)"
        case .monthly:
            let dom = scheduleDom ?? 1
            return "Monthly on day \(dom) at \(time)"
        }
    }

    private func dowMaskToLabels(_ mask: Int) -> String {
        let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        var result: [String] = []
        for i in 0..<7 {
            if mask & (1 << i) != 0 {
                result.append(dayNames[i])
            }
        }
        return result.isEmpty ? "No days" : result.joined(separator: ", ")
    }
}

struct ReminderCreate: Codable {
    var name: String
    var title: String
    var body: String?
    var enabled: Bool = true
    var channelID: String
    var triggerType: String

    var triggerMemberID: String?
    var triggerEvent: String?
    var delaySeconds: Int?

    var scheduleKind: String?
    var scheduleTime: String?
    var scheduleDowMask: Int?
    var scheduleDom: Int?
    var scheduleTz: String?
    var cronExpression: String?

    var scope: String?
    var scopeMemberIDs: [String]?
    var digestWhenAbsent: Bool?

    enum CodingKeys: String, CodingKey {
        case name, title, body, enabled, scope
        case channelID = "channel_id"
        case triggerType = "trigger_type"
        case triggerMemberID = "trigger_member_id"
        case triggerEvent = "trigger_event"
        case delaySeconds = "delay_seconds"
        case scheduleKind = "schedule_kind"
        case scheduleTime = "schedule_time"
        case scheduleDowMask = "schedule_dow_mask"
        case scheduleDom = "schedule_dom"
        case scheduleTz = "schedule_tz"
        case cronExpression = "cron_expression"
        case scopeMemberIDs = "scope_member_ids"
        case digestWhenAbsent = "digest_when_absent"
    }
}

struct ReminderUpdate: Codable {
    var name: String?
    var title: String?
    var body: String?
    var enabled: Bool?
    var channelID: String?
    var triggerType: String?

    var triggerMemberID: String?
    var triggerEvent: String?
    var delaySeconds: Int?

    var scheduleKind: String?
    var scheduleTime: String?
    var scheduleDowMask: Int?
    var scheduleDom: Int?
    var scheduleTz: String?
    var cronExpression: String?

    var scope: String?
    var scopeMemberIDs: [String]?
    var digestWhenAbsent: Bool?

    enum CodingKeys: String, CodingKey {
        case name, title, body, enabled, scope
        case channelID = "channel_id"
        case triggerType = "trigger_type"
        case triggerMemberID = "trigger_member_id"
        case triggerEvent = "trigger_event"
        case delaySeconds = "delay_seconds"
        case scheduleKind = "schedule_kind"
        case scheduleTime = "schedule_time"
        case scheduleDowMask = "schedule_dow_mask"
        case scheduleDom = "schedule_dom"
        case scheduleTz = "schedule_tz"
        case cronExpression = "cron_expression"
        case scopeMemberIDs = "scope_member_ids"
        case digestWhenAbsent = "digest_when_absent"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(title, forKey: .title)
        try c.encode(body, forKey: .body)
        try c.encode(enabled, forKey: .enabled)
        try c.encode(channelID, forKey: .channelID)
        try c.encode(triggerType, forKey: .triggerType)
        try c.encode(triggerMemberID, forKey: .triggerMemberID)
        try c.encode(triggerEvent, forKey: .triggerEvent)
        try c.encode(delaySeconds, forKey: .delaySeconds)
        try c.encode(scheduleKind, forKey: .scheduleKind)
        try c.encode(scheduleTime, forKey: .scheduleTime)
        try c.encode(scheduleDowMask, forKey: .scheduleDowMask)
        try c.encode(scheduleDom, forKey: .scheduleDom)
        try c.encode(scheduleTz, forKey: .scheduleTz)
        try c.encode(cronExpression, forKey: .cronExpression)
        try c.encode(scope, forKey: .scope)
        try c.encode(scopeMemberIDs, forKey: .scopeMemberIDs)
        try c.encode(digestWhenAbsent, forKey: .digestWhenAbsent)
    }
}

struct ReminderNextFire: Codable {
    let nextFireAt: Date?

    enum CodingKeys: String, CodingKey {
        case nextFireAt = "next_fire_at"
    }
}

// MARK: - Polls

struct PollServerConfig: Codable {
    let tier: String
    let minCloseSeconds: Int
    let maxCloseSeconds: Int
    let defaultRetentionDays: Int
    let maxRetentionDays: Int
    let maxConcurrentOpenPolls: Int

    enum CodingKeys: String, CodingKey {
        case tier
        case minCloseSeconds = "min_close_seconds"
        case maxCloseSeconds = "max_close_seconds"
        case defaultRetentionDays = "default_retention_days"
        case maxRetentionDays = "max_retention_days"
        case maxConcurrentOpenPolls = "max_concurrent_open_polls"
    }
}

enum PollAuditAction: String, Codable {
    case cast = "cast"
    case change = "change"
    case withdraw = "withdraw"
}

struct PollVoteEvent: Identifiable, Codable {
    let id: String
    let votedAsMemberID: String?
    let action: PollAuditAction
    let optionIDs: [String]
    let frontingMemberIDs: [String]
    let actorUserID: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, action
        case votedAsMemberID = "voted_as_member_id"
        case optionIDs = "option_ids"
        case frontingMemberIDs = "fronting_member_ids"
        case actorUserID = "actor_user_id"
        case createdAt = "created_at"
    }
}

struct PollAuditRead: Codable {
    let pollID: String
    let isVisible: Bool
    let events: [PollVoteEvent]

    enum CodingKeys: String, CodingKey {
        case pollID = "poll_id"
        case isVisible = "is_visible"
        case events
    }
}

// MARK: - Message Board

enum BoardKind: String, Codable {
    case system = "system"
    case member = "member"
}

struct BoardSummary: Identifiable, Codable {
    let boardKind: BoardKind
    let boardMemberID: String?
    let memberName: String?
    let lastMessageAt: Date?
    let lastMessagePreview: String?
    let messageCount: Int
    let unreadCount: Int

    var id: String {
        if boardKind == .system { return "system" }
        return boardMemberID ?? "unknown"
    }

    var displayName: String {
        if boardKind == .system { return "System Board" }
        return memberName ?? "Unknown Member"
    }

    enum CodingKeys: String, CodingKey {
        case boardKind = "board_kind"
        case boardMemberID = "board_member_id"
        case memberName = "member_name"
        case lastMessageAt = "last_message_at"
        case lastMessagePreview = "last_message_preview"
        case messageCount = "message_count"
        case unreadCount = "unread_count"
    }
}

struct BoardMessage: Identifiable, Codable {
    let id: String
    let systemID: String
    let boardKind: BoardKind
    let boardMemberID: String?
    let authorMemberID: String?
    let authorMemberName: String?
    let parentMessageID: String?
    let parentPreview: String?
    let parentAuthorMemberName: String?
    let body: String
    let createdAt: Date
    let updatedAt: Date

    var isEdited: Bool { updatedAt > createdAt }

    enum CodingKeys: String, CodingKey {
        case id
        case systemID = "system_id"
        case boardKind = "board_kind"
        case boardMemberID = "board_member_id"
        case authorMemberID = "author_member_id"
        case authorMemberName = "author_member_name"
        case parentMessageID = "parent_message_id"
        case parentPreview = "parent_preview"
        case parentAuthorMemberName = "parent_author_member_name"
        case body
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct MessagesPage: Codable {
    let boardKind: BoardKind
    let boardMemberID: String?
    let messages: [BoardMessage]
    let callerLastSeenAt: Date?

    enum CodingKeys: String, CodingKey {
        case boardKind = "board_kind"
        case boardMemberID = "board_member_id"
        case messages
        case callerLastSeenAt = "caller_last_seen_at"
    }
}

struct MessageCreate: Codable {
    var boardKind: BoardKind
    var boardMemberID: String?
    var authorMemberID: String
    var parentMessageID: String?
    var body: String

    enum CodingKeys: String, CodingKey {
        case boardKind = "board_kind"
        case boardMemberID = "board_member_id"
        case authorMemberID = "author_member_id"
        case parentMessageID = "parent_message_id"
        case body
    }
}

struct MessageUpdate: Codable {
    var body: String
}

struct MarkSeenRequest: Codable {
    var memberID: String
    var boardKind: BoardKind
    var boardMemberID: String?

    enum CodingKeys: String, CodingKey {
        case memberID = "member_id"
        case boardKind = "board_kind"
        case boardMemberID = "board_member_id"
    }
}

struct UnreadCounts: Codable {
    let memberID: String
    let total: Int
    let byBoard: [BoardSummary]

    enum CodingKeys: String, CodingKey {
        case memberID = "member_id"
        case total
        case byBoard = "by_board"
    }
}
