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
        ModeColors.color(for: focusMode)
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

// MARK: - Lock Screen / Notification Banner View

struct FocusLockScreenView: View {
    let attributes: FocusActivityAttributes
    let state: FocusActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 16) {
            // Mode icon + progress ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 4)
                    .frame(width: 48, height: 48)

                if let progress = state.progress {
                    Circle()
                        .trim(from: 0, to: CGFloat(progress))
                        .stroke(state.modeColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 48, height: 48)
                }

                Text(state.modeEmoji)
                    .font(.title2)
            }

            VStack(alignment: .leading, spacing: 3) {
                // Phase + task name
                HStack(spacing: 6) {
                    Text(state.phase)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)

                    if state.isPaused {
                        Image(systemName: "pause.fill")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }

                if let task = state.taskName {
                    Text(task)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                }
            }

            Spacer()

            // Timer display
            VStack(alignment: .trailing, spacing: 2) {
                Text(state.formattedTime)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white)

                // Pomodoro counter
                if let num = state.pomodoroNumber, let total = state.totalPomodoros {
                    HStack(spacing: 3) {
                        ForEach(1...total, id: \.self) { i in
                            Circle()
                                .fill(i <= num ? state.modeColor : Color.white.opacity(0.3))
                                .frame(width: 6, height: 6)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.85))
        )
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
        Text(state.formattedTime)
            .font(.system(.caption, design: .rounded, weight: .semibold))
            .monospacedDigit()
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
            // Left: mode + progress
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(state.modeColor.opacity(0.25), lineWidth: 5)
                        .frame(width: 52, height: 52)

                    if let progress = state.progress {
                        Circle()
                            .trim(from: 0, to: CGFloat(progress))
                            .stroke(state.modeColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 52, height: 52)
                    }

                    Text(state.modeEmoji)
                        .font(.title2)
                }

                Text(state.phase)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Center: timer + task
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(state.formattedTime)
                        .font(.system(.title, design: .rounded, weight: .light))
                        .monospacedDigit()

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

            // Right: Pomodoro dots
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
