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
            modeEmoji: "🍅"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (FocusComplicationEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : buildEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FocusComplicationEntry>) -> Void) {
        let entry = buildEntry()
        // Refresh every 15 minutes
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    /// Reads persisted stats from UserDefaults (written by WatchFocusFeature on stats received).
    private func buildEntry() -> FocusComplicationEntry {
        let defaults = UserDefaults.standard
        let isActive = defaults.bool(forKey: WatchStatsKeys.isSessionActive)
        let displayTime = defaults.string(forKey: WatchStatsKeys.displayTime) ?? "—"
        let todayMinutes = defaults.integer(forKey: WatchStatsKeys.todayFocusMinutes)
        let streakDays = defaults.integer(forKey: WatchStatsKeys.currentStreakDays)
        let modeEmoji = defaults.string(forKey: WatchStatsKeys.modeEmoji) ?? "🧠"

        return FocusComplicationEntry(
            date: Date(),
            isActive: isActive,
            displayTime: displayTime,
            todayMinutes: todayMinutes,
            streakDays: streakDays,
            modeEmoji: modeEmoji
        )
    }
}

// MARK: - Shared UserDefaults Keys (Watch-side)

enum WatchStatsKeys {
    static let todayFocusMinutes = "watch.todayFocusMinutes"
    static let currentStreakDays = "watch.currentStreakDays"
    static let todaySessionsCompleted = "watch.todaySessionsCompleted"
    static let isSessionActive = "watch.isSessionActive"
    static let displayTime = "watch.displayTime"
    static let modeEmoji = "watch.modeEmoji"
}

// MARK: - Complication Views

/// Circular small — shows streak or timer
struct CircularComplicationView: View {
    let entry: FocusComplicationEntry

    var body: some View {
        ZStack {
            if entry.isActive {
                ProgressView(value: 0.65)
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

/// Rectangular — shows time or daily total
struct RectangularComplicationView: View {
    let entry: FocusComplicationEntry

    var body: some View {
        HStack(spacing: 6) {
            Text(entry.modeEmoji)
                .font(.body)

            VStack(alignment: .leading, spacing: 1) {
                if entry.isActive {
                    Text(entry.displayTime)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .monospacedDigit()
                } else {
                    Text(formatMinutes(entry.todayMinutes))
                        .font(.system(.headline, design: .rounded, weight: .bold))
                }
                Text(entry.isActive ? String(localized: "Focusing") : String(localized: "today"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if entry.streakDays > 0 && !entry.isActive {
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                        .foregroundStyle(ModeColors.streak)
                    Text("\(entry.streakDays)d")
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
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
                    Text(entry.displayTime)
                } else if entry.streakDays > 0 {
                    Label(String(localized: "\(entry.streakDays)d streak"), systemImage: "flame.fill")
                } else {
                    Text(String(localized: "Focus"))
                }
            }
    }
}
