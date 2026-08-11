//
//  OrbitLiveActivity.swift
//  OrbitWidget
//
//  Lock Screen + Dynamic Island UI for today's routine session. Started by
//  OrbitLiveActivityManager (Runner target) on the first habit completion
//  of the day, updated on every subsequent one, ended once the day's due
//  habits are all complete or at the next daily reset.
//

import ActivityKit
import WidgetKit
import SwiftUI

@available(iOS 16.2, *)
struct OrbitLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: OrbitLiveActivityAttributes.self) { context in
            OrbitLiveActivityLockScreenView(state: context.state)
                .activityBackgroundTint(Color(red: 0.02, green: 0.04, blue: 0.14))
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 4) {
                        Text("🔥")
                        Text("\(context.state.streak)")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.completedCount)/\(context.state.totalCount)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color(red: 0.0, green: 0.9, blue: 1.0))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    OrbitLiveActivityProgressBar(state: context.state)
                        .padding(.top, 4)
                }
            } compactLeading: {
                Text("🔥\(context.state.streak)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            } compactTrailing: {
                Text("\(context.state.completedCount)/\(context.state.totalCount)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(red: 0.0, green: 0.9, blue: 1.0))
            } minimal: {
                Text("🔥")
            }
            .widgetURL(URL(string: "orbit://habit"))
            .keylineTint(Color(red: 0.0, green: 0.9, blue: 1.0))
        }
    }
}

@available(iOS 16.2, *)
private struct OrbitLiveActivityLockScreenView: View {
    let state: OrbitLiveActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("🔥 \(state.streak) day streak")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Text("\(state.completedCount) of \(state.totalCount) habits today")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                OrbitLiveActivityProgressBar(state: state)
                    .frame(height: 6)
                    .padding(.top, 4)
            }
            Spacer()
        }
        .padding(16)
    }
}

@available(iOS 16.2, *)
private struct OrbitLiveActivityProgressBar: View {
    let state: OrbitLiveActivityAttributes.ContentState

    private var progress: Double {
        state.totalCount > 0 ? Double(state.completedCount) / Double(state.totalCount) : 0
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.15))
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(red: 0.0, green: 0.9, blue: 1.0))
                    .frame(width: geometry.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: 6)
    }
}
