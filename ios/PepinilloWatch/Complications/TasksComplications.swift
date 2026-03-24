// TasksComplications.swift
// Pepinillo — Deep Work Companion for Apple
//
// WidgetKit complications for Apple Watch — Tasks.
// Shows today's tasks with completion status and pomodoro progress.
// Cross-platform parity with Wear OS TasksTileService.

import WidgetKit
import SwiftUI

// MARK: - Complication Entry

struct TasksComplicationEntry: TimelineEntry {
    let date: Date
    let tasks: [ComplicationTask]
    let completedCount: Int
    let totalCount: Int

    struct ComplicationTask: Identifiable {
        let id: UUID
        let title: String
        let isCompleted: Bool
        let priority: Int
        let estimatedPomodoros: Int
        let completedPomodoros: Int

        /// Pomodoro progress as dot string (e.g. "••••◦◦◦")
        var pomodoroProgress: String {
            guard estimatedPomodoros > 0 else { return "" }
            let filled = String(repeating: "\u{2022}", count: min(completedPomodoros, estimatedPomodoros))
            let empty = String(repeating: "\u{25E6}", count: max(0, estimatedPomodoros - completedPomodoros))
            return filled + empty
        }

        /// Priority-based emoji (matches Wear OS energyEmoji)
        var priorityEmoji: String {
            switch priority {
            case 3: return "🔴"
            case 2: return "🟡"
            case 1: return "🟢"
            default: return "⚪"
            }
        }
    }
}

// MARK: - Complication Provider

struct TasksComplicationProvider: TimelineProvider {
    typealias Entry = TasksComplicationEntry

    func placeholder(in context: Context) -> TasksComplicationEntry {
        TasksComplicationEntry(
            date: Date(),
            tasks: [
                .init(id: UUID(), title: "Design review", isCompleted: false, priority: 3, estimatedPomodoros: 4, completedPomodoros: 2),
                .init(id: UUID(), title: "Write tests", isCompleted: false, priority: 2, estimatedPomodoros: 3, completedPomodoros: 0),
                .init(id: UUID(), title: "Fix bug #42", isCompleted: true, priority: 1, estimatedPomodoros: 1, completedPomodoros: 1),
            ],
            completedCount: 1,
            totalCount: 3
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TasksComplicationEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : buildEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TasksComplicationEntry>) -> Void) {
        let entry = buildEntry()
        // Refresh every 15 minutes (tasks change infrequently; WatchAppFeature triggers
        // explicit reload when new task data arrives via WatchConnectivity)
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    func relevances() async -> WidgetRelevances<Void> {
        let defaults = UserDefaults.standard
        let total = defaults.integer(forKey: WatchStatsKeys.tasksTotalCount)
        let completed = defaults.integer(forKey: WatchStatsKeys.tasksCompletedCount)
        let pending = total - completed

        // Higher relevance when there are pending tasks
        let score: Float = pending > 0 ? 50 : 5
        return WidgetRelevances([
            WidgetRelevance(context: (), score: score)
        ])
    }

    /// Reads persisted task data from UserDefaults (written by WatchAppFeature on tasks received).
    private func buildEntry() -> TasksComplicationEntry {
        let defaults = UserDefaults.standard
        let completedCount = defaults.integer(forKey: WatchStatsKeys.tasksCompletedCount)
        let totalCount = defaults.integer(forKey: WatchStatsKeys.tasksTotalCount)

        var tasks: [TasksComplicationEntry.ComplicationTask] = []
        if let data = defaults.data(forKey: WatchStatsKeys.tasksJSON),
           let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            tasks = items.compactMap { dict in
                guard let idStr = dict["id"] as? String,
                      let id = UUID(uuidString: idStr),
                      let title = dict["title"] as? String
                else { return nil }
                return TasksComplicationEntry.ComplicationTask(
                    id: id,
                    title: title,
                    isCompleted: dict["isCompleted"] as? Bool ?? false,
                    priority: dict["priority"] as? Int ?? 0,
                    estimatedPomodoros: dict["estimatedPomodoros"] as? Int ?? 0,
                    completedPomodoros: dict["completedPomodoros"] as? Int ?? 0
                )
            }
        }

        return TasksComplicationEntry(
            date: Date(),
            tasks: tasks,
            completedCount: completedCount,
            totalCount: totalCount
        )
    }
}

// MARK: - Complication Widget

struct PepinilloTasksComplication: Widget {
    let kind = "PepinilloTasksComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TasksComplicationProvider()) { entry in
            TasksComplicationContentView(entry: entry)
        }
        .configurationDisplayName(String(localized: "Pepinillo Tasks"))
        .description(String(localized: "Your today's tasks and progress."))
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryCorner,
        ])
    }
}

// MARK: - Family-Adaptive Content View

private struct TasksComplicationContentView: View {
    let entry: TasksComplicationEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryRectangular:
            TasksRectangularView(entry: entry)
        case .accessoryCorner:
            TasksCornerView(entry: entry)
        default:
            TasksCircularView(entry: entry)
        }
    }
}

// MARK: - Rectangular View (main — shows task list)

/// Matches Wear OS tile layout: header with count + up to 3 tasks with emoji, title, progress dots.
struct TasksRectangularView: View {
    let entry: TasksComplicationEntry

    private var pendingCount: Int { entry.totalCount - entry.completedCount }

    /// Show incomplete tasks first, sorted by priority descending.
    private var visibleTasks: [TasksComplicationEntry.ComplicationTask] {
        let sorted = entry.tasks
            .filter { !$0.isCompleted }
            .sorted { $0.priority > $1.priority }
        return Array(sorted.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            // Header: "Tasks (2/5)"
            Text("Tasks (\(entry.completedCount)/\(entry.totalCount))")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)

            if visibleTasks.isEmpty {
                Text(entry.totalCount == 0
                     ? String(localized: "No tasks")
                     : String(localized: "All done!"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(visibleTasks) { task in
                    HStack(spacing: 3) {
                        Text(task.priorityEmoji)
                            .font(.system(size: 10))
                        Text(truncated(task.title, max: 12))
                            .font(.system(size: 11))
                            .lineLimit(1)
                        if !task.pomodoroProgress.isEmpty {
                            Text(task.pomodoroProgress)
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func truncated(_ text: String, max length: Int) -> String {
        text.count > length ? String(text.prefix(length)) + "\u{2026}" : text
    }
}

// MARK: - Circular View (pending count)

struct TasksCircularView: View {
    let entry: TasksComplicationEntry

    private var pendingCount: Int { entry.totalCount - entry.completedCount }
    private var progress: Double {
        guard entry.totalCount > 0 else { return 0 }
        return Double(entry.completedCount) / Double(entry.totalCount)
    }

    var body: some View {
        ZStack {
            if entry.totalCount > 0 {
                ProgressView(value: progress)
                    .progressViewStyle(.circular)
            }
            VStack(spacing: 0) {
                Image(systemName: "checklist")
                    .font(.system(size: 10))
                Text("\(pendingCount)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
        }
    }
}

// MARK: - Corner View (pending count with label)

struct TasksCornerView: View {
    let entry: TasksComplicationEntry

    private var pendingCount: Int { entry.totalCount - entry.completedCount }

    var body: some View {
        Image(systemName: "checklist")
            .font(.title3)
            .widgetLabel {
                if entry.totalCount > 0 {
                    Text("\(pendingCount) pending")
                } else {
                    Text(String(localized: "Tasks"))
                }
            }
    }
}
