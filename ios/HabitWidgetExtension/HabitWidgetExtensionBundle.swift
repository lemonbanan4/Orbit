//
//  HabitWidgetExtensionBundle.swift
//  HabitWidgetExtension
//
//  Created by lemon on 2026-06-20.
//

import WidgetKit
import SwiftUI

@main
struct HabitWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        HabitWidgetExtension()
        HabitWidgetExtensionControl()
        HabitWidgetExtensionLiveActivity()
    }
}
