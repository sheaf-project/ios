//
//  TestMinimalWidget.swift
//  TEMPORARY FILE FOR TESTING
//
//  Use this to test if a basic widget can install.
//  If this works but FrontingComplication doesn't, the issue is in FrontingComplication.swift
//

import WidgetKit
import SwiftUI

// MARK: - Minimal Test Widget (No App Groups, No Dependencies)

struct TestEntry: TimelineEntry {
    let date: Date
}

struct TestProvider: TimelineProvider {
    func placeholder(in context: Context) -> TestEntry {
        TestEntry(date: Date())
    }
    
    func getSnapshot(in context: Context, completion: @escaping (TestEntry) -> Void) {
        completion(TestEntry(date: Date()))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<TestEntry>) -> Void) {
        let entry = TestEntry(date: Date())
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

struct TestWidgetView: View {
    var entry: TestEntry
    
    var body: some View {
        Text("Test")
            .font(.caption)
    }
}

struct TestMinimalWidget: Widget {
    let kind: String = "TestMinimalWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TestProvider()) { entry in
            TestWidgetView(entry: entry)
        }
        .configurationDisplayName("Test")
        .description("Minimal test widget")
        .supportedFamilies([.accessoryCircular])
    }
}

// MARK: - INSTRUCTIONS
/*
 
 TO TEST THIS:
 
 1. Open FrontingComplicationBundle.swift (or FrontingComplicationBundle-SheafWatchWidgetExtension.swift)
 
 2. TEMPORARILY replace the @main widget bundle with this:
 
    @main
    struct FrontingComplicationBundle: WidgetBundle {
        var body: some Widget {
            TestMinimalWidget()  // ← Changed from FrontingComplication()
        }
    }
 
 3. Make sure TestMinimalWidget.swift is included in the SheafWatchWidgetExtension target
    (Check Target Membership in File Inspector)
 
 4. Clean and rebuild
 
 5. Try to install
 
 RESULTS:
 - If it WORKS: The issue is in FrontingComplication.swift or its dependencies
 - If it FAILS: The issue is with the widget extension target configuration itself
 
 6. Don't forget to change it back to FrontingComplication() when done!
 
 */
