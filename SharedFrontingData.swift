//
//  SharedFrontingData.swift
//  Sheaf
//
//  Shared data model for complication and app group communication
//

import Foundation

// MARK: - Shared Data Model for Complication
struct SharedFrontingData: Codable {
    let primaryMember: Member?
    let totalCount: Int
    let updatedAt: Date
}
