// TasksWidget.swift
// Pepinillo — Deep Work Companion for Apple
//
// Home Screen widget showing active tasks with pomodoro progress,
// interactive completion toggles, and quick focus-start per task.

import WidgetKit
import SwiftUI

// MARK: - Widget Definition

struct TasksHomeScreenWidget: Widget {
    let kind: String = "TasksHomeScreenWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigureTasksWidgetIntent.self,
            provider: TasksWidgetProvider()
        ) { entry in
            TasksWidgetEntryView(entry: entry)
                .pepinilloWidgetBackground()
                .widgetURL(URL(string: "pepinillo://plan"))
        }
        .configurationDisplayName(LocalizedStringResource("widget.tasks.displayname", defaultValue: "Tasks"))
        .description(LocalizedStringResource("widget.tasks.description", defaultValue: "See your active tasks and mark them complete."))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Entry View Router

struct TasksWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TasksWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            TasksWidgetSmall(entry: entry)
        case .systemMedium:
            TasksWidgetMedium(entry: entry)
        case .systemLarge:
            TasksWidgetLarge(entry: entry)
        default:
            TasksWidgetSmall(entry: entry)
        }
    }
}

// MARK: - Widget Entry

struct TasksWidgetEntry: TimelineEntry {
    let date: Date
    let tasks: [WidgetTask]
    let activeTaskID: String?
    let isSessionActive: Bool

    struct WidgetTask: Identifiable {
        let id: String
        let title: String
        let isCompleted: Bool
        let energyIcon: String      // SF Symbol from EnergyLevel
        let completedPomodoros: Int
        let estimatedPomodoros: Int
        let priorityValue: Int       // 0=none, 1=low, 2=medium, 3=high
    }

    static let placeholder = TasksWidgetEntry(
        date: Date(),
        tasks: [
            WidgetTask(id: "1", title: "Write research paper", isCompleted: false, energyIcon: "brain.head.profile", completedPomodoros: 2, estimatedPomodoros: 4, priorityValue: 3),
            WidgetTask(id: "2", title: "Review PRs", isCompleted: false, energyIcon: "tray", completedPomodoros: 0, estimatedPomodoros: 2, priorityValue: 2),
            WidgetTask(id: "3", title: "Update docs", isCompleted: false, energyIcon: "folder", completedPomodoros: 1, estimatedPomodoros: 1, priorityValue: 1),
        ],
        activeTaskID: "1",
        isSessionActive: true
    )

    static let empty = TasksWidgetEntry(
        date: Date(),
        tasks: [],
        activeTaskID: nil,
        isSessionActive: false
    )
}

// MARK: - Configuration Intent

import AppIntents

struct ConfigureTasksWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Configure Tasks Widget"
    static let description = IntentDescription("Customize what the Tasks widget shows.")

    @Parameter(title: "Show Pomodoro Progress", default: true)
    var showPomodoroProgress: Bool
}
