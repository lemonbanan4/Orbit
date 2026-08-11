//
//  OrbitLiveActivityAttributes.swift
//
//  Shape shared between the Runner app (which starts/updates/ends the
//  Activity) and OrbitWidgetExtension (which renders it). These run in
//  separate processes -- ActivityKit marshals ContentState updates via
//  Codable, so this file is intentionally duplicated verbatim in both
//  targets rather than shared via a common framework; keep both copies
//  in sync if this shape ever changes.
//

import ActivityKit

struct OrbitLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var completedCount: Int
        var totalCount: Int
        var streak: Int
    }
}
