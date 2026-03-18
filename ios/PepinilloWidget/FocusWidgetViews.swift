// FocusWidgetViews.swift
// Pepinillo — Deep Work Companion for Apple
//
// Widget views for all 3 Home Screen sizes and Lock Screen.
// Each size shows the appropriate amount of data with circular progress rings,
// live countdown timers, and full Pause/Resume/Stop controls.

import SwiftUI
import WidgetKit
import AppIntents

// MARK: - Reusable Progress Ring

private struct WidgetProgressRing<Content: View>: View {
    let progress: Double?
    let modeColor: Color
    let lineWidth: CGFloat
    let isPaused: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            Circle()
                .stroke(modeColor.opacity(0.2), lineWidth: lineWidth)
            if let progress {
                Circle()
                    .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                    .stroke(
                        modeColor.opacity(isPaused ? 0.5 : 1.0),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }
            content()
        }
    }
}

// MARK: - Live Timer Text Helper

private struct LiveTimerText: View {
    let entry: FocusWidgetEntry
    let font: Font

    var body: some View {
        if let start = entry.timerStart, let end = entry.timerEnd, !entry.isPaused {
            // Live countdown via system — updates every second without timeline refresh
            Text(timerInterval: start...end, countsDown: true)
                .font(font)
                .monospacedDigit()
                .multilineTextAlignment(.center)
        } else if let timer = entry.timerText {
            Text(timer)
                .font(font)
                .monospacedDigit()
        }
    }
}

// MARK: - Pause/Resume + Stop Controls

private struct WidgetControls: View {
    let entry: FocusWidgetEntry
    let compact: Bool

    var body: some View {
        HStack(spacing: compact ? 8 : 12) {
            if entry.isPaused {
                Button(intent: ResumeFocusFromWidgetIntent()) {
                    Label(String(localized: "Resume"), systemImage: "play.fill")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(maxWidth: compact ? nil : .infinity)
                }
                .tint(.green)
            } else {
                Button(intent: PauseFocusFromWidgetIntent()) {
                    Label(String(localized: "Pause"), systemImage: "pause.fill")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(maxWidth: compact ? nil : .infinity)
                }
                .tint(.orange)
            }

            Button(intent: StopFocusFromWidgetIntent()) {
                Label(String(localized: "Stop"), systemImage: "stop.fill")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .frame(maxWidth: compact ? nil : .infinity)
            }
            .tint(.red)
        }
    }
}

// MARK: - Small Widget (2x2)

struct FocusWidgetSmall: View {
    let entry: FocusWidgetEntry
    @Environment(\.showsWidgetContainerBackground) var showsBackground

    var body: some View {
        ZStack {
            if showsBackground {
                ContainerRelativeShape()
                    .fill(Color(.systemBackground))
            }

            if showsBackground {
                if entry.isSessionActive, let mode = entry.focusMode {
                    // Active session: progress ring with timer
                    let style = WidgetModeStyle.style(for: mode)
                    let modeColor = ModeColors.color(for: mode)

                    VStack(spacing: 6) {
                        WidgetProgressRing(
                            progress: entry.progress,
                            modeColor: modeColor,
                            lineWidth: 6,
                            isPaused: entry.isPaused
                        ) {
                            VStack(spacing: 2) {
                                Text(style.emoji)
                                    .font(.title3)
                                LiveTimerText(
                                    entry: entry,
                                    font: .system(.title2, design: .rounded, weight: .bold)
                                )
                            }
                        }
                        .frame(width: 90, height: 90)

                        if entry.isPaused {
                            Text(String(localized: "Paused"))
                                .font(.caption2)
                                .foregroundStyle(.orange)
                                .fontWeight(.medium)
                        } else {
                            Text(entry.phase ?? String(localized: "Focusing"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        if let task = entry.linkedTaskTitle {
                            Text(task)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(10)
                } else {
                    // Idle state: daily stats + start button
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "brain.head.profile")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("Pepinillo")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }

                        Spacer()

                        VStack(alignment: .leading, spacing: 4) {
                            Text(formattedMinutes(entry.todayFocusMinutes))
                                .font(.system(.title2, design: .rounded, weight: .bold))

                            Text(String(localized: "today"))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if entry.currentStreakDays > 0 {
                                HStack(spacing: 3) {
                                    Image(systemName: "flame.fill")
                                        .font(.caption2)
                                        .foregroundStyle(ModeColors.streak)
                                    Text("\(entry.currentStreakDays)d")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                }
                            }
                        }

                        Button(intent: StartFocusFromWidgetIntent()) {
                            Label(String(localized: "Start"), systemImage: "play.fill")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .tint(.accentColor)
                    }
                    .padding(12)
                }
            } else {
                // StandBy mode: large, high-contrast
                VStack(spacing: 8) {
                    if entry.isSessionActive, let mode = entry.focusMode {
                        let style = WidgetModeStyle.style(for: mode)
                        let modeColor = ModeColors.color(for: mode)

                        WidgetProgressRing(
                            progress: entry.progress,
                            modeColor: modeColor,
                            lineWidth: 6,
                            isPaused: entry.isPaused
                        ) {
                            VStack(spacing: 4) {
                                Text(style.emoji)
                                    .font(.system(size: 28))
                                LiveTimerText(
                                    entry: entry,
                                    font: .system(size: 36, weight: .bold, design: .rounded)
                                )
                            }
                        }
                        .frame(width: 120, height: 120)

                        if entry.isPaused {
                            Text(String(localized: "Paused"))
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    } else {
                        Text(formattedMinutes(entry.todayFocusMinutes))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text(String(localized: "today"))
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Medium Widget (4x2)

struct FocusWidgetMedium: View {
    let entry: FocusWidgetEntry
    @Environment(\.showsWidgetContainerBackground) var showsBackground

    var body: some View {
        ZStack {
            if showsBackground {
                ContainerRelativeShape()
                    .fill(Color(.systemBackground))
            }

            if showsBackground {
                if entry.isSessionActive, let mode = entry.focusMode {
                    // Active session: ring + info + controls
                    let style = WidgetModeStyle.style(for: mode)
                    let modeColor = ModeColors.color(for: mode)

                    HStack(spacing: 14) {
                        // Progress ring with mode emoji
                        WidgetProgressRing(
                            progress: entry.progress,
                            modeColor: modeColor,
                            lineWidth: 5,
                            isPaused: entry.isPaused
                        ) {
                            Text(style.emoji)
                                .font(.title2)
                        }
                        .frame(width: 64, height: 64)

                        VStack(alignment: .leading, spacing: 3) {
                            // Timer
                            LiveTimerText(
                                entry: entry,
                                font: .system(.title2, design: .rounded, weight: .bold)
                            )

                            // Phase + Pomodoro counter
                            HStack(spacing: 6) {
                                if entry.isPaused {
                                    Text(String(localized: "Paused"))
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                        .fontWeight(.medium)
                                } else {
                                    Text(entry.phase ?? "")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let pn = entry.pomodoroNumber, let tp = entry.totalPomodoros {
                                    Text("\(pn)/\(tp)")
                                        .font(.caption)
                                        .foregroundStyle(modeColor)
                                        .fontWeight(.semibold)
                                }
                            }

                            // Linked task
                            if let task = entry.linkedTaskTitle {
                                HStack(spacing: 3) {
                                    Image(systemName: "link")
                                        .font(.caption2)
                                    Text(task)
                                        .lineLimit(1)
                                }
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 0)

                            // Controls
                            WidgetControls(entry: entry, compact: true)
                        }
                    }
                    .padding(14)
                } else {
                    // Idle state: stats + start button
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 4) {
                                Image(systemName: "brain.head.profile")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("Pepinillo")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(formattedMinutes(entry.todayFocusMinutes))
                                .font(.system(.title, design: .rounded, weight: .bold))
                            Text(String(localized: "focused today"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 10) {
                            StatRow(icon: "checkmark.circle", label: String(localized: "Sessions"), value: "\(entry.todaySessionsCompleted)")
                            if entry.currentStreakDays > 0 {
                                StatRow(icon: "flame.fill", label: String(localized: "Streak"), value: String(localized: "\(entry.currentStreakDays) days"), color: ModeColors.streak)
                            }
                            if let dominant = entry.dominantMode {
                                let style = WidgetModeStyle.style(for: dominant)
                                StatRow(icon: style.systemImage, label: String(localized: "Top mode"), value: dominant.capitalized)
                            }

                            Spacer()

                            Button(intent: StartFocusFromWidgetIntent()) {
                                Label(String(localized: "Start"), systemImage: "play.fill")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                            }
                            .tint(.accentColor)
                        }
                    }
                    .padding(14)
                }
            } else {
                // StandBy mode
                HStack(spacing: 16) {
                    if entry.isSessionActive, let mode = entry.focusMode {
                        let style = WidgetModeStyle.style(for: mode)
                        let modeColor = ModeColors.color(for: mode)

                        WidgetProgressRing(
                            progress: entry.progress,
                            modeColor: modeColor,
                            lineWidth: 6,
                            isPaused: entry.isPaused
                        ) {
                            Text(style.emoji)
                                .font(.system(size: 32))
                        }
                        .frame(width: 80, height: 80)

                        VStack(alignment: .leading, spacing: 4) {
                            LiveTimerText(
                                entry: entry,
                                font: .system(size: 56, weight: .bold, design: .rounded)
                            )
                            .foregroundStyle(.primary)

                            if entry.isPaused {
                                Text(String(localized: "Paused"))
                                    .font(.title3)
                                    .foregroundStyle(.orange)
                            } else {
                                Text(entry.phase ?? String(localized: "Focusing"))
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(formattedMinutes(entry.todayFocusMinutes))
                                .font(.system(size: 56, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                            Text(String(localized: "focused today"))
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        if entry.currentStreakDays > 0 {
                            VStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                    .font(.title2)
                                    .foregroundStyle(ModeColors.streak)
                                Text("\(entry.currentStreakDays)d")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Large Widget (4x4)

struct FocusWidgetLarge: View {
    let entry: FocusWidgetEntry
    @Environment(\.showsWidgetContainerBackground) var showsBackground

    var body: some View {
        ZStack {
            if showsBackground {
                ContainerRelativeShape()
                    .fill(Color(.systemBackground))
            }

            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundStyle(.secondary)
                    Text("Pepinillo")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    if entry.currentStreakDays > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(ModeColors.streak)
                            Text("\(entry.currentStreakDays)d")
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                    }
                }

                // Main: session or total
                if entry.isSessionActive, let mode = entry.focusMode {
                    let style = WidgetModeStyle.style(for: mode)
                    let modeColor = ModeColors.color(for: mode)

                    // Progress ring centered
                    HStack {
                        Spacer()
                        WidgetProgressRing(
                            progress: entry.progress,
                            modeColor: modeColor,
                            lineWidth: 8,
                            isPaused: entry.isPaused
                        ) {
                            VStack(spacing: 2) {
                                Text(style.emoji)
                                    .font(.title2)
                                LiveTimerText(
                                    entry: entry,
                                    font: .system(.largeTitle, design: .rounded, weight: .bold)
                                )
                                if let pn = entry.pomodoroNumber, let tp = entry.totalPomodoros {
                                    Text("\(pn)/\(tp)")
                                        .font(.caption)
                                        .foregroundStyle(modeColor)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                        .frame(width: 120, height: 120)
                        Spacer()
                    }

                    // Phase + task
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            if entry.isPaused {
                                Text(String(localized: "Paused"))
                                    .font(.subheadline)
                                    .foregroundStyle(.orange)
                                    .fontWeight(.medium)
                            } else {
                                Text(entry.phase ?? String(localized: "Focusing"))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            if let task = entry.linkedTaskTitle {
                                HStack(spacing: 3) {
                                    Image(systemName: "link")
                                        .font(.caption2)
                                    Text(task)
                                        .lineLimit(1)
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }

                    // Controls
                    WidgetControls(entry: entry, compact: false)

                } else {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(formattedMinutes(entry.todayFocusMinutes))
                                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            Text(String(localized: "focused today"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(intent: StartFocusFromWidgetIntent()) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 44))
                        }
                        .tint(.accentColor)
                    }
                }

                // Mode breakdown (both states)
                if !entry.modeMinutes.isEmpty {
                    Divider()

                    Text(String(localized: "Time by mode"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    VStack(spacing: 6) {
                        ForEach(sortedModes, id: \.key) { mode, minutes in
                            ModeBar(mode: mode, minutes: minutes, totalMinutes: entry.todayFocusMinutes)
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private var sortedModes: [(key: String, value: Int)] {
        entry.modeMinutes
            .filter { $0.value > 0 }
            .sorted { $0.value > $1.value }
            .map { (key: $0.key, value: $0.value) }
    }
}

// MARK: - Lock Screen Accessory Widgets

struct FocusWidgetAccessoryCircular: View {
    let entry: FocusWidgetEntry

    var body: some View {
        ZStack {
            if entry.isSessionActive, let progress = entry.progress {
                Gauge(value: progress) { EmptyView() }
                    .gaugeStyle(.accessoryCircularCapacity)
            }
            if entry.isSessionActive && entry.isPaused {
                Image(systemName: "pause.fill")
                    .font(.caption2)
            } else {
                Image(systemName: "brain.head.profile")
                    .font(.caption)
            }
        }
    }
}

struct FocusWidgetAccessoryRectangular: View {
    let entry: FocusWidgetEntry

    var body: some View {
        HStack {
            Image(systemName: "brain.head.profile")
                .font(.subheadline)

            VStack(alignment: .leading, spacing: 2) {
                if entry.isSessionActive {
                    if entry.isPaused {
                        if let timer = entry.timerText {
                            Text(timer)
                                .font(.headline)
                                .monospacedDigit()
                        }
                        Text(String(localized: "Paused"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if let start = entry.timerStart, let end = entry.timerEnd {
                        Text(timerInterval: start...end, countsDown: true)
                            .font(.headline)
                            .monospacedDigit()
                        Text(entry.phase ?? String(localized: "Focusing"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if let timer = entry.timerText {
                        Text(timer)
                            .font(.headline)
                            .monospacedDigit()
                        Text(entry.phase ?? String(localized: "Focusing"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(formattedMinutes(entry.todayFocusMinutes))
                        .font(.headline)
                    Text(String(localized: "today"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    var color: Color = .accentColor

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 14)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
        }
    }
}

struct ModeBar: View {
    let mode: String
    let minutes: Int
    let totalMinutes: Int

    var body: some View {
        HStack(spacing: 8) {
            let style = WidgetModeStyle.style(for: mode)
            Text(style.emoji)
                .font(.caption)
                .frame(width: 18)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 8)
                    Capsule()
                        .fill(modeColor)
                        .frame(
                            width: totalMinutes > 0
                                ? geo.size.width * CGFloat(minutes) / CGFloat(totalMinutes)
                                : 0,
                            height: 8
                        )
                }
            }
            .frame(height: 8)

            Text(formattedMinutes(minutes))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)
        }
    }

    private var modeColor: Color {
        ModeColors.color(for: mode)
    }
}

// MARK: - Helpers

private func formattedMinutes(_ minutes: Int) -> String {
    if minutes >= 60 {
        let h = minutes / 60
        let m = minutes % 60
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }
    return "\(minutes)m"
}
