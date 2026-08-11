//
//  OrbitWidgetBundle.swift
//  OrbitWidget
//
//  Created by lemon on 2026-05-22.
//

import WidgetKit
import SwiftUI

@main
struct OrbitWidgetBundle: WidgetBundle {
    var body: some Widget {
        OrbitWidget()
        if #available(iOS 16.2, *) {
            OrbitLiveActivity()
        }
    }
}
