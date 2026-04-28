import Foundation
import Combine

enum LogCategory: String, CaseIterable, Identifiable, Codable {
    case auth = "Auth"
    case keychain = "Keychain"
    case sync = "Sync"
    case api = "API"
    case app = "App"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .auth: return "lock.fill"
        case .keychain: return "key.fill"
        case .sync: return "arrow.triangle.2.circlepath"
        case .api: return "network"
        case .app: return "app.fill"
        }
    }
}

enum LogLevel: Int, CaseIterable, Comparable, Identifiable, Codable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARN"
        case .error: return "ERROR"
        }
    }

    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct LogEntry: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let category: LogCategory
    let level: LogLevel
    let message: String

    init(timestamp: Date, category: LogCategory, level: LogLevel, message: String) {
        self.id = UUID()
        self.timestamp = timestamp
        self.category = category
        self.level = level
        self.message = message
    }
}

final class AppLogger: ObservableObject {
    static let shared = AppLogger()

    @Published private(set) var entries: [LogEntry] = []
    private let maxEntries = 500
    private var saveWork: DispatchWorkItem?

    private static var fileURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("sheaf_debug_log.json")
    }

    private init() {
        loadFromDisk()
    }

    func log(_ category: LogCategory, _ level: LogLevel, _ message: String) {
        let redacted = Self.redact(message)
        let entry = LogEntry(timestamp: Date(), category: category, level: level, message: redacted)

        #if DEBUG
        NSLog("[%@] %@: %@", category.rawValue, level.label, redacted)
        #endif

        DispatchQueue.main.async { [self] in
            entries.append(entry)
            if entries.count > maxEntries {
                entries.removeFirst(entries.count - maxEntries)
            }
            scheduleSave()
        }
    }

    func log(_ message: String, level: LogLevel = .info) {
        let (category, _) = Self.parseCategory(message)
        log(category, level, message)
    }

    func clear() {
        DispatchQueue.main.async { [self] in
            entries.removeAll()
            try? FileManager.default.removeItem(at: Self.fileURL)
        }
    }

    // MARK: - Persistence

    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.saveToDisk()
        }
        saveWork = work
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.0, execute: work)
    }

    private func saveToDisk() {
        let snapshot = entries
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: Self.fileURL, options: .atomic)
        } catch {
            #if DEBUG
            NSLog("AppLogger: Failed to save logs: %@", error.localizedDescription)
            #endif
        }
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: Self.fileURL),
              let saved = try? JSONDecoder().decode([LogEntry].self, from: data) else {
            return
        }
        entries = saved.suffix(maxEntries).map { $0 }
    }

    var exportText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        let header = "Sheaf Debug Log — \(formatter.string(from: Date()))\n\n"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss.SSS"

        let lines = entries.map { entry in
            "[\(timeFormatter.string(from: entry.timestamp))] [\(entry.category.rawValue)] \(entry.level.label): \(entry.message)"
        }
        return header + lines.joined(separator: "\n")
    }

    // MARK: - Redaction

    static func redact(_ message: String) -> String {
        var result = message

        // JWT tokens (eyJ header followed by base64url payload)
        result = result.replacingOccurrences(
            of: "eyJ[A-Za-z0-9_-]{10,}",
            with: "[token]",
            options: .regularExpression
        )

        // Bearer authorization header values
        result = result.replacingOccurrences(
            of: "Bearer [^ \"\\]]+",
            with: "Bearer [token]",
            options: .regularExpression
        )

        // Long hex strings (secrets tend to be 40+ hex chars)
        result = result.replacingOccurrences(
            of: "\\b[a-fA-F0-9]{40,}\\b",
            with: "[hex-redacted]",
            options: .regularExpression
        )

        // Cloudflare access secrets
        result = result.replacingOccurrences(
            of: "(CF-Access-Client-Secret|cf_client_secret)[^,\\]\\n]*",
            with: "$1: [redacted]",
            options: .regularExpression
        )

        return result
    }

    // MARK: - Category Detection

    private static func parseCategory(_ message: String) -> (LogCategory, String) {
        let prefixMap: [(String, LogCategory)] = [
            ("AuthManager:", .auth),
            ("WatchAuthManager:", .auth),
            ("Login:", .auth),
            ("Keychain:", .keychain),
            ("PhoneConnectivityManager:", .sync),
            ("WatchConnectivityManager:", .sync),
            ("APIClient:", .api),
        ]
        for (prefix, category) in prefixMap {
            if message.hasPrefix(prefix) {
                return (category, message)
            }
        }
        return (.app, message)
    }
}
