//
//  SharedFrontingData.swift
//  Sheaf
//
//  Shared data model for complication and app group communication
//

import Foundation

// MARK: - Simplified Member for Complication Sharing
struct SharedMember: Codable {
    let id: String
    let name: String
    let displayName: String?
    let color: String?
    let avatarURL: String?  // Added to support image avatars
}

// MARK: - Shared Data Model for Complication
struct SharedFrontingData: Codable {
    let primaryMember: SharedMember?
    let totalCount: Int
    let updatedAt: Date
}
