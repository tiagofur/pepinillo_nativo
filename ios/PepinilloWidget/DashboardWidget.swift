// DashboardWidget.swift
// Pepinillo — Deep Work Companion for Apple
//
// Home Screen widget showing weekly focus stats with SwiftUI Charts.
// Mode-colored stacked bars, streak, and trend indicators.

import WidgetKit
import SwiftUI

// MARK: - Widget Definition

struct DashboardHomeScreenWidget: Widget {
    let kind: String = "DashboardHomeScreenWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigureDashboardWidgetIntent.self,
            provider: DashboardWidgetProvider()
        ) { entry in
            DashboardWidgetEntryView(entry: entry)
                .pepinilloWidgetBackground()
        }
        .configurationDisplayName("Dashboard")
        .description("Weekly focus stats and progress at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Entry View Router

struct DashboardWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DashboardWidgetEntry

    var body: some View {
        if entry.pepinilloPlusRequired {
            WidgetProRequiredView(title: String(localized: "Dashboard"))
        } else {
            switch family {
            case .systemSmall:
                DashboardWidgetSmall(entry: entry)
            case .systemMedium:
                DashboardWidgetMedium(entry: entry)
            case .systemLarge:
                DashboardWidgetLarge(entry: entry)
            default:
                DashboardWidgetSmall(entry: entry)
            }
        }
    }
}

// MARK: - Widget Entry

struct DashboardWidgetEntry: TimelineEntry {
    let date: Date
    let isProUser: Bool
    let todayMinutes: Int
    let todaySessions: Int
    let streakDays: Int
    /// True when a missed day was automatically bridged via Pro streak-protection.
    let streakProtectionApplied: Bool
    let weeklyData: [DayData]
    let weeklyTotalMinutes: Int
    let bestDayMinutes: Int
    let bestDayName: String
    let yesterdayMinutes: Int

    struct DayData: Identifiable {
        let id: Date
        let dayAbbrev: String
        let pomodoroMinutes: Int
        let flowtimeMinutes: Int
        let timeBlockMinutes: Int
        let stopwatchMinutes: Int
        let isToday: Bool

        var totalMinutes: Int {
            pomodoroMinutes + flowtimeMinutes + timeBlockMinutes + stopwatchMinutes
        }
    }

    var pepinilloPlusRequired: Bool = false

    static let placeholder = DashboardWidgetEntry(
        date: Date(),
        isProUser: true,
        todayMinutes: 95,
        todaySessions: 4,
        streakDays: 7,
        streakProtectionApplied: false,
        weeklyData: (0..<7).map { i in
            DayData(
                id: Calendar.current.date(byAdding: .day, value: -(6-i), to: Date())!,
                dayAbbrev: ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"][i],
                pomodoroMinutes: [30, 45, 20, 60, 40, 15, 50][i],
                flowtimeMinutes: [10, 20, 0, 15, 10, 5, 30][i],
                timeBlockMinutes: [0, 10, 15, 0, 5, 0, 15][i],
                stopwatchMinutes: [5, 0, 10, 0, 0, 5, 0][i],
                isToday: i == 6
            )
        },
        weeklyTotalMinutes: 485,
        bestDayMinutes: 75,
        bestDayName: "Thu",
        yesterdayMinutes: 25
    )

    static let empty = DashboardWidgetEntry(
        date: Date(),
        isProUser: false,
        todayMinutes: 0,
        todaySessions: 0,
        streakDays: 0,
        streakProtectionApplied: false,
        weeklyData: [],
        weeklyTotalMinutes: 0,
        bestDayMinutes: 0,
        bestDayName: "",
        yesterdayMinutes: 0
    )

    static let pepinilloPlusRequired = DashboardWidgetEntry(
        date: Date(),
        isProUser: false,
        todayMinutes: 0,
        todaySessions: 0,
        streakDays: 0,
        streakProtectionApplied: false,
        weeklyData: [],
        weeklyTotalMinutes: 0,
        bestDayMinutes: 0,
        bestDayName: "",
        yesterdayMinutes: 0,
        pepinilloPlusRequired: true
    )
}

// MARK: - Configuration Intent

import AppIntents

struct ConfigureDashboardWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Configure Dashboard Widget"
    static let description = IntentDescription("Customize the Dashboard widget display.")

    @Parameter(title: "Show Mode Breakdown", default: true)
    var showModeBreakdown: Bool
}
