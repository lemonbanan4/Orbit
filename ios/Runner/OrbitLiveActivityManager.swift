//
//  OrbitLiveActivityManager.swift
//
//  Bridges RoutineProvider (Dart) to ActivityKit. Live Activities represent
//  a bounded, ongoing event -- not a permanent fixture -- so this only ever
//  tracks "today's routine session": started on the first habit completion
//  of the day, updated on every subsequent one, ended once the day's due
//  habits are all complete or at the next daily reset. Home-screen widgets
//  (OrbitWidget/HabitWidget) remain the always-on surface; this is not a
//  replacement for them.
//

import ActivityKit
import Flutter
import UIKit

@available(iOS 16.2, *)
final class OrbitLiveActivityManager {
    static let shared = OrbitLiveActivityManager()
    private var activity: Activity<OrbitLiveActivityAttributes>?

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isSupported":
            result(ActivityAuthorizationInfo().areActivitiesEnabled)
        case "start":
            start(call.arguments, result: result)
        case "end":
            end(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// The in-memory `activity` reference is only ever set by this process --
    /// a relaunch after force-quit loses it even though the Activity itself
    /// is kept alive by the OS independent of the app process. Recover it
    /// from ActivityKit's own registry rather than risk starting a second,
    /// orphaned Activity alongside the one still on the Lock Screen.
    private func recoverExistingActivityIfNeeded() {
        guard activity == nil else { return }
        activity = Activity<OrbitLiveActivityAttributes>.activities.first
    }

    private func state(from arguments: Any?) -> OrbitLiveActivityAttributes.ContentState? {
        guard let args = arguments as? [String: Any],
              let completedCount = args["completedCount"] as? Int,
              let totalCount = args["totalCount"] as? Int,
              let streak = args["streak"] as? Int
        else { return nil }
        return OrbitLiveActivityAttributes.ContentState(
            completedCount: completedCount,
            totalCount: totalCount,
            streak: streak
        )
    }

    private func start(_ arguments: Any?, result: @escaping FlutterResult) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            result(false)
            return
        }
        recoverExistingActivityIfNeeded()
        guard let contentState = state(from: arguments) else {
            result(FlutterError(code: "bad_args", message: "Missing completedCount/totalCount/streak", details: nil))
            return
        }
        // Already running -- treat start as an update rather than stacking
        // a second Activity (the OS allows multiple, but Orbit only ever
        // wants one "today's session" activity at a time).
        if let existing = activity {
            Task {
                await existing.update(.init(state: contentState, staleDate: nil))
            }
            result(true)
            return
        }
        do {
            let newActivity = try Activity<OrbitLiveActivityAttributes>.request(
                attributes: OrbitLiveActivityAttributes(),
                content: .init(state: contentState, staleDate: nil)
            )
            activity = newActivity
            result(true)
        } catch {
            result(FlutterError(code: "start_failed", message: error.localizedDescription, details: nil))
        }
    }

    private func end(result: @escaping FlutterResult) {
        recoverExistingActivityIfNeeded()
        guard let current = activity else {
            result(true)
            return
        }
        Task {
            await current.end(current.content, dismissalPolicy: .after(.now.addingTimeInterval(60 * 5)))
            activity = nil
            result(true)
        }
    }
}
