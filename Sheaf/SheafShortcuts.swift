import AppIntents
import SwiftUI

// MARK: - App Shortcuts Provider
struct SheafShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SwitchFrontIntent(),
            phrases: [
                "Switch front in \(.applicationName)",
                "Change who's fronting in \(.applicationName)",
                "Set fronting in \(.applicationName)",
            ],
            shortTitle: "Switch Front",
            systemImageName: "arrow.left.arrow.right"
        )
        AppShortcut(
            intent: AddToFrontIntent(),
            phrases: [
                "Add someone to front in \(.applicationName)",
                "Add to front in \(.applicationName)",
                "Co-front in \(.applicationName)",
            ],
            shortTitle: "Add to Front",
            systemImageName: "person.fill.checkmark"
        )
        AppShortcut(
            intent: GetCurrentFrontIntent(),
            phrases: [
                "Who's fronting in \(.applicationName)",
                "Who is fronting in \(.applicationName)",
                "Check front in \(.applicationName)",
            ],
            shortTitle: "Who's Fronting",
            systemImageName: "person.2.fill"
        )
    }
}

// MARK: - Member Entity
struct MemberEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Member"
    static var defaultQuery = MemberEntityQuery()

    let id: String
    let name: String
    let displayName: String?
    let color: String?

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayName ?? name)")
    }
}

// MARK: - Member Entity Query
struct MemberEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [MemberEntity] {
        let store = await ShortcutsDataStore.shared
        return await store.members
            .filter { identifiers.contains($0.id) }
            .map { MemberEntity(id: $0.id, name: $0.name, displayName: $0.displayName, color: $0.color) }
    }

    func suggestedEntities() async throws -> [MemberEntity] {
        let store = await ShortcutsDataStore.shared
        return await store.members
            .map { MemberEntity(id: $0.id, name: $0.name, displayName: $0.displayName, color: $0.color) }
    }
}

// MARK: - Switch Front Intent
struct SwitchFrontIntent: AppIntent {
    static var title: LocalizedStringResource = "Switch Front"
    static var description = IntentDescription("Set who is currently fronting, replacing anyone currently fronting.")
    static var parameterSummary: some ParameterSummary {
        Summary("Switch front to \(\.$members)")
    }

    @Parameter(title: "Members", description: "Who should be fronting")
    var members: [MemberEntity]

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = await ShortcutsDataStore.shared
        let ids = members.map { $0.id }
        try await store.switchFronting(to: ids)
        let names = members.map { $0.displayName ?? $0.name }.joined(separator: ", ")
        return .result(dialog: "\(names) is now fronting.")
    }
}

// MARK: - Add to Front Intent
struct AddToFrontIntent: AppIntent {
    static var title: LocalizedStringResource = "Add to Front"
    static var description = IntentDescription("Add a member to the current front without removing others.")
    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$member) to front")
    }

    @Parameter(title: "Member", description: "Who to add to front")
    var member: MemberEntity

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = await ShortcutsDataStore.shared
        let currentIDs = await store.currentFrontingIDs
        let newIDs = Array(Set(currentIDs + [member.id]))
        try await store.switchFronting(to: newIDs)
        let name = member.displayName ?? member.name
        return .result(dialog: "\(name) has been added to front.")
    }
}

// MARK: - Get Current Front Intent
struct GetCurrentFrontIntent: AppIntent {
    static var title: LocalizedStringResource = "Who's Fronting"
    static var description = IntentDescription("Get the names of everyone currently fronting.")

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let store = await ShortcutsDataStore.shared
        let names = await store.frontingMemberNames

        if names.isEmpty {
            return .result(value: "No one", dialog: "No one is currently fronting.")
        }
        let nameList = names.joined(separator: ", ")
        return .result(value: nameList, dialog: "\(nameList) is currently fronting.")
    }
}

// MARK: - ShortcutsDataStore
// A lightweight singleton that the intents use to access the API
// without depending on the SwiftUI environment.
@MainActor
final class ShortcutsDataStore {
    static let shared = ShortcutsDataStore()

    private let authManager = AuthManager()
    private lazy var api = APIClient(auth: authManager)

    private(set) var members: [Member] = []
    private(set) var currentFronts: [FrontEntry] = []

    var currentFrontingIDs: [String] {
        Array(Set(currentFronts.flatMap { $0.memberIDs }))
    }

    var frontingMemberNames: [String] {
        let ids = Set(currentFrontingIDs)
        return members
            .filter { ids.contains($0.id) }
            .map { $0.displayName ?? $0.name }
    }

    func refreshIfNeeded() async {
        guard authManager.isAuthenticated else { return }
        do {
            async let m = api.getMembers()
            async let f = api.getCurrentFronts()
            members       = try await m
            currentFronts = try await f
        } catch {}
    }

    func switchFronting(to memberIDs: [String]) async throws {
        guard authManager.isAuthenticated else {
            throw ShortcutError.notAuthenticated
        }
        await refreshIfNeeded()
        let now = Date()
        for front in currentFronts where front.endedAt == nil {
            _ = try await api.updateFront(
                id: front.id,
                update: FrontUpdate(endedAt: now, memberIDs: nil)
            )
        }
        if !memberIDs.isEmpty {
            _ = try await api.createFront(FrontCreate(memberIDs: memberIDs, startedAt: now))
        }
        // Refresh after switching
        await refreshIfNeeded()
    }
}

enum ShortcutError: Error, LocalizedError {
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please open Sheaf and sign in before using shortcuts."
        }
    }
}
