import Foundation
import SwiftUI
import Combine
import Network
#if canImport(WidgetKit)
import WidgetKit
#endif

// MARK: - NetworkMonitor

@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    @Published private(set) var isOnline = true
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let wasOffline = self?.isOnline == false
                self?.isOnline = (path.status == .satisfied)
                if wasOffline && path.status == .satisfied {
                    NotificationCenter.default.post(name: .connectivityRestored, object: nil)
                }
            }
        }
        monitor.start(queue: queue)
    }
}

extension Notification.Name {
    static let connectivityRestored = Notification.Name("connectivityRestored")
}

// MARK: - CacheManager

actor CacheManager {
    static let shared = CacheManager()

    private let container: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        let base = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.systems.lupine.sheaf"
        )!
        container = base.appendingPathComponent("cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { dec in
            let str = try dec.singleValueContainer().decode(String.self)
            let frac = ISO8601DateFormatter()
            frac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = frac.date(from: str) { return date }
            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            if let date = plain.date(from: str) { return date }
            throw DecodingError.dataCorruptedError(
                in: try dec.singleValueContainer(),
                debugDescription: "Cannot decode date: \(str)"
            )
        }
    }

    func save<T: Encodable>(_ value: T, key: String) {
        let url = container.appendingPathComponent("\(key).json")
        if let data = try? encoder.encode(value) {
            try? data.write(to: url, options: .atomic)
        }
    }

    func load<T: Decodable>(key: String, as type: T.Type) -> T? {
        let url = container.appendingPathComponent("\(key).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    func clearAll() {
        let keys = ["members", "groups", "tags", "fields", "currentFronts", "frontHistory", "systemProfile"]
        for key in keys {
            let url = container.appendingPathComponent("\(key).json")
            try? FileManager.default.removeItem(at: url)
        }
        let queueURL = container.appendingPathComponent("offline_queue.json")
        try? FileManager.default.removeItem(at: queueURL)
    }
}

// MARK: - Offline Queue Types

enum OperationType: String, Codable {
    case createMember, updateMember, deleteMember
    case createGroup, updateGroup, deleteGroup, setGroupMembers
    case createFront, updateFront, deleteFront
    case updateSystem
    case createTag, deleteTag
    case createField, updateField, deleteField
    case setMemberFieldValues
}

struct OfflineOperation: Codable, Identifiable {
    let id: UUID
    let type: OperationType
    let resourceID: String?
    let tempID: String?
    let bodyData: Data
    let createdAt: Date
}

// MARK: - SystemStore

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
    @Published var isOnline = true
    @Published var isSyncing = false
    @Published var pendingOperationCount = 0

    var api: APIClient?
    private let cache = CacheManager.shared
    private var offlineQueue: [OfflineOperation] = []
    private var connectivityObserver: Any?

    func configure(auth: AuthManager) {
        api = APIClient(auth: auth)

        // Start network monitoring
        let monitor = NetworkMonitor.shared
        monitor.start()

        // Observe connectivity changes
        connectivityObserver = NotificationCenter.default.addObserver(
            forName: .connectivityRestored, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.onConnectivityRestored()
            }
        }

        // Load cached data immediately
        Task {
            await loadFromCache()
            await loadOfflineQueue()
            pendingOperationCount = offlineQueue.count
        }
    }

    // MARK: - Cache Loading/Saving

    private func loadFromCache() async {
        if let cached = await cache.load(key: "members", as: [Member].self), members.isEmpty {
            members = cached
        }
        if let cached = await cache.load(key: "groups", as: [SystemGroup].self), groups.isEmpty {
            groups = cached
        }
        if let cached = await cache.load(key: "tags", as: [Tag].self), tags.isEmpty {
            tags = cached
        }
        if let cached = await cache.load(key: "fields", as: [CustomField].self), fields.isEmpty {
            fields = cached
        }
        if let cached = await cache.load(key: "currentFronts", as: [FrontEntry].self), currentFronts.isEmpty {
            currentFronts = cached
        }
        if let cached = await cache.load(key: "frontHistory", as: [FrontEntry].self), frontHistory.isEmpty {
            frontHistory = cached
        }
        if let cached = await cache.load(key: "systemProfile", as: SystemProfile.self), systemProfile == nil {
            systemProfile = cached
        }
    }

    private func saveAllToCache() {
        Task {
            await cache.save(members, key: "members")
            await cache.save(groups, key: "groups")
            await cache.save(tags, key: "tags")
            await cache.save(fields, key: "fields")
            await cache.save(currentFronts, key: "currentFronts")
            await cache.save(frontHistory, key: "frontHistory")
            if let systemProfile {
                await cache.save(systemProfile, key: "systemProfile")
            }
        }
    }

    // MARK: - Offline Queue Persistence

    private func loadOfflineQueue() async {
        if let loaded = await cache.load(key: "offline_queue", as: [OfflineOperation].self) {
            offlineQueue = loaded
        }
    }

    private func persistOfflineQueue() {
        Task {
            await cache.save(offlineQueue, key: "offline_queue")
        }
        pendingOperationCount = offlineQueue.count
    }

    private func enqueue(_ type: OperationType, resourceID: String? = nil, tempID: String? = nil, body: Data = Data()) {
        let op = OfflineOperation(
            id: UUID(), type: type, resourceID: resourceID,
            tempID: tempID, bodyData: body, createdAt: Date()
        )
        offlineQueue.append(op)
        persistOfflineQueue()
    }

    // MARK: - Load All

    func loadAll() {
        Task {
            isLoading = true
            defer { isLoading = false }

            isOnline = NetworkMonitor.shared.isOnline
            guard isOnline, api != nil else { return }

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

                saveAllToCache()
                updateWatchComplication()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Connectivity Restored

    private func onConnectivityRestored() async {
        isOnline = true
        guard !offlineQueue.isEmpty else {
            loadAll()
            return
        }
        await replayOfflineQueue()
    }

    // MARK: - Replay Offline Queue

    private func replayOfflineQueue() async {
        guard let api else { return }
        isSyncing = true
        defer { isSyncing = false }

        var tempIDMap: [String: String] = [:]

        while !offlineQueue.isEmpty {
            let op = offlineQueue[0]

            func resolveID(_ id: String?) -> String? {
                guard let id else { return nil }
                return tempIDMap[id] ?? id
            }

            do {
                switch op.type {
                case .createMember:
                    let create = try JSONDecoder.iso.decode(MemberCreate.self, from: op.bodyData)
                    let created = try await api.createMember(create)
                    if let tempID = op.tempID {
                        tempIDMap[tempID] = created.id
                    }
                case .updateMember:
                    if let rid = resolveID(op.resourceID) {
                        let update = try JSONDecoder.iso.decode(MemberUpdate.self, from: op.bodyData)
                        _ = try await api.updateMember(id: rid, update: update)
                    }
                case .deleteMember:
                    if let rid = resolveID(op.resourceID) {
                        try await api.deleteMember(id: rid)
                    }
                case .createGroup:
                    let create = try JSONDecoder.iso.decode(GroupCreate.self, from: op.bodyData)
                    let created = try await api.createGroup(create)
                    if let tempID = op.tempID {
                        tempIDMap[tempID] = created.id
                    }
                case .updateGroup:
                    if let rid = resolveID(op.resourceID) {
                        let update = try JSONDecoder.iso.decode(GroupUpdate.self, from: op.bodyData)
                        _ = try await api.updateGroup(id: rid, update: update)
                    }
                case .deleteGroup:
                    if let rid = resolveID(op.resourceID) {
                        try await api.deleteGroup(id: rid)
                    }
                case .setGroupMembers:
                    if let rid = resolveID(op.resourceID) {
                        let memberIDs = try JSONDecoder.iso.decode([String].self, from: op.bodyData)
                        let resolved = memberIDs.map { tempIDMap[$0] ?? $0 }
                        _ = try await api.setGroupMembers(groupID: rid, memberIDs: resolved)
                    }
                case .createFront:
                    let create = try JSONDecoder.iso.decode(FrontCreate.self, from: op.bodyData)
                    var resolved = create
                    resolved.memberIDs = create.memberIDs.map { tempIDMap[$0] ?? $0 }
                    let created = try await api.createFront(resolved)
                    if let tempID = op.tempID {
                        tempIDMap[tempID] = created.id
                    }
                case .updateFront:
                    if let rid = resolveID(op.resourceID) {
                        let update = try JSONDecoder.iso.decode(FrontUpdate.self, from: op.bodyData)
                        _ = try await api.updateFront(id: rid, update: update)
                    }
                case .deleteFront:
                    if let rid = resolveID(op.resourceID) {
                        try await api.deleteFront(id: rid)
                    }
                case .updateSystem:
                    let update = try JSONDecoder.iso.decode(SystemUpdate.self, from: op.bodyData)
                    _ = try await api.updateMySystem(update)
                case .createTag:
                    let create = try JSONDecoder.iso.decode(TagCreate.self, from: op.bodyData)
                    let created = try await api.createTag(create)
                    if let tempID = op.tempID {
                        tempIDMap[tempID] = created.id
                    }
                case .deleteTag:
                    if let rid = resolveID(op.resourceID) {
                        try await api.deleteTag(id: rid)
                    }
                case .createField:
                    let create = try JSONDecoder.iso.decode(CustomFieldCreate.self, from: op.bodyData)
                    let created = try await api.createField(create)
                    if let tempID = op.tempID {
                        tempIDMap[tempID] = created.id
                    }
                case .updateField:
                    if let rid = resolveID(op.resourceID) {
                        struct FieldUpdatePayload: Codable { let name: String; let privacy: PrivacyLevel }
                        let payload = try JSONDecoder.iso.decode(FieldUpdatePayload.self, from: op.bodyData)
                        _ = try await api.updateField(id: rid, name: payload.name, privacy: payload.privacy)
                    }
                case .deleteField:
                    if let rid = resolveID(op.resourceID) {
                        try await api.deleteField(id: rid)
                    }
                case .setMemberFieldValues:
                    if let rid = resolveID(op.resourceID) {
                        let values = try JSONDecoder.iso.decode([CustomFieldValueSet].self, from: op.bodyData)
                        _ = try await api.setMemberFieldValues(memberID: rid, values: values)
                    }
                }

                // Success — remove from queue
                offlineQueue.removeFirst()
                persistOfflineQueue()

            } catch let error as NSError {
                // Skip 404 (already deleted) and 409 (conflict) — remove and continue
                if error.code == 404 || error.code == 409 {
                    offlineQueue.removeFirst()
                    persistOfflineQueue()
                    continue
                }
                // Other error — stop replay, keep remaining ops
                errorMessage = "Sync failed: \(error.localizedDescription)"
                break
            }
        }

        // Reconcile with server
        loadAll()
    }

    // MARK: - Fronting

    var frontingMembers: [Member] {
        let ids = Set(currentFronts.flatMap { $0.memberIDs })
        return members.filter { ids.contains($0.id) }
    }

    var oldestCurrentFront: FrontEntry? {
        currentFronts.min(by: { $0.startedAt < $1.startedAt })
    }

    func switchFronting(to memberIDs: [String]) async {
        let now = Date()

        if NetworkMonitor.shared.isOnline, let api {
            do {
                for front in currentFronts where front.endedAt == nil {
                    _ = try await api.updateFront(id: front.id, update: FrontUpdate(endedAt: now, memberIDs: nil))
                }
                let created = try await api.createFront(FrontCreate(memberIDs: memberIDs, startedAt: now))
                currentFronts = [created]
                saveAllToCache()
                updateWatchComplication()
            } catch {
                errorMessage = error.localizedDescription
            }
        } else {
            // Offline: queue end-front operations
            for front in currentFronts where front.endedAt == nil {
                let update = FrontUpdate(endedAt: now, memberIDs: nil)
                if let body = try? JSONEncoder.iso.encode(update) {
                    enqueue(.updateFront, resourceID: front.id, body: body)
                }
            }
            // Queue create-front
            let create = FrontCreate(memberIDs: memberIDs, startedAt: now)
            let tempID = UUID().uuidString
            if let body = try? JSONEncoder.iso.encode(create) {
                enqueue(.createFront, tempID: tempID, body: body)
            }
            // Optimistic local update
            let optimistic = FrontEntry(
                id: tempID, systemID: systemProfile?.id ?? "",
                startedAt: now, endedAt: nil, memberIDs: memberIDs
            )
            currentFronts = [optimistic]
            saveAllToCache()
            updateWatchComplication()
        }
    }

    func loadFrontHistory() async {
        if NetworkMonitor.shared.isOnline, let api {
            do {
                frontHistory = try await api.listFronts()
                await cache.save(frontHistory, key: "frontHistory")
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        // If offline, frontHistory is already loaded from cache
    }

    // MARK: - Fronts (consolidated for views)

    func updateFront(id: String, update: FrontUpdate) async {
        if NetworkMonitor.shared.isOnline, let api {
            do {
                let updated = try await api.updateFront(id: id, update: update)
                if let idx = frontHistory.firstIndex(where: { $0.id == id }) {
                    frontHistory[idx] = updated
                }
                if let idx = currentFronts.firstIndex(where: { $0.id == id }) {
                    currentFronts[idx] = updated
                }
                saveAllToCache()
            } catch {
                errorMessage = error.localizedDescription
            }
        } else {
            if let body = try? JSONEncoder.iso.encode(update) {
                enqueue(.updateFront, resourceID: id, body: body)
            }
            // Optimistic update
            if let idx = frontHistory.firstIndex(where: { $0.id == id }) {
                if let endedAt = update.endedAt { frontHistory[idx].endedAt = endedAt }
                if let memberIDs = update.memberIDs { frontHistory[idx].memberIDs = memberIDs }
            }
            if let idx = currentFronts.firstIndex(where: { $0.id == id }) {
                if let endedAt = update.endedAt { currentFronts[idx].endedAt = endedAt }
                if let memberIDs = update.memberIDs { currentFronts[idx].memberIDs = memberIDs }
            }
            saveAllToCache()
        }
    }

    func deleteFront(id: String) async {
        if NetworkMonitor.shared.isOnline, let api {
            do {
                try await api.deleteFront(id: id)
                frontHistory.removeAll { $0.id == id }
                currentFronts.removeAll { $0.id == id }
                saveAllToCache()
            } catch {
                errorMessage = error.localizedDescription
            }
        } else {
            enqueue(.deleteFront, resourceID: id)
            frontHistory.removeAll { $0.id == id }
            currentFronts.removeAll { $0.id == id }
            saveAllToCache()
        }
    }

    /// End all currently active fronts.
    func endAllFronts() async {
        let now = Date()
        for front in currentFronts where front.endedAt == nil {
            await updateFront(id: front.id, update: FrontUpdate(endedAt: now, memberIDs: nil))
        }
        // updateFront sets endedAt on currentFronts entries — filter them out
        currentFronts.removeAll { $0.endedAt != nil }
        saveAllToCache()
    }

    /// Create a front entry (possibly already-ended) and update local state.
    func addFrontEntry(memberIDs: [String], startedAt: Date, endedAt: Date?) async throws {
        guard let api else { throw URLError(.badURL) }

        if NetworkMonitor.shared.isOnline {
            var entry = try await api.createFront(FrontCreate(memberIDs: memberIDs, startedAt: startedAt))
            if let endedAt {
                entry = try await api.updateFront(id: entry.id, update: FrontUpdate(endedAt: endedAt, memberIDs: nil))
            }
            frontHistory.insert(entry, at: 0)
            if entry.endedAt == nil {
                currentFronts.append(entry)
            }
            saveAllToCache()
        } else {
            let tempID = UUID().uuidString
            let create = FrontCreate(memberIDs: memberIDs, startedAt: startedAt)
            if let body = try? JSONEncoder.iso.encode(create) {
                enqueue(.createFront, tempID: tempID, body: body)
            }
            if let endedAt {
                let update = FrontUpdate(endedAt: endedAt, memberIDs: nil)
                if let body = try? JSONEncoder.iso.encode(update) {
                    enqueue(.updateFront, resourceID: tempID, body: body)
                }
            }
            let optimistic = FrontEntry(
                id: tempID, systemID: systemProfile?.id ?? "",
                startedAt: startedAt, endedAt: endedAt, memberIDs: memberIDs
            )
            frontHistory.insert(optimistic, at: 0)
            if endedAt == nil {
                currentFronts.append(optimistic)
            }
            saveAllToCache()
        }
    }

    // MARK: - Members

    func saveMember(existing: Member? = nil, create: MemberCreate) async {
        if NetworkMonitor.shared.isOnline, let api {
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
                saveAllToCache()
            } catch { errorMessage = error.localizedDescription }
        } else {
            if let existing {
                let update = MemberUpdate(
                    name: create.name, displayName: create.displayName,
                    description: create.description, pronouns: create.pronouns,
                    avatarURL: create.avatarURL, color: create.color,
                    birthday: create.birthday, privacy: create.privacy
                )
                if let body = try? JSONEncoder.iso.encode(update) {
                    enqueue(.updateMember, resourceID: existing.id, body: body)
                }
                // Optimistic update
                if let idx = members.firstIndex(where: { $0.id == existing.id }) {
                    members[idx].name = create.name
                    members[idx].displayName = create.displayName
                    members[idx].description = create.description
                    members[idx].pronouns = create.pronouns
                    members[idx].avatarURL = create.avatarURL
                    members[idx].color = create.color
                    members[idx].birthday = create.birthday
                    if let privacy = create.privacy { members[idx].privacy = privacy }
                }
            } else {
                let tempID = UUID().uuidString
                if let body = try? JSONEncoder.iso.encode(create) {
                    enqueue(.createMember, tempID: tempID, body: body)
                }
                let optimistic = Member(
                    id: tempID, systemID: systemProfile?.id ?? "",
                    name: create.name, displayName: create.displayName,
                    description: create.description, pronouns: create.pronouns,
                    avatarURL: create.avatarURL, color: create.color,
                    birthday: create.birthday, privacy: create.privacy ?? .private,
                    createdAt: Date(), updatedAt: Date()
                )
                members.append(optimistic)
            }
            saveAllToCache()
        }
    }

    func deleteMember(id: String) async {
        if NetworkMonitor.shared.isOnline, let api {
            do {
                try await api.deleteMember(id: id)
                members.removeAll { $0.id == id }
                saveAllToCache()
            } catch { errorMessage = error.localizedDescription }
        } else {
            enqueue(.deleteMember, resourceID: id)
            members.removeAll { $0.id == id }
            saveAllToCache()
        }
    }

    // MARK: - Groups

    func saveGroup(existing: SystemGroup? = nil, create: GroupCreate) async {
        if NetworkMonitor.shared.isOnline, let api {
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
                saveAllToCache()
            } catch { errorMessage = error.localizedDescription }
        } else {
            if let existing {
                let update = GroupUpdate(name: create.name, description: create.description,
                                        color: create.color, parentID: create.parentID)
                if let body = try? JSONEncoder.iso.encode(update) {
                    enqueue(.updateGroup, resourceID: existing.id, body: body)
                }
                if let idx = groups.firstIndex(where: { $0.id == existing.id }) {
                    groups[idx].name = create.name
                    groups[idx].description = create.description
                    groups[idx].color = create.color
                    groups[idx].parentID = create.parentID
                }
            } else {
                let tempID = UUID().uuidString
                if let body = try? JSONEncoder.iso.encode(create) {
                    enqueue(.createGroup, tempID: tempID, body: body)
                }
                let optimistic = SystemGroup(
                    id: tempID, systemID: systemProfile?.id ?? "",
                    name: create.name, description: create.description,
                    color: create.color, parentID: create.parentID,
                    createdAt: Date(), updatedAt: Date()
                )
                groups.append(optimistic)
            }
            saveAllToCache()
        }
    }

    func setGroupMembers(groupID: String, memberIDs: [String]) async {
        if NetworkMonitor.shared.isOnline, let api {
            do { _ = try await api.setGroupMembers(groupID: groupID, memberIDs: memberIDs) }
            catch { errorMessage = error.localizedDescription }
        } else {
            if let body = try? JSONEncoder.iso.encode(memberIDs) {
                enqueue(.setGroupMembers, resourceID: groupID, body: body)
            }
        }
    }

    func deleteGroup(id: String) async {
        if NetworkMonitor.shared.isOnline, let api {
            do {
                try await api.deleteGroup(id: id)
                groups.removeAll { $0.id == id }
                saveAllToCache()
            } catch { errorMessage = error.localizedDescription }
        } else {
            enqueue(.deleteGroup, resourceID: id)
            groups.removeAll { $0.id == id }
            saveAllToCache()
        }
    }

    // MARK: - System Profile (consolidated for views)

    func updateSystem(_ update: SystemUpdate) async {
        if NetworkMonitor.shared.isOnline, let api {
            do {
                systemProfile = try await api.updateMySystem(update)
                saveAllToCache()
            } catch {
                errorMessage = error.localizedDescription
            }
        } else {
            if let body = try? JSONEncoder.iso.encode(update) {
                enqueue(.updateSystem, body: body)
            }
            // Optimistic update
            if let name = update.name { systemProfile?.name = name }
            if let desc = update.description { systemProfile?.description = desc }
            if let tag = update.tag { systemProfile?.tag = tag }
            if let url = update.avatarURL { systemProfile?.avatarURL = url }
            if let color = update.color { systemProfile?.color = color }
            if let privacy = update.privacy { systemProfile?.privacy = privacy }
            saveAllToCache()
        }
    }

    // MARK: - Custom Fields (consolidated for views)

    func deleteField(id: String) async {
        if NetworkMonitor.shared.isOnline, let api {
            do {
                try await api.deleteField(id: id)
                fields.removeAll { $0.id == id }
                saveAllToCache()
            } catch {
                errorMessage = error.localizedDescription
            }
        } else {
            enqueue(.deleteField, resourceID: id)
            fields.removeAll { $0.id == id }
            saveAllToCache()
        }
    }

    func updateField(id: String, name: String, privacy: PrivacyLevel) async {
        if NetworkMonitor.shared.isOnline, let api {
            do {
                let updated = try await api.updateField(id: id, name: name, privacy: privacy)
                if let idx = fields.firstIndex(where: { $0.id == id }) {
                    fields[idx] = updated
                }
                saveAllToCache()
            } catch {
                errorMessage = error.localizedDescription
            }
        } else {
            struct FieldUpdatePayload: Codable { let name: String; let privacy: PrivacyLevel }
            if let body = try? JSONEncoder.iso.encode(FieldUpdatePayload(name: name, privacy: privacy)) {
                enqueue(.updateField, resourceID: id, body: body)
            }
            if let idx = fields.firstIndex(where: { $0.id == id }) {
                fields[idx].name = name
                fields[idx].privacy = privacy
            }
            saveAllToCache()
        }
    }

    func createField(_ create: CustomFieldCreate) async -> CustomField? {
        if NetworkMonitor.shared.isOnline, let api {
            do {
                let created = try await api.createField(create)
                fields.append(created)
                saveAllToCache()
                return created
            } catch {
                errorMessage = error.localizedDescription
                return nil
            }
        } else {
            let tempID = UUID().uuidString
            if let body = try? JSONEncoder.iso.encode(create) {
                enqueue(.createField, tempID: tempID, body: body)
            }
            let optimistic = CustomField(
                id: tempID, systemID: systemProfile?.id ?? "",
                name: create.name, fieldType: create.fieldType,
                options: create.options, order: create.order ?? fields.count,
                privacy: create.privacy ?? .private,
                createdAt: Date(), updatedAt: Date()
            )
            fields.append(optimistic)
            saveAllToCache()
            return optimistic
        }
    }

    func reloadFields() async {
        if NetworkMonitor.shared.isOnline, let api {
            fields = (try? await api.getFields()) ?? fields
            saveAllToCache()
        }
    }

    // MARK: - Tags (consolidated for views)

    func createTag(_ create: TagCreate) async -> Tag? {
        if NetworkMonitor.shared.isOnline, let api {
            do {
                let created = try await api.createTag(create)
                tags.append(created)
                saveAllToCache()
                return created
            } catch {
                errorMessage = error.localizedDescription
                return nil
            }
        } else {
            let tempID = UUID().uuidString
            if let body = try? JSONEncoder.iso.encode(create) {
                enqueue(.createTag, tempID: tempID, body: body)
            }
            let optimistic = Tag(
                id: tempID, systemID: systemProfile?.id ?? "",
                name: create.name, color: create.color,
                createdAt: Date(), updatedAt: Date()
            )
            tags.append(optimistic)
            saveAllToCache()
            return optimistic
        }
    }

    func deleteTag(id: String) async {
        if NetworkMonitor.shared.isOnline, let api {
            do {
                try await api.deleteTag(id: id)
                tags.removeAll { $0.id == id }
                saveAllToCache()
            } catch {
                errorMessage = error.localizedDescription
            }
        } else {
            enqueue(.deleteTag, resourceID: id)
            tags.removeAll { $0.id == id }
            saveAllToCache()
        }
    }

    // MARK: - Member Field Values (consolidated for views)

    func getMemberFieldValues(memberID: String) async -> [CustomFieldValue] {
        if NetworkMonitor.shared.isOnline, let api {
            return (try? await api.getMemberFieldValues(memberID: memberID)) ?? []
        }
        return []
    }

    func setMemberFieldValues(memberID: String, values: [CustomFieldValueSet]) async {
        if NetworkMonitor.shared.isOnline, let api {
            do {
                _ = try await api.setMemberFieldValues(memberID: memberID, values: values)
            } catch {
                errorMessage = error.localizedDescription
            }
        } else {
            if let body = try? JSONEncoder.iso.encode(values) {
                enqueue(.setMemberFieldValues, resourceID: memberID, body: body)
            }
        }
    }

    // MARK: - Helpers

    var membersByFrontFrequency: [Member] {
        guard !frontHistory.isEmpty else { return members }

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
        members.filter { m in
            false
        }
    }

    // MARK: - Watch Complication Support

    private func updateWatchComplication() {
        guard let sharedDefaults = UserDefaults(suiteName: "group.systems.lupine.sheaf") else { return }

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
            sharedDefaults.synchronize()
        }

        #if canImport(WidgetKit)
        WidgetKit.WidgetCenter.shared.reloadAllTimelines()
        #endif

        PhoneConnectivityManager.shared.syncCredentials()
    }
}
