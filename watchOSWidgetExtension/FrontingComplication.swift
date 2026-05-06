import WidgetKit
import SwiftUI

// MARK: - Timeline Provider
struct FrontingComplicationProvider: TimelineProvider {
    typealias Entry = FrontingEntry
    
    func placeholder(in context: Context) -> FrontingEntry {
        FrontingEntry(date: Date(), members: [SharedMember.example])
    }
    
    func getSnapshot(in context: Context, completion: @escaping (FrontingEntry) -> Void) {
        completion(FrontingEntry(date: Date(), members: [SharedMember.example]))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<FrontingEntry>) -> Void) {
        Task {
            let entry = await getCurrentFrontingEntry()
            
            // Update every 15 minutes
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            
            completion(timeline)
        }
    }
    
    private func getCurrentFrontingEntry() async -> FrontingEntry {
        // Try to get current fronting info from shared data
        guard let sharedData = UserDefaults(suiteName: "group.systems.lupine.sheaf") else {
            print("⚠️ Widget: Unable to access App Group - check entitlements")
            return FrontingEntry(date: Date(), members: [])
        }
        
        if let frontingData = sharedData.data(forKey: "currentFronting") {
            if let decoded = try? JSONDecoder().decode(SharedFrontingData.self, from: frontingData) {
                print("✅ Widget: Loaded fronting data - \(decoded.totalCount) fronting")
                // Use allMembers if available, fall back to primaryMember for backwards compat
                let members = decoded.allMembers.isEmpty
                    ? (decoded.primaryMember.map { [$0] } ?? [])
                    : decoded.allMembers
                return FrontingEntry(date: Date(), members: members)
            } else {
                print("⚠️ Widget: Failed to decode fronting data")
            }
        } else {
            print("⚠️ Widget: No fronting data found in App Group")
        }
        
        // Fallback: no one fronting
        return FrontingEntry(date: Date(), members: [])
    }
}

// MARK: - Timeline Entry
struct FrontingEntry: TimelineEntry {
    let date: Date
    let members: [SharedMember]
}

// MARK: - Shared Member Extensions
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
    
    /// Short name for compact display (first name only)
    var shortName: String {
        let n = displayName ?? name
        if let firstName = n.split(separator: " ").first {
            return String(firstName)
        }
        return n
    }
}

// MARK: - Widget-Specific Avatar View
// Widgets cannot reliably fetch remote images, so always use initials
struct WidgetAvatarView: View {
    let member: SharedMember
    let size: CGFloat

    var body: some View {
        ColorAvatarView(member: member, size: size)
            .frame(width: size, height: size)
            .clipShape(Circle())
    }
}

// MARK: - Color Avatar (Initials)
private struct ColorAvatarView: View {
    let member: SharedMember
    let size: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .fill(member.displayColor)
            
            Text(member.initials)
                .font(.system(size: size * 0.35, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .fontWeight(.heavy)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .widgetAccentable()
        }
    }
}

// MARK: - Widget Views
struct FrontingComplicationView: View {
    @Environment(\.widgetFamily) var family
    let entry: FrontingEntry
    
    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularComplicationView(entry: entry)
        case .accessoryRectangular:
            RectangularComplicationView(entry: entry)
        case .accessoryInline:
            InlineComplicationView(entry: entry)
        #if os(watchOS)
        case .accessoryCorner:
            CornerComplicationView(entry: entry)
        #endif

        default:
            Text("Sheaf")
        }
    }
}

// MARK: - Circular Complication (e.g., Modular face)
struct CircularComplicationView: View {
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
                // Overlapping avatars for multiple fronters
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
        .containerBackground(for: .widget) {
            Color.clear
        }
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

// MARK: - Rectangular Complication (e.g., Infograph)
struct RectangularComplicationView: View {
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
                // Overlapping avatars
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
                                .foregroundColor(.secondary)
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
        .containerBackground(for: .widget) {
            Color.clear
        }
    }
}

// MARK: - Inline Complication (e.g., Modular Compact)
struct InlineComplicationView: View {
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

// MARK: - Corner Complication (e.g., Infograph Modular)
struct CornerComplicationView: View {
    let entry: FrontingEntry
    
    var body: some View {
        if entry.members.isEmpty {
            Image(systemName: "moon.stars")
                .containerBackground(for: .widget) {
                    Color.clear
                }
                .widgetLabel {
                    Text("No fronters")
                }
        } else if entry.members.count == 1 {
            Text(entry.members[0].initials)
                .font(.system(size: 16, weight: .bold))
                .containerBackground(for: .widget) {
                    Color.clear
                }
                .widgetLabel {
                    Text("Fronting")
                }
        } else {
            Text("\(entry.members.count)")
                .font(.system(size: 16, weight: .bold))
                .containerBackground(for: .widget) {
                    Color.clear
                }
                .widgetLabel {
                    Text(entry.members.prefix(2).map { $0.shortName }.joined(separator: ", "))
                }
        }
    }
}



// MARK: - Widget Configuration
struct FrontingComplication: Widget {
    let kind: String = "FrontingComplication"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FrontingComplicationProvider()) { entry in
            FrontingComplicationView(entry: entry)
        }
        .configurationDisplayName("Fronting Status")
        .description("Shows who's currently fronting")
        #if os(watchOS)
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
        #else
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
        #endif
    }
}

// MARK: - Preview
#if DEBUG
struct FrontingComplication_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Circular - single
            FrontingComplicationView(entry: FrontingEntry(
                date: Date(),
                members: [SharedMember.example]
            ))
            .previewContext(WidgetPreviewContext(family: .accessoryCircular))
            .previewDisplayName("Circular - Single")
            
            // Circular - co-fronting
            FrontingComplicationView(entry: FrontingEntry(
                date: Date(),
                members: SharedMember.examples
            ))
            .previewContext(WidgetPreviewContext(family: .accessoryCircular))
            .previewDisplayName("Circular - Co-front")
            
            // Rectangular - co-fronting
            FrontingComplicationView(entry: FrontingEntry(
                date: Date(),
                members: SharedMember.examples
            ))
            .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
            .previewDisplayName("Rectangular - Co-front")
            
            // Inline - co-fronting
            FrontingComplicationView(entry: FrontingEntry(
                date: Date(),
                members: Array(SharedMember.examples.prefix(2))
            ))
            .previewContext(WidgetPreviewContext(family: .accessoryInline))
            .previewDisplayName("Inline - Co-front")
            
            // No one fronting
            FrontingComplicationView(entry: FrontingEntry(
                date: Date(),
                members: []
            ))
            .previewContext(WidgetPreviewContext(family: .accessoryCircular))
            .previewDisplayName("No Front")
        }
    }
}
#endif

// MARK: - Example Data
extension SharedMember {
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
