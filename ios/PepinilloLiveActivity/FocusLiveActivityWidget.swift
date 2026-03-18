// FocusLiveActivityWidget.swift
// Pepinillo — Deep Work Companion for Apple
//
// WidgetKit Live Activity configuration combining all 4 Dynamic Island presentations
// and the Lock Screen banner view.

import ActivityKit
import WidgetKit
import SwiftUI

struct FocusLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            // MARK: - Lock Screen / StandBy / Banner
            FocusLockScreenView(
                attributes: context.attributes,
                state: context.state
            )
            .activityBackgroundTint(Color.black.opacity(0.8))
            .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                // MARK: - Expanded
                DynamicIslandExpandedRegion(.leading) {
                    FocusDynamicIslandCompactLeading(state: context.state)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    FocusDynamicIslandCompactTrailing(state: context.state)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    FocusDynamicIslandExpanded(
                        attributes: context.attributes,
                        state: context.state
                    )
                }
                DynamicIslandExpandedRegion(.bottom) {
                    // Progress bar at the bottom of expanded island
                    if let progress = context.state.progress {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.15))
                                    .frame(height: 3)
                                Capsule()
                                    .fill(modeColor(for: context.state.focusMode))
                                    .frame(width: geo.size.width * progress, height: 3)
                            }
                        }
                        .frame(height: 3)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 6)
                    }
                }
            } compactLeading: {
                FocusDynamicIslandCompactLeading(state: context.state)
            } compactTrailing: {
                FocusDynamicIslandCompactTrailing(state: context.state)
            } minimal: {
                FocusDynamicIslandMinimal(state: context.state)
            }
        }
    }

    private func modeColor(for mode: String) -> Color {
        switch mode {
        case "pomodoro":  return Color(red: 0.91, green: 0.30, blue: 0.24)
        case "flowtime":  return Color(red: 0.20, green: 0.53, blue: 0.92)
        case "timeBlock": return Color(red: 0.56, green: 0.27, blue: 0.87)
        case "stopwatch": return Color(red: 0.18, green: 0.72, blue: 0.44)
        default:          return .blue
        }
    }
}
