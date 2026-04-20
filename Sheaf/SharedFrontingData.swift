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
    let pronouns: String?
    let color: String?
    let avatarURL: String?
    let frontStartedAt: Date?
}

// MARK: - Shared Data Model for Complication
struct SharedFrontingData: Codable {
    let primaryMember: SharedMember?
    let totalCount: Int
    let updatedAt: Date
    let allMembers: [SharedMember]

    init(primaryMember: SharedMember?, totalCount: Int, updatedAt: Date, allMembers: [SharedMember] = []) {
        self.primaryMember = primaryMember
        self.totalCount = totalCount
        self.updatedAt = updatedAt
        self.allMembers = allMembers
    }
}
