// FocusWidgetViews.swift
// Pepinillo — Deep Work Companion for Apple
//
// Widget views for all 3 Home Screen sizes and Lock Screen.
// Each size shows the appropriate amount of data with circular progress rings,
// live countdowns, and quick-action buttons.
// Design style: Liquid Glass (Premium, translucent, atmospheric).

import SwiftUI
import WidgetKit

// MARK: - Tinted Rendering Helpers

/// Returns the appropriate colour for a focus mode element, respecting the widget rendering mode.
/// In `.accented` (tinted) mode all colours collapse to the system tint, so we switch to
/// `.primary`/`.secondary` via a sentinel `.clear` that callers swap for the desired semantic.
private func modeAccentColor(_ mode: String, renderingMode: WidgetRenderingMode) -> Color {
    renderingMode == .accented ? .primary : ModeColors.color(for: mode)
}

// MARK: - Reusable Progress Ring

private struct WidgetProgressRing<Content: View>: View {
    let progress: Double?
    let modeColor: Color
    let lineWidth: CGFloat
    let isPaused: Bool
    let countsDown: Bool
    let timerStart: Date?
    let timerEnd: Date?
    let content: Content

    init(
        progress: Double?,
        modeColor: Color,
        lineWidth: CGFloat = 8,
        isPaused: Bool = false,
        countsDown: Bool = false,
        timerStart: Date? = nil,
        timerEnd: Date? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.progress = progress
        self.modeColor = modeColor
        self.lineWidth = lineWidth
        self.isPaused = isPaused
        self.countsDown = countsDown
        self.timerStart = timerStart
        self.timerEnd = timerEnd
        self.content = content()
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(modeColor.opacity(0.15), lineWidth: lineWidth)

            if let start = timerStart, let end = timerEnd, !isPaused {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    ringStroke(visibleProgress: liveVisibleProgress(at: context.date, start: start, end: end))
                }
            } else if let progress {
                ringStroke(visibleProgress: visibleProgress(from: progress))
            }

            content
        }
    }

    private func ringStroke(visibleProgress: Double) -> some View {
        Circle()
            .trim(from: 0, to: CGFloat(min(max(visibleProgress, 0), 1)))
            .stroke(
                modeColor,
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
    }

    private func visibleProgress(from progress: Double) -> Double {
        let clamped = min(max(progress, 0), 1)
        return countsDown ? 1 - clamped : clamped
    }

    private func liveVisibleProgress(at date: Date, start: Date, end: Date) -> Double {
        let duration = max(end.timeIntervalSince(start), 1)
        let completed = min(max(date.timeIntervalSince(start) / duration, 0), 1)
        return countsDown ? 1 - completed : completed
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
    let isProUser: Bool
    var renderingMode: WidgetRenderingMode = .fullColor

    @ViewBuilder
    var body: some View {
        let isProMode = (mode == "flowtime" || mode == "timeBlock")
        let isLocked = isProMode && !isProUser
        let color = modeAccentColor(mode, renderingMode: renderingMode)

        if isLocked {
            label(isLocked: true)
                .foregroundStyle(.secondary)
                .background(.secondary.opacity(0.10), in: Capsule())
        } else if mode == selectedMode {
            Button(intent: SelectFocusModeFromWidgetIntent(modeID: mode)) {
                label(isLocked: false)
            }
            .buttonStyle(.plain)
            .foregroundStyle(renderingMode == .accented ? AnyShapeStyle(.primary) : AnyShapeStyle(Color.white))
            .widgetAccentable(renderingMode == .accented)
            .background(renderingMode == .accented ? AnyShapeStyle(.secondary.opacity(0.20)) : AnyShapeStyle(color), in: Capsule())
        } else {
            Button(intent: SelectFocusModeFromWidgetIntent(modeID: mode)) {
                label(isLocked: false)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .background(.secondary.opacity(0.10), in: Capsule())
        }
    }

    private func label(isLocked: Bool) -> some View {
        let style = WidgetModeStyle.style(for: mode)
        return HStack(spacing: 5) {
            Image(systemName: isLocked ? "lock.fill" : style.systemImage)
                .font(.system(size: 11, weight: .bold))
            if showsTitle {
                Text(modeDisplayName(mode))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: showsTitle ? 26 : 22)
    }
}

private struct WidgetModeIconStartRow: View {
    let selectedMode: String
    let isProUser: Bool
    var renderingMode: WidgetRenderingMode = .fullColor

    var body: some View {
        HStack(spacing: 6) {
            ForEach(widgetSelectableModes, id: \.self) { mode in
                let style = WidgetModeStyle.style(for: mode)
                let color = modeAccentColor(mode, renderingMode: renderingMode)
                let isProMode = (mode == "flowtime" || mode == "timeBlock")
                let isLocked = isProMode && !isProUser
                let isSelected = mode == selectedMode

                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                        .background(.secondary.opacity(0.10), in: Capsule())
                } else {
                    Button(intent: SelectFocusModeFromWidgetIntent(modeID: mode)) {
                        Image(systemName: style.systemImage)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(
                                renderingMode == .accented
                                    ? (isSelected ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                                    : (isSelected ? AnyShapeStyle(Color.white) : AnyShapeStyle(color))
                            )
                            .frame(maxWidth: .infinity)
                            .frame(height: 24)
                            .background(
                                renderingMode == .accented
                                    ? (isSelected ? AnyShapeStyle(Color.secondary.opacity(0.25)) : AnyShapeStyle(Color.secondary.opacity(0.10)))
                                    : (isSelected ? AnyShapeStyle(color) : AnyShapeStyle(color.opacity(0.12))),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                    .widgetAccentable(renderingMode == .accented && isSelected)
                }
            }
        }
    }
}

private struct WidgetModeQuickStartGrid: View {
    let selectedMode: String
    let showsTitles: Bool
    let isProUser: Bool
    var renderingMode: WidgetRenderingMode = .fullColor

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)],
            spacing: 6
        ) {
            ForEach(widgetSelectableModes, id: \.self) { mode in
                WidgetModeQuickStartButton(
                    mode: mode,
                    selectedMode: selectedMode,
                    showsTitle: showsTitles,
                    isProUser: isProUser,
                    renderingMode: renderingMode
                )
            }
        }
    }
}

private struct WidgetPrimaryStartButton: View {
    let mode: String
    let compact: Bool
    let isProUser: Bool
    var renderingMode: WidgetRenderingMode = .fullColor

    @ViewBuilder
    var body: some View {
        let isProMode = (mode == "flowtime" || mode == "timeBlock")
        let isLocked = isProMode && !isProUser

        if isLocked {
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                Text(String(localized: "Pepinillo+"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .font(.system(size: compact ? 12 : 14, weight: .bold, design: .rounded))
            .frame(maxWidth: .infinity)
            .frame(height: compact ? 28 : 38)
            .foregroundStyle(.secondary)
            .background(.secondary.opacity(0.12), in: Capsule())
        } else {
            Button(intent: StartFocusFromWidgetIntent(modeID: mode)) {
                let modeColor = modeAccentColor(mode, renderingMode: renderingMode)
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                    Text(compact ? String(localized: "Start") : String(localized: "Start \(modeDisplayName(mode))"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .font(.system(size: compact ? 12 : 14, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: compact ? 28 : 38)
                .foregroundStyle(renderingMode == .accented ? AnyShapeStyle(.primary) : AnyShapeStyle(Color.white))
                .background(
                    renderingMode == .accented ? AnyShapeStyle(Color.secondary.opacity(0.20)) : AnyShapeStyle(modeColor.gradient),
                    in: Capsule()
                )
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .widgetAccentable(renderingMode == .accented)
        }
    }
}

// MARK: - Pause/Resume + Stop Controls

private struct WidgetMetric: View {
    let icon: String
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: -1) {
                Text("\(value)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(label)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

private struct WidgetControls: View {
    let entry: FocusWidgetEntry
    let compact: Bool

    var body: some View {
        HStack(spacing: compact ? 10 : 14) {
            // Hide pause/resume during the "waiting for next phase" hold.
            // The engine has no running timer then, so these controls are meaningless.
            if !entry.isWaiting {
                if entry.isPaused {
                    Button(intent: ResumeFocusFromWidgetIntent()) {
                        controlIcon("play.fill", color: .green)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Circle())
                } else {
                    Button(intent: PauseFocusFromWidgetIntent()) {
                        controlIcon("pause.fill", color: .orange)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Circle())
                }
            }

            Button(intent: StopFocusFromWidgetIntent()) {
                controlIcon("stop.fill", color: .red)
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
        }
    }

    private var buttonSize: CGFloat { compact ? 36 : 44 }

    private func controlIcon(_ systemName: String, color: Color) -> some View {
        ZStack {
            Circle()
                .fill(color)
            Image(systemName: systemName)
                .font(.system(size: compact ? 13 : 16, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: buttonSize, height: buttonSize)
        .shadow(color: color.opacity(0.18), radius: 6, y: 3)
    }
}

// MARK: - Small Widget (2x2)

struct FocusWidgetSmall: View {
    let entry: FocusWidgetEntry
    @Environment(\.showsWidgetContainerBackground) var showsBackground
    @Environment(\.widgetRenderingMode) var renderingMode

    var body: some View {
        ZStack {
            if entry.isSessionActive, let mode = entry.focusMode {
                let style = WidgetModeStyle.style(for: mode)
                let modeColor = modeAccentColor(mode, renderingMode: renderingMode)

                VStack(spacing: 6) {
                    WidgetProgressRing(
                        progress: entry.progress,
                        modeColor: modeColor,
                        lineWidth: 6,
                        isPaused: entry.isPaused,
                        countsDown: isCountdownMode(mode),
                        timerStart: entry.timerStart,
                        timerEnd: entry.timerEnd
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
                        WidgetControls(entry: entry, compact: true)
                    }
                }
            } else {
                let mode = entry.preferredModeID ?? "pomodoro"
                let style = WidgetModeStyle.style(for: mode)
                let modeColor = modeAccentColor(mode, renderingMode: renderingMode)

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
                        .foregroundStyle(renderingMode == .accented ? .secondary : modeColor)
                        .fontWeight(.medium)

                    WidgetPrimaryStartButton(mode: mode, compact: true, isProUser: entry.isProUser, renderingMode: renderingMode)
                }
                .padding(0)
            }
        }
    }
}

// MARK: - Medium Widget (4x2)

struct FocusWidgetMedium: View {
    let entry: FocusWidgetEntry
    @Environment(\.showsWidgetContainerBackground) var showsBackground
    @Environment(\.widgetRenderingMode) var renderingMode

    var body: some View {
        ZStack {
            if entry.isSessionActive, let mode = entry.focusMode {
                liquidActiveLayout(for: mode)
            } else {
                liquidIdleLayout
            }
        }
    }

    @ViewBuilder
    private func liquidActiveLayout(for mode: String) -> some View {
        let style = WidgetModeStyle.style(for: mode)
        let modeColor = modeAccentColor(mode, renderingMode: renderingMode)
        let taskTitle = entry.linkedTaskTitle ?? String(localized: "No task linked")

        HStack(alignment: .center, spacing: 18) {
            ZStack {
                Circle()
                    .fill(modeColor.opacity(0.08))
                    .blur(radius: 10)
                    .scaleEffect(1.08)

                WidgetProgressRing(
                    progress: entry.progress,
                    modeColor: modeColor,
                    lineWidth: 9,
                    isPaused: entry.isPaused,
                    countsDown: isCountdownMode(mode),
                    timerStart: entry.timerStart,
                    timerEnd: entry.timerEnd
                ) {
                    VStack(spacing: 5) {
                        Text(style.emoji)
                            .font(.system(size: 22))
                            .shadow(color: modeColor.opacity(0.22), radius: 3)
                        LiveTimerText(
                            entry: entry,
                            font: .system(size: 25, weight: .bold, design: .rounded)
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    }
                }
            }
            .frame(width: 118, height: 118)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(taskTitle)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(entry.linkedTaskTitle == nil ? .secondary : .primary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)
                    }

                    Spacer(minLength: 8)

                    if let pn = entry.pomodoroNumber, let tp = entry.totalPomodoros {
                        Text("\(pn)/\(tp)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(modeColor.opacity(renderingMode == .accented ? 0.20 : 0.16), in: Capsule())
                            .foregroundStyle(renderingMode == .accented ? .primary : modeColor)
                            .widgetAccentable(renderingMode == .accented)
                    }
                }

                WidgetControls(entry: entry, compact: false)
                    .padding(.top, -1)

                HStack(spacing: 18) {
                    // S2: the streak row renders only when enabled in widget settings.
                    if entry.showStreak {
                        WidgetMetric(icon: "flame.fill", value: entry.currentStreakDays, label: String(localized: "streak"), color: renderingMode == .accented ? .primary : ModeColors.streak)
                    }
                    WidgetMetric(icon: "checkmark.circle.fill", value: entry.todaySessionsCompleted, label: String(localized: "sessions"), color: .secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(0)
    }

    @ViewBuilder
    private var liquidIdleLayout: some View {
        let mode = entry.preferredModeID ?? "pomodoro"
        let style = WidgetModeStyle.style(for: mode)
        let modeColor = modeAccentColor(mode, renderingMode: renderingMode)

        HStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(modeColor.opacity(renderingMode == .accented ? 0.08 : 0.12))
                    .blur(radius: 20)
                    .scaleEffect(1.35)

                WidgetProgressRing(progress: 0, modeColor: modeColor, lineWidth: 10, countsDown: isCountdownMode(mode)) {
                    Text(style.emoji)
                        .font(.system(size: 36))
                        .shadow(color: modeColor.opacity(renderingMode == .accented ? 0.10 : 0.25), radius: 4)
                }
            }
            .frame(width: 140)
            .offset(x: -16)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(String(localized: "Ready"))
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
                    .foregroundStyle(renderingMode == .accented ? .secondary : modeColor)

                Spacer(minLength: 6)

                WidgetPrimaryStartButton(mode: mode, compact: true, isProUser: entry.isProUser, renderingMode: renderingMode)

                WidgetModeIconStartRow(selectedMode: mode, isProUser: entry.isProUser, renderingMode: renderingMode)
            }
            .padding(0)
        }
    }
}

// MARK: - Large Widget (4x4)

struct FocusWidgetLarge: View {
    let entry: FocusWidgetEntry
    @Environment(\.showsWidgetContainerBackground) var showsBackground
    @Environment(\.widgetRenderingMode) var renderingMode

    var body: some View {
        ZStack {
            if entry.isSessionActive, let mode = entry.focusMode {
                liquidActiveLayout(for: mode)
            } else {
                liquidIdleLayout
            }
        }
    }

    @ViewBuilder
    private func liquidActiveLayout(for mode: String) -> some View {
        let style = WidgetModeStyle.style(for: mode)
        let modeColor = modeAccentColor(mode, renderingMode: renderingMode)

        VStack(spacing: 14) {
            HStack {
                Text(entry.isWaiting ? (entry.phase ?? String(localized: "Waiting")) : (entry.isPaused ? String(localized: "Paused") : (entry.phase ?? String(localized: "Focusing"))))
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(renderingMode == .accented ? Color.secondary : (entry.isPaused ? Color.orange : Color.secondary))
                Spacer()
                if let pn = entry.pomodoroNumber, let tp = entry.totalPomodoros {
                    Text("\(pn)/\(tp)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(renderingMode == .accented ? .primary : modeColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(modeColor.opacity(renderingMode == .accented ? 0.20 : 0.14), in: Capsule())
                        .widgetAccentable(renderingMode == .accented)
                }
            }

            WidgetProgressRing(
                progress: entry.progress,
                modeColor: modeColor,
                lineWidth: 14,
                isPaused: entry.isPaused,
                countsDown: isCountdownMode(mode),
                timerStart: entry.timerStart,
                timerEnd: entry.timerEnd
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

            // S2: honors the widget's Show Mode Breakdown toggle.
            if entry.showModeBreakdown, !entry.modeMinutes.isEmpty {
                VStack(spacing: 8) {
                    ForEach(sortedModes.prefix(3), id: \.key) { mode, minutes in
                        ModeBar(mode: mode, minutes: minutes, totalMinutes: entry.todayFocusMinutes, renderingMode: renderingMode)
                    }
                }
                .padding(12)
                .pepinilloGlass(cornerRadius: 14)
            }
        }
        .padding(0)
    }

    @ViewBuilder
    private var liquidIdleLayout: some View {
        let preferredMode = entry.preferredModeID ?? "pomodoro"
        let style = WidgetModeStyle.style(for: preferredMode)
        let modeColor = modeAccentColor(preferredMode, renderingMode: renderingMode)

        VStack(spacing: 18) {
            HStack(spacing: 24) {
                WidgetProgressRing(progress: 0, modeColor: modeColor, lineWidth: 12, countsDown: isCountdownMode(preferredMode)) {
                    Text(style.emoji)
                        .font(.system(size: 40))
                }
                .frame(width: 130, height: 130)

                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Ready"))
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(.secondary)

                    Text(entry.preferredTimerText)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.8)

                    Text(modeDisplayName(preferredMode))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(renderingMode == .accented ? .secondary : modeColor)

                    Text(String(localized: "Today: \(formattedMinutes(entry.todayFocusMinutes))"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            WidgetPrimaryStartButton(mode: preferredMode, compact: false, isProUser: entry.isProUser, renderingMode: renderingMode)

            WidgetModeQuickStartGrid(selectedMode: preferredMode, showsTitles: true, isProUser: entry.isProUser, renderingMode: renderingMode)

            // S2: honors the widget's Show Mode Breakdown toggle.
            if entry.showModeBreakdown, !entry.modeMinutes.isEmpty {
                VStack(spacing: 8) {
                    ForEach(sortedModes, id: \.key) { mode, minutes in
                        ModeBar(mode: mode, minutes: minutes, totalMinutes: entry.todayFocusMinutes, renderingMode: renderingMode)
                    }
                }
                .padding(14)
                .pepinilloGlass(cornerRadius: 20)
            }

            Spacer(minLength: 0)
        }
        .padding(0)
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
            if entry.isSessionActive && entry.isWaiting {
                Image(systemName: "hourglass")
                    .font(.caption2)
            } else if entry.isSessionActive && entry.isPaused {
                Image(systemName: "pause.fill")
                    .font(.caption2)
            } else {
                Image(systemName: WidgetModeStyle.style(for: entry.focusMode ?? entry.preferredModeID ?? "pomodoro").systemImage)
                    .font(.caption)
            }
        }
    }
}

struct FocusWidgetAccessoryRectangular: View {
    let entry: FocusWidgetEntry

    var body: some View {
        HStack {
            Image(systemName: WidgetModeStyle.style(for: entry.focusMode ?? entry.preferredModeID ?? "pomodoro").systemImage)
                .font(.subheadline)

            VStack(alignment: .leading, spacing: 2) {
                if entry.isSessionActive {
                    if entry.isWaiting {
                        Text(entry.phase ?? String(localized: "Waiting"))
                            .font(.headline)
                        Text(String(localized: "Waiting"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if entry.isPaused {
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
                    } else if let start = entry.timerStart {
                        Text(timerInterval: start...Date.distantFuture, countsDown: false)
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
    var renderingMode: WidgetRenderingMode = .fullColor

    /// Index within [pomodoro, flowtime, timeBlock, stopwatch] for opacity differentiation.
    private static let modeOrder = ["pomodoro", "flowtime", "timeBlock", "stopwatch"]
    private var modeIndex: Int { Self.modeOrder.firstIndex(of: mode) ?? 0 }

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
                        .fill(barColor)
                        .widgetAccentable(renderingMode == .accented)
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

    private var barColor: Color {
        if renderingMode == .accented {
            // Use opacity levels to distinguish modes under a single tint.
            let opacities: [Double] = [1.0, 0.65, 0.40, 0.20]
            let opacity = opacities[min(modeIndex, opacities.count - 1)]
            return Color.primary.opacity(opacity)
        }
        return ModeColors.color(for: mode)
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
