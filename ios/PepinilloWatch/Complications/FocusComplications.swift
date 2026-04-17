// FocusComplications.swift
// Pepinillo — Deep Work Companion for Apple
//
// ClockKit / WidgetKit complications for Apple Watch.
// Provides: corner, circular small, graphic corner, and graphic rectangular.
// All complications deep-link into Pepinillo Watch app.

import ClockKit
import WidgetKit
import SwiftUI

// MARK: - Complication Entry

struct FocusComplicationEntry: TimelineEntry {
    let date: Date
    let isActive: Bool
    let displayTime: String
    let todayMinutes: Int
    let streakDays: Int
    let modeEmoji: String
    let linkedTaskTitle: String?
    let phaseName: String?
    let progress: Double
    let pomodoroNumber: Int?
    let phaseStartDate: Date?
    let phaseEndDate: Date?
}

// MARK: - Complication Provider

struct FocusComplicationProvider: TimelineProvider {
    typealias Entry = FocusComplicationEntry

    func placeholder(in context: Context) -> FocusComplicationEntry {
        FocusComplicationEntry(
            date: Date(),
            isActive: false,
            displayTime: "25:00",
            todayMinutes: 95,
            streakDays: 7,
            modeEmoji: "🍅",
            linkedTaskTitle: nil,
            phaseName: nil,
            progress: 0,
            pomodoroNumber: nil,
            phaseStartDate: nil,
            phaseEndDate: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (FocusComplicationEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : buildEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FocusComplicationEntry>) -> Void) {
        let entry = buildEntry()
        let refreshMinutes = entry.isActive ? 5 : 15
        let next = Calendar.current.date(byAdding: .minute, value: refreshMinutes, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    /// Reads persisted stats from UserDefaults (written by WatchTimerFeature on stats received).
    private func buildEntry() -> FocusComplicationEntry {
        let defaults = UserDefaults.standard
        let isActive = defaults.bool(forKey: WatchStatsKeys.isSessionActive)
        let displayTime = defaults.string(forKey: WatchStatsKeys.displayTime) ?? "—"
        let todayMinutes = defaults.integer(forKey: WatchStatsKeys.todayFocusMinutes)
        let streakDays = defaults.integer(forKey: WatchStatsKeys.currentStreakDays)
        let modeEmoji = defaults.string(forKey: WatchStatsKeys.modeEmoji) ?? "🧠"
        let linkedTaskTitle = defaults.string(forKey: WatchStatsKeys.linkedTaskTitle)
        let phaseName = defaults.string(forKey: WatchStatsKeys.phaseName)
        let progress = defaults.double(forKey: WatchStatsKeys.progress)
        let pomodoroNumber: Int? = defaults.object(forKey: WatchStatsKeys.pomodoroNumber) as? Int
        let phaseStartDate: Date? = {
            let ti = defaults.double(forKey: WatchStatsKeys.phaseStartDate)
            return ti > 0 ? Date(timeIntervalSince1970: ti) : nil
        }()
        let phaseEndDate: Date? = {
            let ti = defaults.double(forKey: WatchStatsKeys.phaseEndDate)
            return ti > 0 ? Date(timeIntervalSince1970: ti) : nil
        }()

        return FocusComplicationEntry(
            date: Date(),
            isActive: isActive,
            displayTime: displayTime,
            todayMinutes: todayMinutes,
            streakDays: streakDays,
            modeEmoji: modeEmoji,
            linkedTaskTitle: linkedTaskTitle,
            phaseName: phaseName,
            progress: progress,
            pomodoroNumber: pomodoroNumber,
            phaseStartDate: phaseStartDate,
            phaseEndDate: phaseEndDate
        )
    }
}

// WatchStatsKeys is defined in PepinilloWatch/WatchStatsKeys.swift

// MARK: - Complication Views

/// Circular small — shows streak or timer
struct CircularComplicationView: View {
    let entry: FocusComplicationEntry

    var body: some View {
        ZStack {
            if entry.isActive {
                ProgressView(value: entry.progress)
                    .progressViewStyle(.circular)
                Text(entry.modeEmoji)
                    .font(.system(size: 12))
            } else {
                VStack(spacing: 0) {
                    Text(entry.modeEmoji)
                        .font(.system(size: 14))
                    if entry.streakDays > 0 {
                        Text("\(entry.streakDays)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                }
            }
        }
    }
}

/// Rectangular — shows time or daily total (Smart Stack)
struct RectangularComplicationView: View {
    let entry: FocusComplicationEntry

    var body: some View {
        HStack(spacing: 6) {
            Text(entry.modeEmoji)
                .font(.body)

            VStack(alignment: .leading, spacing: 1) {
                if entry.isActive {
                    if let start = entry.phaseStartDate, let end = entry.phaseEndDate {
                        Text(timerInterval: start...end, countsDown: true)
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .monospacedDigit()
                    } else {
                        Text(entry.displayTime)
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .monospacedDigit()
                    }

                    HStack(spacing: 4) {
                        if let phase = entry.phaseName {
                            Text(phase)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if let num = entry.pomodoroNumber {
                            Text("· \(num)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text(formatMinutes(entry.todayMinutes))
                        .font(.system(.headline, design: .rounded, weight: .bold))

                    HStack(spacing: 4) {
                        Text(String(localized: "today"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if entry.streakDays > 0 {
                            Label(String(localized: "\(entry.streakDays)d"), systemImage: "flame.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()
        }
        .overlay(alignment: .bottomLeading) {
            if entry.isActive, let task = entry.linkedTaskTitle {
                Text(task)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes >= 60 {
            let h = minutes / 60; let m = minutes % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(minutes)m"
    }
}

// MARK: - Complication Widget Bundle

struct PepinilloWatchComplication: Widget {
    let kind = "PepinilloWatchComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FocusComplicationProvider()) { entry in
            ComplicationContentView(entry: entry)
        }
        .configurationDisplayName(String(localized: "Pepinillo Focus"))
        .description(String(localized: "Your focus timer and daily streak."))
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryCorner,
        ])
    }
}

// MARK: - Family-Adaptive Content View

private struct ComplicationContentView: View {
    let entry: FocusComplicationEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryRectangular:
            RectangularComplicationView(entry: entry)
        case .accessoryCorner:
            CornerComplicationView(entry: entry)
        default:
            CircularComplicationView(entry: entry)
        }
    }
}

// MARK: - Corner Complication

struct CornerComplicationView: View {
    let entry: FocusComplicationEntry

    var body: some View {
        Text(entry.modeEmoji)
            .font(.title3)
            .widgetLabel {
                if entry.isActive {
                    if let start = entry.phaseStartDate, let end = entry.phaseEndDate {
                        Text(timerInterval: start...end, countsDown: true)
                    } else {
                        Text(entry.displayTime)
                    }
                } else if entry.streakDays > 0 {
                    Label(String(localized: "\(entry.streakDays)d streak"), systemImage: "flame.fill")
                } else {
                    Text(String(localized: "Focus"))
                }
            }
    }
}
