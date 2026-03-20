import WidgetKit
import SwiftUI

// MARK: - Timeline Provider
struct FrontingComplicationProvider: TimelineProvider {
    typealias Entry = FrontingEntry
    
    func placeholder(in context: Context) -> FrontingEntry {
        FrontingEntry(date: Date(), frontingMember: nil, frontCount: 0)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (FrontingEntry) -> Void) {
        // For previews in the widget gallery
        let entry = FrontingEntry(
            date: Date(),
            frontingMember: Member.example,
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
        if let sharedData = UserDefaults(suiteName: "group.com.yourdomain.sheaf") {
            if let frontingData = sharedData.data(forKey: "currentFronting"),
               let decoded = try? JSONDecoder().decode(SharedFrontingData.self, from: frontingData) {
                return FrontingEntry(
                    date: Date(),
                    frontingMember: decoded.primaryMember,
                    frontCount: decoded.totalCount
                )
            }
        }
        
        // Fallback: no one fronting
        return FrontingEntry(date: Date(), frontingMember: nil, frontCount: 0)
    }
}

// MARK: - Timeline Entry
struct FrontingEntry: TimelineEntry {
    let date: Date
    let frontingMember: Member?
    let frontCount: Int
}

// MARK: - Shared Data Model
struct SharedFrontingData: Codable {
    let primaryMember: Member?
    let totalCount: Int
    let updatedAt: Date
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
        case .accessoryCorner:
            CornerComplicationView(entry: entry)
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
                AvatarView(member: member, size: 42)
                    .clipShape(Circle())
                
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
                }
            } else {
                // No one fronting
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            }
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
                AvatarView(member: member, size: 32)
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.displayName ?? member.name)
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
    }
}

// MARK: - Inline Complication (e.g., Modular Compact)
struct InlineComplicationView: View {
    let entry: FrontingEntry
    
    var body: some View {
        if let member = entry.frontingMember {
            if entry.frontCount > 1 {
                Text("\(member.displayName ?? member.name) +\(entry.frontCount - 1)")
            } else {
                Text(member.displayName ?? member.name)
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
            Text(String((member.displayName ?? member.name).prefix(3)))
                .font(.system(size: 16, weight: .bold))
                .widgetLabel {
                    if entry.frontCount > 1 {
                        Text("\(entry.frontCount) fronting")
                    } else {
                        Text("Fronting")
                    }
                }
        } else {
            Image(systemName: "moon.stars")
                .widgetLabel {
                    Text("No front")
                }
        }
    }
}

// MARK: - Widget Configuration
@main
struct FrontingComplication: Widget {
    let kind: String = "FrontingComplication"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FrontingComplicationProvider()) { entry in
            FrontingComplicationView(entry: entry)
        }
        .configurationDisplayName("Fronting Status")
        .description("Shows who's currently fronting")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
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
                frontingMember: Member.example,
                frontCount: 1
            ))
            .previewContext(WidgetPreviewContext(family: .accessoryCircular))
            .previewDisplayName("Circular - Single")
            
            // Circular - co-fronting
            FrontingComplicationView(entry: FrontingEntry(
                date: Date(),
                frontingMember: Member.example,
                frontCount: 3
            ))
            .previewContext(WidgetPreviewContext(family: .accessoryCircular))
            .previewDisplayName("Circular - Co-front")
            
            // Rectangular
            FrontingComplicationView(entry: FrontingEntry(
                date: Date(),
                frontingMember: Member.example,
                frontCount: 2
            ))
            .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
            .previewDisplayName("Rectangular")
            
            // Inline
            FrontingComplicationView(entry: FrontingEntry(
                date: Date(),
                frontingMember: Member.example,
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
extension Member {
    static var example: Member {
        Member(
            id: "example",
            name: "Alice",
            displayName: "Alice",
            pronouns: "she/her",
            avatarURL: nil,
            color: "#9B59B6",
            description: nil,
            birthday: nil,
            privacy: nil,
            proxyTags: nil,
            keepProxy: nil,
            autoproxyEnabled: nil,
            messageCount: nil,
            lastMessageTimestamp: nil,
            created: nil,
            bannerImage: nil
        )
    }
}
