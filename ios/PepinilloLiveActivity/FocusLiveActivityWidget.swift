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
                                    .fill(ModeColors.color(for: context.state.focusMode))
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

}
