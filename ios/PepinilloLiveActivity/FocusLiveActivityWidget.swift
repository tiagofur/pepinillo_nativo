// FocusLiveActivityWidget.swift
// Pepinillo — Deep Work Companion for Apple
//
// WidgetKit Live Activity configuration combining all 4 Dynamic Island presentations
// and the Lock Screen banner view.

import ActivityKit
import WidgetKit
import SwiftUI

@ViewBuilder
private func liveProgressBar(
    state: FocusActivityAttributes.ContentState,
    width: CGFloat
) -> some View {
    let modeColor = ModeColors.color(for: state.focusMode)
    let countsDown = state.focusMode == "pomodoro" || state.focusMode == "timeBlock"

    if let start = state.timerStart, let end = state.timerEnd, !state.isPaused {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let duration = max(end.timeIntervalSince(start), 1)
            let completed = min(max(context.date.timeIntervalSince(start) / duration, 0), 1)
            let visible = countsDown ? 1 - completed : completed
            Capsule()
                .fill(modeColor)
                .frame(width: width * visible, height: 3)
        }
    } else if let progress = state.progress {
        let visible = countsDown ? 1 - progress : progress
        Capsule()
            .fill(modeColor)
            .frame(width: width * visible, height: 3)
    }
}

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
                    if context.state.progress != nil
                        || (context.state.timerStart != nil && context.state.timerEnd != nil) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.15))
                                    .frame(height: 3)
                                liveProgressBar(state: context.state, width: geo.size.width)
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

}
