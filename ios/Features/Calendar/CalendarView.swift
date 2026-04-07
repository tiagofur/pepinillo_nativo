// CalendarView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Monthly calendar view with focus activity indicators and day detail panel.

import SwiftUI
import ComposableArchitecture

struct CalendarView: View {
    @Bindable var store: StoreOf<CalendarFeature>
    @Environment(\.appTheme) private var theme

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let calendar = Calendar.current

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                monthHeader
                calendarGrid
                if let detail = store.selectedDayDetail {
                    dayDetailCard(detail)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .navigationTitle(String(localized: "Calendar"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.send(.onAppear) }
        .conditionalAnimation(.easeInOut(duration: 0.25), value: store.selectedDate)
    }

    // MARK: - Month Header

    private var monthHeader: some View {
        HStack {
            Button {
                if let prev = calendar.date(byAdding: .month, value: -1, to: store.displayedMonth) {
                    store.send(.monthChanged(prev))
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Text(monthYearString(from: store.displayedMonth))
                .font(.title3.weight(.bold))

            Spacer()

            Button {
                if let next = calendar.date(byAdding: .month, value: 1, to: store.displayedMonth) {
                    store.send(.monthChanged(next))
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        VStack(spacing: 8) {
            // Weekday headers
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(orderedWeekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day cells
            LazyVGrid(columns: columns, spacing: 6) {
                // Leading empty cells
                ForEach(0..<leadingEmptyCells, id: \.self) { _ in
                    Color.clear.frame(height: 44)
                }

                // Day cells
                ForEach(daysInMonth, id: \.self) { date in
                    dayCell(for: date)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func dayCell(for date: Date) -> some View {
        let day = calendar.component(.day, from: date)
        let isToday = calendar.isDateInToday(date)
        let isSelected = store.selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        let hasActivity = store.activityDays.contains(
            calendar.dateComponents([.year, .month, .day], from: date)
        )
        let isFuture = date > Date.now

        return Button {
            store.send(.daySelected(date))
        } label: {
            VStack(spacing: 4) {
                Text("\(day)")
                    .font(.system(.body, design: .rounded, weight: isToday ? .bold : .regular))
                    .foregroundStyle(
                        isSelected ? AnyShapeStyle(.white) :
                        isFuture ? AnyShapeStyle(.tertiary) :
                        isToday ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.primary)
                    )
                    .frame(width: 34, height: 34)
                    .background {
                        if isSelected {
                            Circle().fill(Color.accentColor)
                        } else if isToday {
                            Circle().stroke(Color.accentColor, lineWidth: 1.5)
                        }
                    }

                Circle()
                    .fill(hasActivity && !isSelected ? Color.accentColor : .clear)
                    .frame(width: 5, height: 5)
            }
            .frame(height: 44)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Day Detail Card

    private func dayDetailCard(_ detail: CalendarFeature.State.DayDetail) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Date header
            Text(fullDateString(from: detail.date))
                .font(.headline)

            // Summary row
            if detail.sessionsCompleted > 0 || !detail.tasks.isEmpty {
                HStack(spacing: 0) {
                    summaryItem(
                        icon: "brain.head.profile",
                        value: "\(detail.totalFocusMinutes)",
                        label: String(localized: "min")
                    )
                    summaryItem(
                        icon: "checkmark.circle",
                        value: "\(detail.sessionsCompleted)",
                        label: String(localized: "sessions")
                    )
                    summaryItem(
                        icon: "list.bullet",
                        value: "\(detail.tasks.count)",
                        label: String(localized: "tasks")
                    )
                }
            }

            // Sessions list
            if !detail.sessions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "Focus Sessions"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(detail.sessions) { session in
                        sessionRow(session)
                    }
                }
            }

            // Tasks list
            if !detail.tasks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "Tasks"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(detail.tasks) { task in
                        taskRow(task)
                    }
                }
            }

            // Empty state
            if detail.sessions.isEmpty && detail.tasks.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "moon.zzz")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text(String(localized: "No activity"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 12)
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func summaryItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
            Text(value)
                .font(.title2.weight(.bold).monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func sessionRow(_ session: CalendarFeature.State.SessionSummary) -> some View {
        let mode = FocusMode(rawValue: session.mode) ?? .pomodoro
        return HStack(spacing: 12) {
            Image(systemName: mode.systemImage)
                .foregroundStyle(theme.color(for: mode))
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(mode.displayName)
                    .font(.subheadline)
                Text(session.startedAt, format: .dateTime.hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(String(localized: "\(session.durationMinutes) min"))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)

            if session.wasCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }

    private func taskRow(_ task: CalendarFeature.State.TaskSummary) -> some View {
        HStack(spacing: 12) {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(task.isCompleted ? .green : .secondary)
                .frame(width: 22)

            Text(task.title)
                .font(.subheadline)
                .strikethrough(task.isCompleted)
                .foregroundStyle(task.isCompleted ? .secondary : .primary)
                .lineLimit(1)

            Spacer()

            if task.isDue {
                Text(String(localized: "Due"))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: date)
    }

    private func fullDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }

    private var orderedWeekdaySymbols: [String] {
        let symbols = calendar.shortWeekdaySymbols
        let firstWeekday = calendar.firstWeekday - 1 // 0-based
        return Array(symbols[firstWeekday...]) + Array(symbols[..<firstWeekday])
    }

    private var leadingEmptyCells: Int {
        let comps = calendar.dateComponents([.year, .month], from: store.displayedMonth)
        guard let firstOfMonth = calendar.date(from: comps) else { return 0 }
        let weekday = calendar.component(.weekday, from: firstOfMonth) // 1=Sun, 2=Mon...
        let firstWeekday = calendar.firstWeekday
        return (weekday - firstWeekday + 7) % 7
    }

    private var daysInMonth: [Date] {
        let comps = calendar.dateComponents([.year, .month], from: store.displayedMonth)
        guard let firstOfMonth = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else {
            return []
        }
        return range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth)
        }
    }
}
