// FocusWidgetViews.swift
// Pepinillo — Deep Work Companion for Apple
//
// Widget views for all 3 Home Screen sizes and Lock Screen.
// Each size shows the appropriate amount of data with circular progress rings,
// live countdowns, and quick-action buttons.
// Design style: Liquid Glass (Premium, translucent, atmospheric).

import SwiftUI
import WidgetKit

// MARK: - Reusable Progress Ring

private struct WidgetProgressRing<Content: View>: View {
    let progress: Double?
    let modeColor: Color
    let lineWidth: CGFloat
    let isPaused: Bool
    let countsDown: Bool
    let content: Content

    init(
        progress: Double?,
        modeColor: Color,
        lineWidth: CGFloat = 8,
        isPaused: Bool = false,
        countsDown: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.progress = progress
        self.modeColor = modeColor
        self.lineWidth = lineWidth
        self.isPaused = isPaused
        self.countsDown = countsDown
        self.content = content()
    }

    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(modeColor.opacity(0.15), lineWidth: lineWidth)

            // Progress bar. Countdown modes render remaining time, so they start full and empty out.
            if let progress {
                let clamped = min(max(progress, 0), 1)
                let visibleProgress = countsDown ? 1 - clamped : clamped
                Circle()
                    .trim(from: 0, to: CGFloat(visibleProgress))
                    .stroke(
                        modeColor,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 1.0), value: visibleProgress)
            }

            content
        }
    }
}

// MARK: - Live Timer Text

private struct LiveTimerText: View {
    let entry: FocusWidgetEntry
    let font: Font

    var body: some View {
        if let start = entry.timerStart, let end = entry.timerEnd, !entry.isPaused {
            // Live countdown via system — updates every second without timeline refresh.
            Text(timerInterval: start...end, countsDown: true)
                .font(font)
                .monospacedDigit()
                .multilineTextAlignment(.center)
        } else if let start = entry.timerStart, isCountUpMode, !entry.isPaused {
            Text(timerInterval: start...Date.distantFuture, countsDown: false)
                .font(font)
                .monospacedDigit()
                .multilineTextAlignment(.center)
        } else if let timer = entry.timerText {
            Text(timer)
                .font(font)
                .monospacedDigit()
        }
    }

    private var isCountUpMode: Bool {
        entry.focusMode == "flowtime" || entry.focusMode == "stopwatch"
    }
}

// MARK: - Mode Quick Starts

private let widgetSelectableModes = ["pomodoro", "flowtime", "timeBlock", "stopwatch"]

private struct WidgetModeQuickStartButton: View {
    let mode: String
    let selectedMode: String
    let showsTitle: Bool

    @ViewBuilder
    var body: some View {
        let color = ModeColors.color(for: mode)
        if mode == selectedMode {
            Button(intent: StartFocusFromWidgetIntent(modeID: mode)) {
                label
            }
            .tint(color)
            .buttonStyle(.borderedProminent)
            .clipShape(Capsule())
        } else {
            Button(intent: StartFocusFromWidgetIntent(modeID: mode)) {
                label
            }
            .tint(.secondary)
            .buttonStyle(.bordered)
            .clipShape(Capsule())
        }
    }

    private var label: some View {
        let style = WidgetModeStyle.style(for: mode)
        return HStack(spacing: 5) {
            Image(systemName: showsTitle ? "play.fill" : style.systemImage)
                .font(.system(size: showsTitle ? 10 : 13, weight: .bold))
            if showsTitle {
                Text(modeDisplayName(mode))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            } else {
                Image(systemName: "play.fill")
                    .font(.system(size: 7, weight: .black))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: showsTitle ? 28 : 24)
    }
}

private struct WidgetModeQuickStartGrid: View {
    let selectedMode: String
    let showsTitles: Bool

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)],
            spacing: 6
        ) {
            ForEach(widgetSelectableModes, id: \.self) { mode in
                WidgetModeQuickStartButton(mode: mode, selectedMode: selectedMode, showsTitle: showsTitles)
            }
        }
    }
}

private struct WidgetPrimaryStartButton: View {
    let mode: String
    let compact: Bool

    var body: some View {
        Button(intent: StartFocusFromWidgetIntent(modeID: mode)) {
            HStack(spacing: 6) {
                Image(systemName: "play.fill")
                Text(compact ? String(localized: "Start") : String(localized: "Start \(modeDisplayName(mode))"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .font(.system(size: compact ? 12 : 14, weight: .bold, design: .rounded))
            .frame(maxWidth: .infinity)
            .frame(height: compact ? 28 : 38)
        }
        .tint(ModeColors.color(for: mode))
        .buttonStyle(.borderedProminent)
        .clipShape(Capsule())
    }
}

// MARK: - Pause/Resume + Stop Controls

private struct WidgetControls: View {
    let entry: FocusWidgetEntry
    let compact: Bool

    var body: some View {
        HStack(spacing: compact ? 10 : 14) {
            if entry.isPaused {
                Button(intent: ResumeFocusFromWidgetIntent()) {
                    Image(systemName: "play.fill")
                        .font(.system(size: compact ? 13 : 16, weight: .bold))
                        .frame(width: buttonSize, height: buttonSize)
                }
                .tint(.green)
                .buttonStyle(.borderedProminent)
                .clipShape(Circle())
            } else {
                Button(intent: PauseFocusFromWidgetIntent()) {
                    Image(systemName: "pause.fill")
                        .font(.system(size: compact ? 13 : 16, weight: .bold))
                        .frame(width: buttonSize, height: buttonSize)
                }
                .tint(.orange)
                .buttonStyle(.borderedProminent)
                .clipShape(Circle())
            }

            Button(intent: StopFocusFromWidgetIntent()) {
                Image(systemName: "stop.fill")
                    .font(.system(size: compact ? 13 : 16, weight: .bold))
                    .frame(width: buttonSize, height: buttonSize)
            }
            .tint(.red)
            .buttonStyle(.borderedProminent)
            .clipShape(Circle())
        }
    }

    private var buttonSize: CGFloat { compact ? 34 : 44 }
}

// MARK: - Small Widget (2x2)

struct FocusWidgetSmall: View {
    let entry: FocusWidgetEntry
    @Environment(\.showsWidgetContainerBackground) var showsBackground

    var body: some View {
        ZStack {
            if entry.isSessionActive, let mode = entry.focusMode {
                let style = WidgetModeStyle.style(for: mode)
                let modeColor = ModeColors.color(for: mode)

                VStack(spacing: 6) {
                    WidgetProgressRing(
                        progress: entry.progress,
                        modeColor: modeColor,
                        lineWidth: 6,
                        isPaused: entry.isPaused,
                        countsDown: isCountdownMode(mode)
                    ) {
                        Text(style.emoji)
                            .font(.title2)
                    }
                    .frame(width: 56, height: 56)

                    LiveTimerText(
                        entry: entry,
                        font: .system(.headline, design: .rounded, weight: .bold)
                    )

                    HStack(spacing: 4) {
                        if entry.isPaused {
                            Text(String(localized: "Paused"))
                                .font(.caption2)
                                .foregroundStyle(.orange)
                                .fontWeight(.medium)
                        } else {
                            Text(entry.phase ?? String(localized: "Focusing"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                let mode = entry.preferredModeID ?? "pomodoro"
                let style = WidgetModeStyle.style(for: mode)
                let modeColor = ModeColors.color(for: mode)

                VStack(spacing: 6) {
                    WidgetProgressRing(progress: 0, modeColor: modeColor, lineWidth: 6, countsDown: isCountdownMode(mode)) {
                        Text(style.emoji)
                            .font(.title2)
                    }
                    .frame(width: 56, height: 56)

                    Text(entry.preferredTimerText)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .monospacedDigit()

                    Text(modeDisplayName(mode))
                        .font(.caption2)
                        .foregroundStyle(modeColor)
                        .fontWeight(.medium)

                    WidgetPrimaryStartButton(mode: mode, compact: true)

                    WidgetModeQuickStartGrid(selectedMode: mode, showsTitles: false)
                }
                .padding(8)
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
            if entry.isSessionActive, let mode = entry.focusMode {
                liquidActiveLayout(for: mode)
            } else {
                liquidIdleLayout
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func liquidActiveLayout(for mode: String) -> some View {
        let style = WidgetModeStyle.style(for: mode)
        let modeColor = ModeColors.color(for: mode)

        HStack(spacing: 0) {
            // Left: Massive Hero Ring
            ZStack {
                // Background "glow" for Liquid Glass effect
                Circle()
                    .fill(modeColor.opacity(0.15))
                    .blur(radius: 20)
                    .scaleEffect(1.4)
                
                WidgetProgressRing(
                    progress: entry.progress,
                    modeColor: modeColor,
                    lineWidth: 10,
                    isPaused: entry.isPaused,
                    countsDown: isCountdownMode(mode)
                ) {
                    Text(style.emoji)
                        .font(.system(size: 36))
                        .shadow(color: modeColor.opacity(0.3), radius: 4)
                }
            }
            .frame(width: 140)
            .offset(x: -16) // Dramatic asymmetric offset

            VStack(alignment: .leading, spacing: 2) {
                // Header info
                HStack {
                    if entry.isPaused {
                        Label(String(localized: "Paused"), systemImage: "pause.fill")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.orange)
                    } else {
                        Text(entry.phase?.uppercased() ?? String(localized: "FOCUSING"))
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(.secondary)
                            .tracking(1)
                    }
                    
                    Spacer()
                    
                    if let pn = entry.pomodoroNumber, let tp = entry.totalPomodoros {
                        Text("\(pn)/\(tp)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(modeColor.opacity(0.15), in: Capsule())
                            .foregroundStyle(modeColor)
                    }
                }

                // Timer
                LiveTimerText(
                    entry: entry,
                    font: .system(size: 40, weight: .bold, design: .rounded)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.top, -2)

                // Task
                if let task = entry.linkedTaskTitle {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.system(size: 10))
                        Text(task)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                } else {
                    Text(String(localized: "Deep Work Session"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 8)

                // Controls
                WidgetControls(entry: entry, compact: true)
            }
            .padding(.trailing, 16)
            .padding(.vertical, 14)
        }
    }

    @ViewBuilder
    private var liquidIdleLayout: some View {
        let mode = entry.preferredModeID ?? "pomodoro"
        let style = WidgetModeStyle.style(for: mode)
        let modeColor = ModeColors.color(for: mode)

        HStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(modeColor.opacity(0.12))
                    .blur(radius: 20)
                    .scaleEffect(1.35)

                WidgetProgressRing(progress: 0, modeColor: modeColor, lineWidth: 10, countsDown: isCountdownMode(mode)) {
                    Text(style.emoji)
                        .font(.system(size: 36))
                        .shadow(color: modeColor.opacity(0.25), radius: 4)
                }
            }
            .frame(width: 140)
            .offset(x: -16)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(String(localized: "READY"))
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formattedMinutes(entry.todayFocusMinutes))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Text(entry.preferredTimerText)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.8)
                    .padding(.top, -2)

                Text(modeDisplayName(mode))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(modeColor)

                Spacer(minLength: 6)

                WidgetPrimaryStartButton(mode: mode, compact: true)

                WidgetModeQuickStartGrid(selectedMode: mode, showsTitles: false)
            }
            .padding(.trailing, 16)
            .padding(.vertical, 14)
        }
    }
}

// MARK: - Large Widget (4x4)

struct FocusWidgetLarge: View {
    let entry: FocusWidgetEntry
    @Environment(\.showsWidgetContainerBackground) var showsBackground

    var body: some View {
        ZStack {
            if entry.isSessionActive, let mode = entry.focusMode {
                liquidActiveLayout(for: mode)
            } else {
                liquidIdleLayout
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func liquidActiveLayout(for mode: String) -> some View {
        let style = WidgetModeStyle.style(for: mode)
        let modeColor = ModeColors.color(for: mode)

        VStack(spacing: 14) {
            HStack {
                Text(entry.isPaused ? String(localized: "PAUSED") : (entry.phase?.uppercased() ?? String(localized: "FOCUSING")))
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(entry.isPaused ? .orange : .secondary)
                Spacer()
                if let pn = entry.pomodoroNumber, let tp = entry.totalPomodoros {
                    Text("\(pn)/\(tp)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(modeColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(modeColor.opacity(0.14), in: Capsule())
                }
            }

            WidgetProgressRing(
                progress: entry.progress,
                modeColor: modeColor,
                lineWidth: 14,
                isPaused: entry.isPaused,
                countsDown: isCountdownMode(mode)
            ) {
                VStack(spacing: 6) {
                    Text(style.emoji)
                        .font(.system(size: 30))
                    LiveTimerText(
                        entry: entry,
                        font: .system(size: 42, weight: .bold, design: .rounded)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                }
            }
            .frame(width: 188, height: 188)

            if let task = entry.linkedTaskTitle {
                Label(task, systemImage: "link")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            WidgetControls(entry: entry, compact: false)

            if !entry.modeMinutes.isEmpty {
                VStack(spacing: 8) {
                    ForEach(sortedModes.prefix(3), id: \.key) { mode, minutes in
                        ModeBar(mode: mode, minutes: minutes, totalMinutes: entry.todayFocusMinutes)
                    }
                }
                .padding(12)
                .background(.ultraThinMaterial.opacity(0.45), in: RoundedRectangle(cornerRadius: 14))
            }

            Spacer(minLength: 0)
        }
        .padding(18)
    }

    @ViewBuilder
    private var liquidIdleLayout: some View {
        let preferredMode = entry.preferredModeID ?? "pomodoro"
        let style = WidgetModeStyle.style(for: preferredMode)
        let modeColor = ModeColors.color(for: preferredMode)

        VStack(spacing: 18) {
            HStack(spacing: 24) {
                WidgetProgressRing(progress: 0, modeColor: modeColor, lineWidth: 12, countsDown: isCountdownMode(preferredMode)) {
                    Text(style.emoji)
                        .font(.system(size: 40))
                }
                .frame(width: 130, height: 130)

                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "READY"))
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(.secondary)

                    Text(entry.preferredTimerText)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.8)

                    Text(modeDisplayName(preferredMode))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(modeColor)

                    Text(String(localized: "Today: \(formattedMinutes(entry.todayFocusMinutes))"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            WidgetPrimaryStartButton(mode: preferredMode, compact: false)

            WidgetModeQuickStartGrid(selectedMode: preferredMode, showsTitles: true)

            if !entry.modeMinutes.isEmpty {
                VStack(spacing: 8) {
                    ForEach(sortedModes, id: \.key) { mode, minutes in
                        ModeBar(mode: mode, minutes: minutes, totalMinutes: entry.todayFocusMinutes)
                    }
                }
                .padding(14)
                .background(.ultraThinMaterial.opacity(0.3), in: RoundedRectangle(cornerRadius: 20))
            }

            Spacer(minLength: 0)
        }
        .padding(20)
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
            if entry.isSessionActive, let progress = entry.progress, let mode = entry.focusMode {
                Gauge(value: widgetVisibleProgress(progress, mode: mode)) { EmptyView() }
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
private func modeDisplayName(_ mode: String) -> String {
    switch mode {
    case "pomodoro": return String(localized: "Pomodoro")
    case "flowtime": return String(localized: "Flowtime")
    case "timeBlock": return String(localized: "Time Block")
    case "stopwatch": return String(localized: "Stopwatch")
    default: return String(localized: "Focus")
    }
}

private func isCountdownMode(_ mode: String) -> Bool {
    mode == "pomodoro" || mode == "timeBlock"
}

private func widgetVisibleProgress(_ progress: Double, mode: String) -> Double {
    let clamped = min(max(progress, 0), 1)
    return isCountdownMode(mode) ? 1 - clamped : clamped
}

