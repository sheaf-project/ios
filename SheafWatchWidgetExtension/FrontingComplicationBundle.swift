//
//  FrontingComplicationBundle.swift
//  SheafWatchWidgetExtension
//
//  Widget bundle entry point for watch complications
//

import WidgetKit
import SwiftUI

// MARK: - Widget Bundle Entry Point
@main
struct FrontingComplicationBundle: WidgetBundle {
    var body: some Widget {
        FrontingComplication()
    }
}
