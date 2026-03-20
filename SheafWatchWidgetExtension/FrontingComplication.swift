import WidgetKit
import SwiftUI

// MARK: - Timeline Provider
struct FrontingComplicationProvider: TimelineProvider {
    typealias Entry = FrontingEntry
    
    func placeholder(in context: Context) -> FrontingEntry {
        // Return example data for placeholder instead of empty state
        FrontingEntry(
            date: Date(),
            frontingMember: SharedMember.example,
            frontCount: 1
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (FrontingEntry) -> Void) {
        // For previews in the widget gallery
        let entry = FrontingEntry(
            date: Date(),
            frontingMember: SharedMember.example,
            frontCount: 1
        )
        completion(entry)
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
            return FrontingEntry(date: Date(), frontingMember: nil, frontCount: 0)
        }
        
        if let frontingData = sharedData.data(forKey: "currentFronting") {
            if let decoded = try? JSONDecoder().decode(SharedFrontingData.self, from: frontingData) {
                print("✅ Widget: Loaded fronting data - \(decoded.totalCount) fronting")
                return FrontingEntry(
                    date: Date(),
                    frontingMember: decoded.primaryMember,
                    frontCount: decoded.totalCount
                )
            } else {
                print("⚠️ Widget: Failed to decode fronting data")
            }
        } else {
            print("⚠️ Widget: No fronting data found in App Group")
        }
        
        // Fallback: no one fronting
        return FrontingEntry(date: Date(), frontingMember: nil, frontCount: 0)
    }
}

// MARK: - Timeline Entry
struct FrontingEntry: TimelineEntry {
    let date: Date
    let frontingMember: SharedMember?
    let frontCount: Int
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
struct WidgetAvatarView: View {
    let member: SharedMember
    let size: CGFloat

    var body: some View {
        Group {
            if let avatarURLString = member.avatarURL,
               !avatarURLString.isEmpty,
               let url = URL(string: avatarURLString) {
                // Show image avatar if available
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        // Fallback to color avatar with initials on error
                        ColorAvatarView(member: member, size: size)
                    case .empty:
                        // Show loading state with color background
                        ZStack {
                            ColorAvatarView(member: member, size: size)
                            ProgressView()
                                .tint(.white)
                        }
                    @unknown default:
                        ColorAvatarView(member: member, size: size)
                    }
                }
            } else {
                // No avatar URL, use color avatar with initials
                ColorAvatarView(member: member, size: size)
            }
        }
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
                .fill(LinearGradient(
                    colors: [member.displayColor, member.displayColor.opacity(0.7)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
            
            Text(member.initials)
                .font(.system(size: size * 0.35, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
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
            if let member = entry.frontingMember {
                // Show avatar with count badge if co-fronting
                WidgetAvatarView(member: member, size: 42)
                
                if entry.frontCount > 1 {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("\(entry.frontCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Color.purple)
                                .clipShape(Circle())
                        }
                    }
                    .padding(2)
                }
            } else {
                // No one fronting
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            }
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
        .widgetLabel {
            if entry.frontCount > 1 {
                Text("\(entry.frontCount) fronting")
            } else if entry.frontingMember != nil {
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
            if let member = entry.frontingMember {
                WidgetAvatarView(member: member, size: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.shortName)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    
                    if entry.frontCount > 1 {
                        Text("+\(entry.frontCount - 1) more")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    } else {
                        Text("Fronting")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            } else {
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
        if let member = entry.frontingMember {
            if entry.frontCount > 1 {
                Text("\(member.shortName) +\(entry.frontCount - 1)")
            } else {
                Text(member.shortName)
            }
        } else {
            Text("No front")
        }
    }
}

// MARK: - Corner Complication (e.g., Infograph Modular)
struct CornerComplicationView: View {
    let entry: FrontingEntry
    
    var body: some View {
        if let member = entry.frontingMember {
            Text(member.initials)
                .font(.system(size: 16, weight: .bold))
                .containerBackground(for: .widget) {
                    Color.clear
                }
                .widgetLabel {
                    if entry.frontCount > 1 {
                        Text("\(entry.frontCount) fronting")
                    } else {
                        Text("Fronting")
                    }
                }
        } else {
            Image(systemName: "moon.stars")
                .containerBackground(for: .widget) {
                    Color.clear
                }
                .widgetLabel {
                    Text("No front")
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
            // Circular - with member
            FrontingComplicationView(entry: FrontingEntry(
                date: Date(),
                frontingMember: SharedMember.example,
                frontCount: 1
            ))
            .previewContext(WidgetPreviewContext(family: .accessoryCircular))
            .previewDisplayName("Circular - Single")
            
            // Circular - co-fronting
            FrontingComplicationView(entry: FrontingEntry(
                date: Date(),
                frontingMember: SharedMember.example,
                frontCount: 3
            ))
            .previewContext(WidgetPreviewContext(family: .accessoryCircular))
            .previewDisplayName("Circular - Co-front")
            
            // Rectangular
            FrontingComplicationView(entry: FrontingEntry(
                date: Date(),
                frontingMember: SharedMember.example,
                frontCount: 2
            ))
            .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
            .previewDisplayName("Rectangular")
            
            // Inline
            FrontingComplicationView(entry: FrontingEntry(
                date: Date(),
                frontingMember: SharedMember.example,
                frontCount: 1
            ))
            .previewContext(WidgetPreviewContext(family: .accessoryInline))
            .previewDisplayName("Inline")
            
            // No one fronting
            FrontingComplicationView(entry: FrontingEntry(
                date: Date(),
                frontingMember: nil,
                frontCount: 0
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
        SharedMember(
            id: "example",
            name: "Alice",
            displayName: "Alice",
            color: "#9B59B6",
            avatarURL: nil  // Example uses color avatar
        )
    }
}
