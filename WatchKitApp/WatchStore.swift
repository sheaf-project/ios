import Foundation
import SwiftUI
import Combine
#if os(watchOS)
import WidgetKit
#endif

/// Thin observable store for the watch — same shape as iOS SystemStore
/// but using WatchAuthManager so it compiles without UIKit dependencies.
@MainActor
class WatchStore: ObservableObject {
    @Published var members: [Member]      = []
    @Published var groups: [SystemGroup]  = []
    @Published var currentFronts: [FrontEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var api: WatchAPIClient?

    func configure(auth: WatchAuthManager) {
        api = WatchAPIClient(auth: auth)
    }

    func loadAll() {
        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                async let m  = api?.getMembers()       ?? []
                async let fr = api?.getCurrentFronts() ?? []
                members       = try await m
                currentFronts = try await fr
                
                // Update complication data
                updateComplicationData()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    var frontingMembers: [Member] {
        let ids = Set(currentFronts.flatMap { $0.memberIDs })
        return members.filter { ids.contains($0.id) }
    }

    var oldestCurrentFront: FrontEntry? {
        currentFronts.min(by: { $0.startedAt < $1.startedAt })
    }

    func createMember(name: String, pronouns: String? = nil) async {
        guard let api else { return }
        do {
            let created = try await api.createMember(MemberCreate(name: name, pronouns: pronouns))
            members.append(created)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func switchFronting(to memberIDs: [String]) async {
        guard let api else { return }
        do {
            let now = Date()
            for front in currentFronts where front.endedAt == nil {
                _ = try await api.updateFront(id: front.id, update: FrontUpdate(endedAt: now, memberIDs: nil))
            }
            let created = try await api.createFront(FrontCreate(memberIDs: memberIDs, startedAt: now))
            currentFronts = [created]
            
            // Update complication data
            updateComplicationData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Complication Support
    
    private func updateComplicationData() {
        guard let sharedDefaults = UserDefaults(suiteName: "group.systems.lupine.sheaf") else {
            return
        }
        
        let allSharedMembers = frontingMembers.map { member in
            SharedMember(
                id: member.id,
                name: member.name,
                displayName: member.displayName,
                color: member.color,
                avatarURL: member.avatarURL
            )
        }
        
        let frontingData = SharedFrontingData(
            primaryMember: allSharedMembers.first,
            totalCount: frontingMembers.count,
            updatedAt: Date(),
            allMembers: allSharedMembers
        )
        
        if let encoded = try? JSONEncoder().encode(frontingData) {
            sharedDefaults.set(encoded, forKey: "currentFronting")
        }
        
        // Request complication update
        #if os(watchOS)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}

