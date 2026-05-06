import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct FrontingProvider: TimelineProvider {
    typealias Entry = FrontingEntry

    func placeholder(in context: Context) -> FrontingEntry {
        FrontingEntry(date: Date(), members: [.example])
    }

    func getSnapshot(in context: Context, completion: @escaping (FrontingEntry) -> Void) {
        completion(FrontingEntry(date: Date(), members: [.example]))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FrontingEntry>) -> Void) {
        let entry = getCurrentFrontingEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func getCurrentFrontingEntry() -> FrontingEntry {
        guard let sharedData = UserDefaults(suiteName: "group.systems.lupine.sheaf") else {
            return FrontingEntry(date: Date(), members: [])
        }

        if let frontingData = sharedData.data(forKey: "currentFronting"),
           let decoded = try? JSONDecoder().decode(SharedFrontingData.self, from: frontingData) {
            let members = decoded.allMembers.isEmpty
                ? (decoded.primaryMember.map { [$0] } ?? [])
                : decoded.allMembers
            return FrontingEntry(date: Date(), members: members)
        }

        return FrontingEntry(date: Date(), members: [])
    }
}

// MARK: - Timeline Entry

struct FrontingEntry: TimelineEntry {
    let date: Date
    let members: [SharedMember]
}

// MARK: - Color Helpers

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard hex.count == 6, let int = UInt64(hex, radix: 16) else { return nil }
        self.init(
            red: Double((int >> 16) & 0xFF) / 255.0,
            green: Double((int >> 8) & 0xFF) / 255.0,
            blue: Double(int & 0xFF) / 255.0
        )
    }
}

extension SharedMember {
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

    var shortName: String {
        let n = displayName ?? name
        if let firstName = n.split(separator: " ").first {
            return String(firstName)
        }
        return n
    }

    static var example: SharedMember {
        SharedMember(id: "1", name: "Alice", displayName: "Alice", pronouns: "she/her", color: "#9B59B6", avatarURL: nil, emoji: nil, frontStartedAt: Date().addingTimeInterval(-7200))
    }

    static var examples: [SharedMember] {
        [
            SharedMember(id: "1", name: "Alice", displayName: "Alice", pronouns: "she/her", color: "#9B59B6", avatarURL: nil, emoji: "✨", frontStartedAt: Date().addingTimeInterval(-7200)),
            SharedMember(id: "2", name: "Bob", displayName: "Bob", pronouns: "he/him", color: "#3498DB", avatarURL: nil, emoji: nil, frontStartedAt: Date().addingTimeInterval(-7200)),
            SharedMember(id: "3", name: "Carol", displayName: "Carol", pronouns: nil, color: "#E74C3C", avatarURL: nil, emoji: nil, frontStartedAt: Date().addingTimeInterval(-3600)),
        ]
    }
}

// MARK: - Widget Avatar View

struct WidgetAvatarView: View {
    @Environment(\.widgetRenderingMode) var renderingMode
    let member: SharedMember
    let size: CGFloat

    var body: some View {
        ZStack {
            if renderingMode == .accented {
                Circle()
                    .strokeBorder(.white, lineWidth: 1.5)
                Text(member.initials)
                    .font(.system(size: size * 0.35, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .fontWeight(.heavy)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            } else {
                Circle()
                    .fill(member.displayColor)
                Text(member.initials)
                    .font(.system(size: size * 0.35, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .fontWeight(.heavy)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

// MARK: - Widget Entry View

struct FrontingWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: FrontingEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularView(entry: entry)
        case .accessoryRectangular:
            RectangularView(entry: entry)
        case .accessoryInline:
            InlineView(entry: entry)
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            Text("Sheaf")
        }
    }
}

// MARK: - Lock Screen: Circular

struct CircularView: View {
    let entry: FrontingEntry

    var body: some View {
        ZStack {
            if entry.members.isEmpty {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            } else if entry.members.count == 1 {
                WidgetAvatarView(member: entry.members[0], size: 42)
            } else {
                let visible = Array(entry.members.prefix(3))
                ZStack {
                    ForEach(Array(visible.enumerated().reversed()), id: \.element.id) { index, member in
                        WidgetAvatarView(member: member, size: 28)
                            .offset(x: CGFloat(index - (visible.count - 1)) * 10)
                    }
                }
                if entry.members.count > 3 {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("+\(entry.members.count - 3)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(3)
                                .background(Color.purple)
                                .clipShape(Circle())
                        }
                    }
                    .padding(2)
                }
            }
        }
        .containerBackground(for: .widget) { Color.clear }
        .widgetLabel {
            if entry.members.count > 1 {
                Text("\(entry.members.count) fronting")
            } else if !entry.members.isEmpty {
                Text("Fronting")
            } else {
                Text("No front")
            }
        }
    }
}

// MARK: - Lock Screen: Rectangular

struct RectangularView: View {
    let entry: FrontingEntry

    var body: some View {
        HStack(spacing: 8) {
            if entry.members.isEmpty {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Sheaf")
                        .font(.system(size: 14, weight: .semibold))
                    Text("No one fronting")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            } else {
                ZStack {
                    ForEach(Array(entry.members.prefix(3).enumerated().reversed()), id: \.element.id) { index, member in
                        WidgetAvatarView(member: member, size: 26)
                            .offset(x: CGFloat(index) * 10)
                    }
                }
                .frame(width: CGFloat(min(entry.members.count, 3) - 1) * 10 + 26, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    let names = entry.members.prefix(2).map { $0.shortName }
                    Text(names.joined(separator: ", "))
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)

                    if entry.members.count > 2 {
                        Text("+\(entry.members.count - 2) more")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    } else if entry.members.count == 1 {
                        if let pronouns = entry.members[0].pronouns, !pronouns.isEmpty {
                            Text(pronouns)
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        } else {
                            Text("Fronting")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Co-fronting")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .containerBackground(for: .widget) { Color.clear }
    }
}

// MARK: - Lock Screen: Inline

struct InlineView: View {
    let entry: FrontingEntry

    var body: some View {
        if entry.members.isEmpty {
            Text("No front")
        } else if entry.members.count <= 2 {
            Text(entry.members.map { $0.shortName }.joined(separator: " & "))
        } else {
            let first = entry.members[0].shortName
            Text("\(first) +\(entry.members.count - 1)")
        }
    }
}

// MARK: - Home Screen: Small

struct SmallWidgetView: View {
    let entry: FrontingEntry

    var body: some View {
        VStack(spacing: 8) {
            if entry.members.isEmpty {
                Spacer()
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                Text("No one fronting")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
            } else if entry.members.count == 1 {
                let member = entry.members[0]
                Spacer()
                WidgetAvatarView(member: member, size: 44)
                Text(member.displayName ?? member.name)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                if let pronouns = member.pronouns, !pronouns.isEmpty {
                    Text(pronouns)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                if let startedAt = member.frontStartedAt {
                    Text(startedAt, style: .relative)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                Spacer()
                ZStack {
                    ForEach(Array(entry.members.prefix(3).enumerated().reversed()), id: \.element.id) { index, member in
                        WidgetAvatarView(member: member, size: 36)
                            .offset(x: CGFloat(index - min(entry.members.count, 3) / 2) * 16)
                    }
                }

                let names = entry.members.prefix(2).map { $0.shortName }
                Text(names.joined(separator: " & "))
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                if entry.members.count > 2 {
                    Text("+\(entry.members.count - 2) more fronting")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    Text("Co-fronting")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                if let startedAt = entry.members.first?.frontStartedAt {
                    Text(startedAt, style: .relative)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

// MARK: - Home Screen: Medium

struct MediumWidgetView: View {
    let entry: FrontingEntry

    var body: some View {
        HStack(spacing: 28) {
            if entry.members.isEmpty {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Sheaf")
                        .font(.system(size: 17, weight: .bold))
                    Text("No one is currently fronting")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(spacing: 6) {
                    if entry.members.count == 1 {
                        WidgetAvatarView(member: entry.members[0], size: 52)
                    } else {
                        ZStack {
                            ForEach(Array(entry.members.prefix(3).enumerated().reversed()), id: \.element.id) { index, member in
                                WidgetAvatarView(member: member, size: 36)
                                    .offset(x: CGFloat(index) * 18)
                            }
                        }
                        .frame(width: CGFloat(min(entry.members.count, 3) - 1) * 18 + 36)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("Currently Fronting")
                            .font(.caption2).fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        if let startedAt = entry.members.compactMap({ $0.frontStartedAt }).min() {
                            Text("·")
                                .font(.caption2).fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            Text(startedAt, style: .relative)
                                .font(.caption2).fontWeight(.semibold)
                                .fontDesign(.monospaced)
                                .foregroundStyle(.secondary)
                        }
                    }

                    ForEach(Array(entry.members.prefix(3).enumerated()), id: \.element.id) { _, member in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(member.displayColor)
                                .frame(width: 8, height: 8)
                                .widgetAccentable()
                            Text(member.displayName ?? member.name)
                                .font(.subheadline).fontWeight(.medium)
                                .lineLimit(1)
                            if let pronouns = member.pronouns, !pronouns.isEmpty {
                                Text(pronouns)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }

                    if entry.members.count > 3 {
                        Text("+\(entry.members.count - 3) more")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

// MARK: - Widget Configuration

struct FrontingWidget: Widget {
    let kind: String = "FrontingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FrontingProvider()) { entry in
            FrontingWidgetView(entry: entry)
        }
        .configurationDisplayName("Fronting Status")
        .description("Shows who's currently fronting")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .systemSmall,
            .systemMedium
        ])
    }
}

// MARK: - Previews

#Preview("Small - Single", as: .systemSmall) {
    FrontingWidget()
} timeline: {
    FrontingEntry(date: .now, members: [.example])
}

#Preview("Small - Co-front", as: .systemSmall) {
    FrontingWidget()
} timeline: {
    FrontingEntry(date: .now, members: SharedMember.examples)
}

#Preview("Medium - Co-front", as: .systemMedium) {
    FrontingWidget()
} timeline: {
    FrontingEntry(date: .now, members: SharedMember.examples)
}

#Preview("Medium - Empty", as: .systemMedium) {
    FrontingWidget()
} timeline: {
    FrontingEntry(date: .now, members: [])
}
