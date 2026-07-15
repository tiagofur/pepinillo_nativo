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
                    cards
                }
                .padding(.vertical, 8)
            }
            .scrollBounceBehavior(.basedOnSize)
            .primaryScrollEdgeEffect()
        case .grid:
            LazyVGrid(columns: adaptiveCardColumns, spacing: 16) {
                cards
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Shared cards (reused by both layout modes)

    @ViewBuilder
    private var cards: some View {
        activeTaskCard
        soundscapeCard
        todaySessionsCard
        streakCard
        if let next = nextScheduledTask {
            nextTaskCard(next)
        }
    }

    // MARK: - Active Task Card

    private var activeTaskCard: some View {
        Button {
            store.send(.taskPickerTapped)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                Label(String(localized: "Active Task"), systemImage: "checkmark.circle")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    activeTaskIcon

                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.linkedTaskTitle ?? String(localized: "Pick a task to focus on"))
                            .font((store.linkedTaskTitle == nil ? Font.subheadline : Font.body.weight(.medium)))
                            .foregroundStyle(store.linkedTaskTitle == nil ? .secondary : .primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        if store.linkedTaskTitle != nil {
                            Text(String(localized: "Tap to change or unlink"))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Spacer(minLength: 12)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(RoundedRectangle(cornerRadius: GlassCornerRadius.card, style: .continuous))
        .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Active task: \(store.linkedTaskTitle ?? "none")"))
        .accessibilityHint(String(localized: "Double tap to change or unlink the task"))
    }

    @ViewBuilder
    private var activeTaskIcon: some View {
        if let icon = store.linkedTaskIcon {
            Image(systemName: icon)
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
        } else {
            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
        }
    }

    // MARK: - Soundscape Card

    private var soundscapeCard: some View {
        Button {
            store.send(.soundscapePickerTapped)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: store.selectedSoundscape.systemImage)
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)

                VStack(alignment: .leading, spacing: 2) {
                    Label(String(localized: "Sounds"), systemImage: "speaker.wave.2")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(store.selectedSoundscape == .none
                         ? String(localized: "Choose focus audio")
                         : store.selectedSoundscape.displayName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(store.selectedSoundscape == .none ? .secondary : .primary)
                }

                Spacer(minLength: 12)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(RoundedRectangle(cornerRadius: GlassCornerRadius.card, style: .continuous))
        .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Sounds: \(store.selectedSoundscape == .none ? "none" : store.selectedSoundscape.displayName)"))
        .accessibilityHint(String(localized: "Double tap to choose focus audio"))
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
                    Spacer(minLength: 0)
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Today: \(sessionsToday) \(sessionsToday == 1 ? "session" : "sessions"), \(totalFocusMinutesToday) minutes"))
    }

    // MARK: - Streak Card

    private var streakCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "flame.fill")
                .font(.largeTitle)
                .foregroundStyle(theme.streakColor)
                .contentTransition(.symbolEffect(.replace))

            VStack(alignment: .leading, spacing: 2) {
                Text("\(streakDays)")
                    .font(NumericFont.heroStat())
                    .foregroundStyle(.primary)
                Text(streakDays == 1
                     ? String(localized: "day streak")
                     : String(localized: "days streak"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "\(streakDays) \(streakDays == 1 ? "day streak" : "days streak")"))
    }

    // MARK: - Next Scheduled Task Card

    private func nextTaskCard(_ task: TaskListFeature.TaskItemState) -> some View {
        Button {
            store.send(.linkTask(task.id, task.title, task.energyLevel.icon))
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                Label(String(localized: "Up Next"), systemImage: "arrow.right.circle")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Image(systemName: task.energyLevel.icon)
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(task.energyLevel.color)
                    Text(task.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Spacer(minLength: 12)
                    Image(systemName: "link")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(RoundedRectangle(cornerRadius: GlassCornerRadius.card, style: .continuous))
        .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Up next: \(task.title)"))
        .accessibilityHint(String(localized: "Double tap to link this task to your session"))
    }
}
