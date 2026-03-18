// FocusWidgetViews.swift
// Pepinillo — Deep Work Companion for Apple
//
// Widget views for all 3 Home Screen sizes and Lock Screen.
// Each size shows the appropriate amount of data.

import SwiftUI
import WidgetKit
import AppIntents

// MARK: - Small Widget (2x2)

struct FocusWidgetSmall: View {
    let entry: FocusWidgetEntry
    @Environment(\.showsWidgetContainerBackground) var showsBackground

    var body: some View {
        ZStack {
            // Background
            if showsBackground {
                ContainerRelativeShape()
                    .fill(Color(.systemBackground))
            }

            if showsBackground {
                // Normal Home Screen layout
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

                    if entry.isSessionActive, let mode = entry.focusMode, let timer = entry.timerText {
                        let style = WidgetModeStyle.style(for: mode)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(style.emoji)
                                .font(.title2)

                            Text(timer)
                                .font(.system(.title, design: .rounded, weight: .bold))
                                .monospacedDigit()

                            Text(entry.phase ?? String(localized: "Focusing"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    } else {
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
                }
                .padding(12)
            } else {
                // StandBy mode: large, high-contrast, minimal
                VStack(spacing: 8) {
                    if entry.isSessionActive, let mode = entry.focusMode, let timer = entry.timerText {
                        let style = WidgetModeStyle.style(for: mode)
                        Text(style.emoji)
                            .font(.system(size: 36))
                        Text(timer)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
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
                // Normal Home Screen layout
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

                        if entry.isSessionActive, let mode = entry.focusMode, let timer = entry.timerText {
                            let style = WidgetModeStyle.style(for: mode)
                            Text(style.emoji)
                                .font(.largeTitle)
                            Text(timer)
                                .font(.system(.title2, design: .rounded, weight: .bold))
                                .monospacedDigit()
                            Text(entry.phase ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(formattedMinutes(entry.todayFocusMinutes))
                                .font(.system(.title, design: .rounded, weight: .bold))
                            Text(String(localized: "focused today"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
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

                        if entry.isSessionActive {
                            Button(intent: StopFocusFromWidgetIntent()) {
                                Label(String(localized: "Stop"), systemImage: "stop.fill")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                            }
                            .tint(.red)
                        } else {
                            Button(intent: StartFocusFromWidgetIntent()) {
                                Label(String(localized: "Start"), systemImage: "play.fill")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                            }
                            .tint(.accentColor)
                        }
                    }
                }
                .padding(14)
            } else {
                // StandBy mode: large timer + emoji, centered
                HStack(spacing: 16) {
                    if entry.isSessionActive, let mode = entry.focusMode, let timer = entry.timerText {
                        let style = WidgetModeStyle.style(for: mode)
                        Text(style.emoji)
                            .font(.system(size: 44))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(timer)
                                .font(.system(size: 56, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.primary)
                            Text(entry.phase ?? String(localized: "Focusing"))
                                .font(.title3)
                                .foregroundStyle(.secondary)
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

            VStack(alignment: .leading, spacing: 14) {
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
                if entry.isSessionActive, let mode = entry.focusMode, let timer = entry.timerText {
                    let style = WidgetModeStyle.style(for: mode)
                    HStack(spacing: 12) {
                        Text(style.emoji)
                            .font(.system(size: 40))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(timer)
                                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                .monospacedDigit()
                            Text(entry.phase ?? String(localized: "Focusing"))
                                .foregroundStyle(.secondary)
                            if let task = entry.linkedTaskTitle {
                                Text(task)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        VStack(spacing: 8) {
                            Button(intent: PauseFocusFromWidgetIntent()) {
                                Image(systemName: "pause.fill")
                                    .font(.title3)
                            }
                            .tint(.orange)
                            Button(intent: StopFocusFromWidgetIntent()) {
                                Image(systemName: "stop.fill")
                                    .font(.title3)
                            }
                            .tint(.red)
                        }
                    }
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

                Divider()

                // Mode breakdown
                if !entry.modeMinutes.isEmpty {
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

// MARK: - Lock Screen Accessory Widget

struct FocusWidgetAccessoryCircular: View {
    let entry: FocusWidgetEntry

    var body: some View {
        ZStack {
            if entry.isSessionActive, let progress = entry.progress {
                Gauge(value: progress) { EmptyView() }
                    .gaugeStyle(.accessoryCircularCapacity)
            }
            Image(systemName: "brain.head.profile")
                .font(.caption)
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
                if entry.isSessionActive, let timer = entry.timerText {
                    Text(timer)
                        .font(.headline)
                        .monospacedDigit()
                } else {
                    Text(formattedMinutes(entry.todayFocusMinutes))
                        .font(.headline)
                }
                Text(String(localized: "today"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
