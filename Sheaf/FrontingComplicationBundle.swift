//
//  FrontingComplicationBundle.swift
//  SheafWatchWidgetExtension
//
//  Widget bundle entry point for watch complications
//

import WidgetKit
import SwiftUI

// MARK: - Widget Bundle Entry Point
// IMPORTANT: Only uncomment @main after you've moved this file to the
// SheafWatchWidgetExtension target (and removed it from Watch App target)

// @main
struct FrontingComplicationBundle: WidgetBundle {
    var body: some Widget {
        FrontingComplication()
    }
}
