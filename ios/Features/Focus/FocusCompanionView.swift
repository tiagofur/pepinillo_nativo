// FocusCompanionView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Trailing companion pane shown beside the timer ring on iPad (regular width).
// Displays: active task card, today's sessions summary, streak, and next scheduled task.
// Receives data via lightweight props — no additional store coupling needed.

import SwiftUI
import ComposableArchitecture

struct FocusCompanionView: View {

    // MARK: - Layout

    enum Layout { case stack, grid }

    // MARK: - Props

    @Bindable var store: StoreOf<FocusFeature>
    let streakDays: Int
    let sessionsToday: Int
    let totalFocusMinutesToday: Int
    var layout: Layout = .stack

    @Environment(\.appTheme) private var theme

    private var scheduledTasks: [TaskListFeature.TaskItemState] {
        store.availableTasks.filter { !$0.isCompleted && $0.scheduledForToday }
    }

    private var nextScheduledTask: TaskListFeature.TaskItemState? {
        scheduledTasks.first { $0.id != store.linkedTaskID }
    }

    var body: some View {
        switch layout {
        case .stack:
            ScrollView {
                VStack(spacing: 16) {
                    if !store.isRunning && store.selectedMode == .timeBlock {
                        durationControlRow
                            .transition(.opacity)
                    }
                    cards
                }
                .padding(.vertical, 8)
            }
            .scrollBounceBehavior(.basedOnSize)
        case .grid:
            LazyVGrid(columns: adaptiveCardColumns, spacing: 16) {
                if !store.isRunning && store.selectedMode == .timeBlock {
                    durationControlRow
                        .transition(.opacity)
                }
                cards
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Duration Control Row (Time Block, iPad only — mirrors FocusView.durationPicker)

    @ViewBuilder
    private var durationControlRow: some View {
        HStack {
            Label(String(localized: "Duration:"), systemImage: "timer")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer()

            Stepper(
                "\(store.customDurationMinutes) min",
                value: Binding(
                    get: { store.customDurationMinutes },
                    set: { store.send(.customDurationChanged($0)) }
                ),
                in: 5...480,
                step: 5
            )
            .font(.subheadline)
        }
        .padding(16)
        .background(.regularMaterial, in: .rect(cornerRadius: 20))
    }

    // MARK: - Shared cards (reused by both layout modes)

    @ViewBuilder
    private var cards: some View {
        activeTaskCard
        todaySessionsCard
        streakCard
        if let next = nextScheduledTask {
            nextTaskCard(next)
        }
    }

    // MARK: - Active Task Card

    private var activeTaskCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(String(localized: "Active Task"), systemImage: "checkmark.circle")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            if let title = store.linkedTaskTitle {
                Button {
                    store.send(.taskPickerTapped)
                } label: {
                    HStack(spacing: 10) {
                        if let emoji = store.linkedTaskEmoji {
                            Text(emoji)
                                .font(.title2)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(Color.accentColor)
                        }
                        Text(title)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    store.send(.taskPickerTapped)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.accentColor)
                        Text(String(localized: "Pick a task to focus on"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: .rect(cornerRadius: 20))
    }

    // MARK: - Today Sessions Card

    private var todaySessionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(String(localized: "Today"), systemImage: "calendar")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            if sessionsToday == 0 {
                HStack(spacing: 10) {
                    Image(systemName: "moon.zzz")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text(String(localized: "No sessions yet today"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(sessionsToday)")
                            .font(.system(.title, design: .rounded, weight: .bold))
                            .foregroundStyle(.primary)
                        Text(sessionsToday == 1
                             ? String(localized: "session")
                             : String(localized: "sessions"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if totalFocusMinutesToday > 0 {
                        Divider()
                            .frame(height: 36)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(totalFocusMinutesToday)")
                                .font(.system(.title, design: .rounded, weight: .bold))
                                .foregroundStyle(.primary)
                            Text(String(localized: "minutes"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: .rect(cornerRadius: 20))
    }

    // MARK: - Streak Card

    private var streakCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "flame.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)
                .symbolEffect(.bounce, value: streakDays)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(streakDays)")
                    .font(NumericFont.heroStat(size: 28))
                    .foregroundStyle(.primary)
                Text(streakDays == 1
                     ? String(localized: "day streak")
                     : String(localized: "day streak"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(.regularMaterial, in: .rect(cornerRadius: 20))
    }

    // MARK: - Next Scheduled Task Card

    private func nextTaskCard(_ task: TaskListFeature.TaskItemState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(String(localized: "Up Next"), systemImage: "arrow.right.circle")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Text(task.energyLevel.emoji)
                    .font(.title2)
                Text(task.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Spacer()
            }
        }
        .padding(16)
        .background(.regularMaterial, in: .rect(cornerRadius: 20))
    }
}
