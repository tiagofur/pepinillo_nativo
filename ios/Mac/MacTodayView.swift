// MacTodayView.swift
// Pepinillo — native macOS Today dashboard

import SwiftUI

struct MacTodayView: View {
    let analytics: AnalyticsFeature.State
    let tasks: TaskListFeature.State
    let onStartFocus: (TaskListFeature.TaskItemState?) -> Void
    let onOpenPlan: () -> Void
    let onRefresh: () -> Void

    @Environment(\.appTheme) private var theme

    private var tasksCompletedToday: Int {
        tasks.tasks.filter { task in
            guard task.isCompleted else { return false }
            if let completedAt = task.completedAt {
                return Calendar.current.isDateInToday(completedAt)
            }
            return task.scheduledForToday
        }.count
    }

    private var nextTask: TaskListFeature.TaskItemState? {
        tasks.tasks
            .filter { $0.scheduledForToday && !$0.isCompleted }
            .sorted {
                if $0.priority != $1.priority {
                    return $0.priority > $1.priority
                }
                return $0.sortOrder < $1.sortOrder
            }
            .first
    }

    private var focusTimeText: String {
        guard analytics.todayFocusMinutes > 0 else {
            return Duration.seconds(0).formatted(.units(allowed: [.minutes], width: .abbreviated))
        }
        return durationText(TimeInterval(analytics.todayFocusMinutes) * 60)
    }

    private var streakText: String {
        analytics.currentStreakDays == 1
            ? String(localized: "1 day streak")
            : String(localized: "\(analytics.currentStreakDays) days streak")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                kpiGrid
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 320), spacing: 24, alignment: .top)],
                    alignment: .leading,
                    spacing: 24
                ) {
                    recentSessionsCard
                    nextFocusCard
                }
            }
            .frame(maxWidth: 980, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(24)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: onRefresh) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh Today")
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day().year())
                    .font(.title2.weight(.semibold))
                Text("Your focus summary for today")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 16)

            HStack(spacing: 14) {
                Label {
                    Text(streakText)
                } icon: {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(theme.streakColor)
                }

                Divider()
                    .frame(height: 18)

                Text("\(focusTimeText) focused")
                    .monospacedDigit()
            }
            .font(.callout.weight(.medium))
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - KPI Grid

    private var kpiGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 150), spacing: 16)],
            alignment: .leading,
            spacing: 16
        ) {
            TodayKPI(
                title: "Focus Time",
                value: focusTimeText,
                systemImage: "clock",
                tint: theme.color(for: .pomodoro)
            )
            TodayKPI(
                title: "Sessions",
                value: analytics.todaySessions.formatted(),
                systemImage: "checkmark.circle",
                tint: theme.color(for: .flowtime)
            )
            TodayKPI(
                title: "Streak",
                value: analytics.currentStreakDays.formatted(),
                systemImage: "flame.fill",
                tint: theme.streakColor
            )
            TodayKPI(
                title: "Tasks Completed",
                value: tasksCompletedToday.formatted(),
                systemImage: "checklist",
                tint: theme.color(for: .timeBlock)
            )
        }
    }

    // MARK: - Recent Sessions

    private var recentSessionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Recent Sessions", systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                Spacer()
                if !analytics.recentSessions.isEmpty {
                    Text("Last 5")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if analytics.recentSessions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No sessions yet")
                        .font(.callout.weight(.medium))
                    Text("Complete a focus session to see it here.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                let sessions = Array(analytics.recentSessions.prefix(5))
                VStack(spacing: 0) {
                    ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                        recentSessionRow(session)
                        if index < sessions.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
    }

    private func recentSessionRow(_ session: SessionRecordDTO) -> some View {
        let mode = FocusMode(rawValue: session.mode)
        let color = mode.map { theme.color(for: $0) } ?? Color.accentColor
        let taskTitle = linkedTaskTitle(for: session)

        return HStack(spacing: 12) {
            Image(systemName: mode?.systemImage ?? "timer")
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(color)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(mode?.macDisplayName ?? session.mode)
                        .font(.body.weight(.medium))
                    Text("·")
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                    Text(durationText(session.actualDuration))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                HStack(spacing: 6) {
                    Text(session.startedAt, format: .dateTime.hour().minute())
                    if let taskTitle {
                        Text("·")
                            .accessibilityHidden(true)
                        Text(taskTitle)
                            .lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if !session.wasCompleted {
                Text("Stopped")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    private func linkedTaskTitle(for session: SessionRecordDTO) -> String? {
        guard let taskID = session.taskID else { return nil }
        return tasks.tasks[id: taskID]?.title
    }

    // MARK: - Next Focus

    private var nextFocusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Next Focus", systemImage: "play.circle")
                .font(.headline)

            if let nextTask {
                HStack(spacing: 10) {
                    Image(systemName: nextTask.energyLevel.icon)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(nextTask.energyLevel.color)
                        .font(.title3)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(nextTask.title)
                            .font(.body.weight(.medium))
                            .lineLimit(2)
                        Text("Pomodoros: \(nextTask.estimatedPomodoros)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No task scheduled for today")
                        .font(.body.weight(.medium))
                    Text("Start a free session or choose a task in Plan.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                onStartFocus(nextTask)
            } label: {
                Label("Start Next Focus", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if nextTask == nil {
                Button("Open Plan", action: onOpenPlan)
                    .buttonStyle(.link)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
    }

    // MARK: - Formatting

    private func durationText(_ seconds: TimeInterval) -> String {
        let value = Duration.seconds(max(0, seconds))
        if seconds < 60 {
            return value.formatted(.units(allowed: [.seconds], width: .abbreviated))
        }
        return value.formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }
}

private struct TodayKPI: View {
    let title: LocalizedStringKey
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)

            Text(value)
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
        .accessibilityElement(children: .combine)
    }
}
