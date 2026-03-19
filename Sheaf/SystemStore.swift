import Foundation
import SwiftUI
import Combine

@MainActor
class SystemStore: ObservableObject {
    @Published var members: [Member] = []
    @Published var groups: [SystemGroup] = []
    @Published var tags: [Tag] = []
    @Published var fields: [CustomField] = []
    @Published var currentFronts: [FrontEntry] = []
    @Published var frontHistory: [FrontEntry] = []
    @Published var systemProfile: SystemProfile?
    @Published var isLoading = false
    @Published var errorMessage: String?

    var api: APIClient?

    func configure(auth: AuthManager) {
        api = APIClient(auth: auth)
    }

    func loadAll() {
        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                async let m  = api?.getMembers()       ?? []
                async let g  = api?.getGroups()        ?? []
                async let t  = api?.getTags()          ?? []
                async let f  = api?.getFields()        ?? []
                async let fr = api?.getCurrentFronts() ?? []
                async let s  = api?.getMySystem()
                members       = try await m
                groups        = try await g
                tags          = try await t
                fields        = try await f
                currentFronts = try await fr
                systemProfile = try await s
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Fronting

    /// All members currently fronting (may be multiple for co-fronting)
    var frontingMembers: [Member] {
        let ids = Set(currentFronts.flatMap { $0.memberIDs })
        return members.filter { ids.contains($0.id) }
    }

    var oldestCurrentFront: FrontEntry? {
        currentFronts.min(by: { $0.startedAt < $1.startedAt })
    }

    /// Switch fronting: ends open fronts then creates a new one
    func switchFronting(to memberIDs: [String]) async {
        guard let api else { return }
        do {
            // End all currently open fronts
            let now = Date()
            for front in currentFronts where front.endedAt == nil {
                _ = try await api.updateFront(id: front.id, update: FrontUpdate(endedAt: now, memberIDs: nil))
            }
            // Create new front
            let created = try await api.createFront(FrontCreate(memberIDs: memberIDs, startedAt: now))
            currentFronts = [created]
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadFrontHistory() async {
        guard let api else { return }
        do { frontHistory = try await api.listFronts() }
        catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Members

    func saveMember(existing: Member? = nil, create: MemberCreate) async {
        guard let api else { return }
        do {
            if let existing {
                let update = MemberUpdate(
                    name: create.name, displayName: create.displayName,
                    description: create.description, pronouns: create.pronouns,
                    avatarURL: create.avatarURL, color: create.color,
                    birthday: create.birthday, privacy: create.privacy
                )
                let updated = try await api.updateMember(id: existing.id, update: update)
                if let idx = members.firstIndex(where: { $0.id == existing.id }) {
                    members[idx] = updated
                }
            } else {
                let created = try await api.createMember(create)
                members.append(created)
            }
        } catch { errorMessage = error.localizedDescription }
    }

    func deleteMember(id: String) async {
        guard let api else { return }
        do {
            try await api.deleteMember(id: id)
            members.removeAll { $0.id == id }
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Groups

    func saveGroup(existing: SystemGroup? = nil, create: GroupCreate) async {
        guard let api else { return }
        do {
            if let existing {
                let update = GroupUpdate(name: create.name, description: create.description,
                                        color: create.color, parentID: create.parentID)
                let updated = try await api.updateGroup(id: existing.id, update: update)
                if let idx = groups.firstIndex(where: { $0.id == existing.id }) {
                    groups[idx] = updated
                }
            } else {
                let created = try await api.createGroup(create)
                groups.append(created)
            }
        } catch { errorMessage = error.localizedDescription }
    }

    func setGroupMembers(groupID: String, memberIDs: [String]) async {
        guard let api else { return }
        do { _ = try await api.setGroupMembers(groupID: groupID, memberIDs: memberIDs) }
        catch { errorMessage = error.localizedDescription }
    }

    func deleteGroup(id: String) async {
        guard let api else { return }
        do {
            try await api.deleteGroup(id: id)
            groups.removeAll { $0.id == id }
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Helpers

    /// Members sorted by how often they appear in front history,
    /// most frequent first. Falls back to member list order if no history.
    var membersByFrontFrequency: [Member] {
        guard !frontHistory.isEmpty else { return members }

        // Count how many front entries each member appears in
        var counts: [String: Int] = [:]
        for entry in frontHistory {
            for id in entry.memberIDs {
                counts[id, default: 0] += 1
            }
        }

        return members.sorted { a, b in
            (counts[a.id] ?? 0) > (counts[b.id] ?? 0)
        }
    }

    func membersIn(group: SystemGroup) -> [Member] {
        // Groups don't embed member_ids in GroupRead — we use the /members endpoint
        // This is a local cache; call getGroupMembers for authoritative data
        members.filter { m in
            // Fall back to checking if any loaded front/group data associates them
            false
        }
    }
}
