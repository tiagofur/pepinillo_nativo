// FocusLiveActivityView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Lock Screen and Dynamic Island views for all 4 focus modes.
// The Live Activity keeps the session visible without opening the app.

import SwiftUI
import ActivityKit
import WidgetKit

// MARK: - Shared Live Activity Helpers

private extension FocusActivityAttributes.ContentState {
    var modeEmoji: String {
        switch focusMode {
        case "pomodoro":  return "🍅"
        case "flowtime":  return "🌊"
        case "timeBlock": return "📦"
        case "stopwatch": return "⏱️"
        default:          return "🧠"
        }
    }

    var modeColor: Color {
        ModeColors.color(for: focusMode, phase: phase)
    }

    var modeSystemImage: String {
        switch focusMode {
        case "pomodoro":  return "timer"
        case "flowtime":  return "wind"
        case "timeBlock": return "rectangle.split.3x1"
        case "stopwatch": return "stopwatch"
        default:          return "brain.head.profile"
        }
    }

    var countsDown: Bool {
        focusMode == "pomodoro" || focusMode == "timeBlock"
    }

    var formattedTime: String {
        if let remaining = remainingSeconds {
            let m = remaining / 60
            let s = remaining % 60
            return String(format: "%d:%02d", m, s)
        }
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Live Timer Text

private struct FocusLiveTimerText: View {
    let state: FocusActivityAttributes.ContentState
    let font: Font

    var body: some View {
        if let start = state.timerStart, let end = state.timerEnd, !state.isPaused {
            Text(timerInterval: start...end, countsDown: true)
                .font(font)
                .monospacedDigit()
        } else if let start = state.timerStart, state.countsDown == false, !state.isPaused {
            Text(timerInterval: start...Date.distantFuture, countsDown: false)
                .font(font)
                .monospacedDigit()
        } else {
            Text(state.formattedTime)
                .font(font)
                .monospacedDigit()
        }
    }
}

// MARK: - Live Progress Ring

private struct FocusLiveProgressRing<Content: View>: View {
    let state: FocusActivityAttributes.ContentState
    let lineWidth: CGFloat
    let frameSize: CGFloat
    let content: Content

    init(
        state: FocusActivityAttributes.ContentState,
        lineWidth: CGFloat,
        frameSize: CGFloat,
        @ViewBuilder content: () -> Content
    ) {
        self.state = state
        self.lineWidth = lineWidth
        self.frameSize = frameSize
        self.content = content()
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(state.modeColor.opacity(0.25), lineWidth: lineWidth)
                .frame(width: frameSize, height: frameSize)

            if let start = state.timerStart, let end = state.timerEnd, !state.isPaused {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    progressStroke(visibleProgress: liveVisibleProgress(at: context.date, start: start, end: end))
                }
            } else if let progress = state.progress {
                progressStroke(visibleProgress: visibleProgress(from: progress))
            }

            content
        }
    }

    private func progressStroke(visibleProgress: Double) -> some View {
        Circle()
            .trim(from: 0, to: CGFloat(min(max(visibleProgress, 0), 1)))
            .stroke(state.modeColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .frame(width: frameSize, height: frameSize)
    }

    private func visibleProgress(from progress: Double) -> Double {
        let clamped = min(max(progress, 0), 1)
        return state.countsDown ? 1 - clamped : clamped
    }

    private func liveVisibleProgress(at date: Date, start: Date, end: Date) -> Double {
        let duration = max(end.timeIntervalSince(start), 1)
        let completed = min(max(date.timeIntervalSince(start) / duration, 0), 1)
        return state.countsDown ? 1 - completed : completed
    }
}

// MARK: - Lock Screen / Notification Banner View

struct FocusLockScreenView: View {
    let attributes: FocusActivityAttributes
    let state: FocusActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 16) {
            FocusLiveProgressRing(state: state, lineWidth: 4, frameSize: 48) {
                Text(state.modeEmoji)
                    .font(.title2)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(state.phase)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    if state.isPaused {
                        Image(systemName: "pause.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let task = state.taskName {
                    Text(task)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                FocusLiveTimerText(
                    state: state,
                    font: .system(.title3, design: .rounded, weight: .semibold)
                )
                .foregroundStyle(.primary)

                if let num = state.pomodoroNumber, let total = state.totalPomodoros {
                    HStack(spacing: 3) {
                        ForEach(1...total, id: \.self) { i in
                            Circle()
                                .fill(i <= num ? state.modeColor : Color.secondary.opacity(0.4))
                                .frame(width: 6, height: 6)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Dynamic Island Views

/// Compact Leading — shown in the pill island compact form
struct FocusDynamicIslandCompactLeading: View {
    let state: FocusActivityAttributes.ContentState

    var body: some View {
        Text(state.modeEmoji)
            .font(.caption)
    }
}

/// Compact Trailing — timer or progress
struct FocusDynamicIslandCompactTrailing: View {
    let state: FocusActivityAttributes.ContentState

    var body: some View {
        FocusLiveTimerText(
            state: state,
            font: .system(.caption, design: .rounded, weight: .semibold)
        )
        .foregroundStyle(state.modeColor)
    }
}

/// Minimal — smallest form, just an icon
struct FocusDynamicIslandMinimal: View {
    let state: FocusActivityAttributes.ContentState

    var body: some View {
        Image(systemName: state.modeSystemImage)
            .font(.caption2)
            .foregroundStyle(state.modeColor)
    }
}

/// Expanded — full Dynamic Island expanded view
struct FocusDynamicIslandExpanded: View {
    let attributes: FocusActivityAttributes
    let state: FocusActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 20) {
            VStack(spacing: 8) {
                FocusLiveProgressRing(state: state, lineWidth: 5, frameSize: 52) {
                    Text(state.modeEmoji)
                        .font(.title2)
                }

                Text(state.phase)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    FocusLiveTimerText(
                        state: state,
                        font: .system(.title, design: .rounded, weight: .light)
                    )

                    if state.isPaused {
                        Image(systemName: "pause.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }

                if let task = state.taskName {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(task)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            if let num = state.pomodoroNumber, let total = state.totalPomodoros {
                VStack(spacing: 4) {
                    Text("\(num)/\(total)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 3) {
                        ForEach(1...min(total, 6), id: \.self) { i in
                            Circle()
                                .fill(i <= num ? state.modeColor : Color.secondary.opacity(0.3))
                                .frame(width: 7, height: 7)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

}