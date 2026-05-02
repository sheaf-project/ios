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
                "Add to front in \(.applicationName)",
                "Add someone to front in \(.applicationName)",
                "Co-front in \(.applicationName)",
                ],
            shortTitle: "Add to Front",
            systemImageName: "person.fill.checkmark"
        )
        AppShortcut(
            intent: RemoveFromFrontIntent(),
            phrases: [
                "Remove from front in \(.applicationName)",
                "Remove someone from front in \(.applicationName)",
                ],
            shortTitle: "Remove from Front",
            systemImageName: "person.fill.xmark"
        )
        AppShortcut(
            intent: PurgeFrontIntent(),
            phrases: [
                "Purge front in \(.applicationName)",
                "Clear front in \(.applicationName)",
                "End front in \(.applicationName)",
                "Remove everyone from front in \(.applicationName)",
            ],
            shortTitle: "Purge Front",
            systemImageName: "person.fill.xmark"
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

    // Tells Siri which spoken words map to this entity —
    // includes both name and displayName so either works
    static var typeDisplayName: LocalizedStringResource = "Member"
}

// MARK: - Member Entity Query
struct MemberEntityQuery: EntityQuery, EnumerableEntityQuery, EntityStringQuery {
    // EnumerableEntityQuery tells Shortcuts to show a full pre-populated
    // picker list instead of a free-text search field.
    func allEntities() async throws -> [MemberEntity] {
        let members = await ShortcutsDataStore.shared.members
        return members
            .map { MemberEntity(id: $0.id, name: $0.name, displayName: $0.displayName, color: $0.color) }
    }

    func entities(for identifiers: [String]) async throws -> [MemberEntity] {
        let members = await ShortcutsDataStore.shared.members
        return members
            .filter { identifiers.contains($0.id) }
            .map { MemberEntity(id: $0.id, name: $0.name, displayName: $0.displayName, color: $0.color) }
    }

    func suggestedEntities() async throws -> [MemberEntity] {
        try await allEntities()
    }

    // EntityStringQuery: called when Siri hears a name and needs to resolve
    // it — matches against both name and displayName so either works
    func entities(matching query: String) async throws -> [MemberEntity] {
        let members = await ShortcutsDataStore.shared.members
        let q = query.lowercased()
        return members
            .filter {
                $0.name.lowercased().contains(q) ||
                ($0.displayName?.lowercased().contains(q) ?? false)
            }
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

    // Optional — if not pre-filled by the user in Shortcuts, perform() will
    // interactively prompt with the full member list before executing.
    @Parameter(
        title: "Members",
        description: "Who should be fronting",
        requestValueDialog: IntentDialog("Who should be fronting?")
    )
    var members: [MemberEntity]

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Siri resolves member names via EntityStringQuery automatically.
        // requestValueDialog on the @Parameter handles the case where no
        // name was spoken — Siri will ask without showing a dropdown.
        let store = await ShortcutsDataStore.shared
        let ids = members.map { $0.id }
        try await store.switchFronting(to: ids)
        let names = await formatNameList(members.map { $0.displayName ?? $0.name })
        let verb = members.count == 1 ? "is" : "are"
        return .result(dialog: "\(names) \(verb) now fronting.")
    }
}

// MARK: - Add to Front Intent
struct AddToFrontIntent: AppIntent {
    static var title: LocalizedStringResource = "Add to Front"
    static var description = IntentDescription("Add a member to the current front without removing others.")
    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$member) to front")
    }

    @Parameter(
        title: "Member",
        description: "Who to add to front",
        requestValueDialog: IntentDialog("Who should be added to front?")
    )
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

        let nameList = await formatNameList(names)
        if names.isEmpty {
            return .result(value: "No one", dialog: "No one is currently fronting.")
        }
        let verb = names.count == 1 ? "is" : "are"
        return .result(value: nameList, dialog: "\(nameList) \(verb) currently fronting.")
    }
}

// MARK: - Remove from Front Intent
struct RemoveFromFrontIntent: AppIntent {
    static var title: LocalizedStringResource = "Remove from Front"
    static var description = IntentDescription("Remove a member from the current front without affecting others.")
    static var parameterSummary: some ParameterSummary {
        Summary("Remove \(\.$member) from front")
    }

    @Parameter(
        title: "Member",
        description: "Who to remove from front",
        requestValueDialog: IntentDialog("Who should be removed from front?")
    )
    var member: MemberEntity

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = await ShortcutsDataStore.shared
        let currentIDs = await store.currentFrontingIDs

        guard currentIDs.contains(member.id) else {
            let name = member.displayName ?? member.name
            return .result(dialog: "\(name) isn't currently fronting.")
        }

        let remaining = currentIDs.filter { $0 != member.id }
        try await store.switchFronting(to: remaining)

        let name = member.displayName ?? member.name
        if remaining.isEmpty {
            return .result(dialog: "\(name) has been removed from front. No one is now fronting.")
        }
        return .result(dialog: "\(name) has been removed from front.")
    }
}

// MARK: - Purge Front Intent
struct PurgeFrontIntent: AppIntent {
    static var title: LocalizedStringResource = "Purge Front"
    static var description = IntentDescription("End the current front entirely, removing everyone.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = await ShortcutsDataStore.shared
        let currentIDs = await store.currentFrontingIDs

        guard !currentIDs.isEmpty else {
            return .result(dialog: "No one is currently fronting.")
        }

        let names = await store.frontingMemberNames
        try await store.switchFronting(to: [])
        let nameList = await formatNameList(names)
        let verb = names.count == 1 ? "has" : "have"
        return .result(dialog: "\(nameList) \(verb) been removed from front.")
    }
}

// MARK: - Name list formatting
private func formatNameList(_ names: [String]) -> String {
    guard !names.isEmpty else { return "No one" }
    return names.formatted(.list(type: .and, width: .standard))
}

// MARK: - ShortcutsDataStore
// A lightweight singleton that the intents use to access the API
// without depending on the SwiftUI environment.
// NOTE: Not @MainActor so intents can call it directly from their background context.
final class ShortcutsDataStore {
    static let shared = ShortcutsDataStore()

    private var authManager: AuthManager?
    private var api: APIClient?

    func configure(auth: AuthManager) {
        self.authManager = auth
        self.api = APIClient(auth: auth)
    }

    private var isReady: Bool { authManager?.isAuthenticated == true && api != nil }

    var currentFrontingIDs: [String] {
        get async {
            guard isReady, let api else { return [] }
            do {
                let fronts = try await api.getCurrentFronts()
                return Array(Set(fronts.flatMap { $0.memberIDs }))
            } catch {
                return []
            }
        }
    }

    var frontingMemberNames: [String] {
        get async {
            guard isReady, let api else { return [] }
            do {
                async let frontsTask   = api.getCurrentFronts()
                async let membersTask  = api.getMembers()
                let fronts   = try await frontsTask
                let members  = try await membersTask
                let ids      = Set(fronts.flatMap { $0.memberIDs })
                return members
                    .filter { ids.contains($0.id) }
                    .map { $0.displayName ?? $0.name }
            } catch {
                return []
            }
        }
    }

    var members: [Member] {
        get async {
            guard isReady, let api else { return [] }
            return (try? await api.getMembers()) ?? []
        }
    }

    func switchFronting(to memberIDs: [String]) async throws {
        guard isReady, let api else {
            throw ShortcutError.notAuthenticated
        }
        let currentFronts = (try? await api.getCurrentFronts()) ?? []
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
