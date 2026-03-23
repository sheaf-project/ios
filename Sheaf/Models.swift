import Foundation
import SwiftUI

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
    var privacy: PrivacyLevel
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case systemID     = "system_id"
        case name
        case displayName  = "display_name"
        case description
        case pronouns
        case avatarURL    = "avatar_url"
        case color
        case birthday
        case privacy
        case createdAt    = "created_at"
        case updatedAt    = "updated_at"
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
    var privacy: PrivacyLevel?

    enum CodingKeys: String, CodingKey {
        case name
        case displayName  = "display_name"
        case description
        case pronouns
        case avatarURL    = "avatar_url"
        case color
        case birthday
        case privacy
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
    var privacy: PrivacyLevel?

    enum CodingKeys: String, CodingKey {
        case name
        case displayName  = "display_name"
        case description
        case pronouns
        case avatarURL    = "avatar_url"
        case color
        case birthday
        case privacy
    }
}

// MARK: - SystemRead
struct SystemProfile: Identifiable, Codable {
    let id: String
    var name: String
    var description: String?
    var tag: String?
    var avatarURL: String?
    var color: String?
    var privacy: PrivacyLevel
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, description, tag, color, privacy
        case avatarURL  = "avatar_url"
        case createdAt  = "created_at"
        case updatedAt  = "updated_at"
    }
}

// MARK: - FrontRead
struct FrontEntry: Identifiable, Codable {
    let id: String
    let systemID: String
    var startedAt: Date
    var endedAt: Date?
    var memberIDs: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case systemID  = "system_id"
        case startedAt = "started_at"
        case endedAt   = "ended_at"
        case memberIDs = "member_ids"
    }
}

// MARK: - FrontCreate
struct FrontCreate: Codable {
    var memberIDs: [String]
    var startedAt: Date?

    enum CodingKeys: String, CodingKey {
        case memberIDs = "member_ids"
        case startedAt = "started_at"
    }
}

// MARK: - FrontUpdate
struct FrontUpdate: Codable {
    var endedAt: Date?
    var memberIDs: [String]?

    enum CodingKeys: String, CodingKey {
        case endedAt   = "ended_at"
        case memberIDs = "member_ids"
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

// MARK: - CustomFieldRead
struct CustomField: Identifiable, Codable {
    let id: String
    let systemID: String
    var name: String
    var fieldType: FieldType
    var options: [String: AnyCodable]?
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
    var options: [String: AnyCodable]?
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
    
    enum CodingKeys: String, CodingKey {
        case email, password
        case totpCode = "totp_code"
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
    let createdAt: Date
    let lastLoginAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, email, tier
        case totpEnabled  = "totp_enabled"
        case isAdmin      = "is_admin"
        case createdAt    = "created_at"
        case lastLoginAt  = "last_login_at"
    }
}

struct UserRegister: Codable {
    var email: String
    var password: String
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

// MARK: - AnyCodable
struct AnyCodable: Codable, Hashable {
    let value: Any

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool { false }
    func hash(into hasher: inout Hasher) {}

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(String.self)  { value = v; return }
        if let v = try? c.decode(Int.self)     { value = v; return }
        if let v = try? c.decode(Double.self)  { value = v; return }
        if let v = try? c.decode(Bool.self)    { value = v; return }
        value = ""
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case let v as String:  try c.encode(v)
        case let v as Int:     try c.encode(v)
        case let v as Double:  try c.encode(v)
        case let v as Bool:    try c.encode(v)
        default:               try c.encode("")
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

extension EnvironmentValues {
    var apiBaseURL: String {
        get { self[APIBaseURLKey.self] }
        set { self[APIBaseURLKey.self] = newValue }
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
