// FocusWidgetProvider.swift
// Pepinillo — Deep Work Companion for Apple
//
// WidgetKit Timeline Provider.
// Reads today's DailyStats from the App Group shared SwiftData store.
// App Group ID: group.com.pepinillo.app  (configured in Xcode target entitlements)

import WidgetKit
import SwiftData
import Foundation

// MARK: - Timeline Provider

struct FocusWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = FocusWidgetEntry
    typealias Intent = ConfigureFocusWidgetIntent

    func placeholder(in context: Context) -> FocusWidgetEntry {
        .placeholder
    }

    func snapshot(for configuration: ConfigureFocusWidgetIntent, in context: Context) async -> FocusWidgetEntry {
        context.isPreview ? .placeholder : await buildEntry(configuration: configuration)
    }

    func timeline(for configuration: ConfigureFocusWidgetIntent, in context: Context) async -> Timeline<FocusWidgetEntry> {
        let entry = await buildEntry(configuration: configuration)
        // Refresh more frequently during active sessions, otherwise every 15 minutes
        let refreshMinutes = entry.isSessionActive ? 1 : 15
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: refreshMinutes, to: Date.now) ?? Date.now
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }

    // MARK: - Entry Construction

    private func buildEntry(configuration: ConfigureFocusWidgetIntent) async -> FocusWidgetEntry {
        do {
            let container = try makeWidgetModelContainer()
            let context = ModelContext(container)

            let today = Calendar.current.startOfDay(for: Date.now)
            guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) else {
                return .idle
            }

            // Fetch today's DailyStats
            let todayDescriptor = FetchDescriptor<DailyStats>(
                predicate: #Predicate { $0.date >= today && $0.date < tomorrow }
            )
            let todayStats = try context.fetch(todayDescriptor).first

            // Fetch streak (consecutive days with focus sessions, counting backwards)
            let streak = computeStreak(context: context, today: today)

            // Fetch user preferences for default mode
            let prefsDescriptor = FetchDescriptor<UserPreferences>()
            let prefs = try context.fetch(prefsDescriptor).first

            let focusMinutes = todayStats?.totalFocusMinutes ?? 0
            let sessionsCompleted = todayStats?.sessionsCompleted ?? 0
            let dominantMode = todayStats?.dominantMode?.rawValue

            var modeMinutes: [String: Int] = [:]
            if let stats = todayStats {
                let pomMins = stats.pomodoroSeconds / 60
                let flowMins = stats.flowtimeSeconds / 60
                let blockMins = stats.timeBlockSeconds / 60
                let watchMins = stats.stopwatchSeconds / 60
                if pomMins > 0  { modeMinutes["pomodoro"]  = pomMins }
                if flowMins > 0 { modeMinutes["flowtime"]  = flowMins }
                if blockMins > 0 { modeMinutes["timeBlock"] = blockMins }
                if watchMins > 0 { modeMinutes["stopwatch"] = watchMins }
            }

            _ = prefs // reserved for future per-user widget customization

            // Check AppGroupDefaults for active session state
            let isActive = AppGroupDefaults.isSessionActive
            let isPaused = isActive ? AppGroupDefaults.activeSessionIsPaused : false
            let activeMode = isActive ? AppGroupDefaults.activeModeName : nil
            let activePhase = isActive ? AppGroupDefaults.activeSessionPhase : nil
            let activeProgress = isActive ? AppGroupDefaults.activeSessionProgress : nil
            let activePomodoroNumber = isActive ? AppGroupDefaults.activeSessionPomodoroNumber : nil
            let activeTotalPomodoros = isActive ? AppGroupDefaults.activeSessionTotalPomodoros : nil
            let activeTaskTitle = isActive ? AppGroupDefaults.activeSessionTaskTitle : nil
            let timerStart = isActive ? AppGroupDefaults.activeSessionTimerStart : nil
            let timerEnd = isActive ? AppGroupDefaults.activeSessionTimerEnd : nil

            // Build timer text from elapsed/remaining
            let timerText: String?
            if isActive {
                if let remaining = AppGroupDefaults.activeSessionRemaining {
                    let m = remaining / 60
                    let s = remaining % 60
                    timerText = String(format: "%d:%02d", m, s)
                } else {
                    let elapsed = AppGroupDefaults.activeSessionElapsed
                    let m = elapsed / 60
                    let s = elapsed % 60
                    timerText = String(format: "%d:%02d", m, s)
                }
            } else {
                timerText = nil
            }

            let isPro = AppGroupDefaults.isProUser
            let entry = FocusWidgetEntry(
                date: Date(),
                isProUser: isPro,
                isSessionActive: isActive,
                isPaused: isPaused,
                focusMode: activeMode,
                phase: activePhase,
                timerText: timerText,
                progress: activeProgress,
                pomodoroNumber: activePomodoroNumber,
                totalPomodoros: activeTotalPomodoros,
                linkedTaskTitle: activeTaskTitle,
                timerStart: timerStart,
                timerEnd: timerEnd,
                todayFocusMinutes: focusMinutes,
                todaySessionsCompleted: sessionsCompleted,
                currentStreakDays: streak,
                dominantMode: dominantMode,
                modeMinutes: modeMinutes
            )
            return entry
        } catch {
            // SwiftData read failed (first launch / store not yet created) — show idle
            return .idle
        }
    }

    // MARK: - Streak Calculation

    /// Count consecutive days (going back from yesterday) where hadFocusSession == true.
    private func computeStreak(context: ModelContext, today: Date) -> Int {
        var streak = 0
        var checkDate = today

        for _ in 0..<365 {
            guard let start = Calendar.current.date(byAdding: .day, value: -1, to: checkDate) else { break }
            let end = checkDate

            let descriptor = FetchDescriptor<DailyStats>(
                predicate: #Predicate { $0.date >= start && $0.date < end }
            )

            guard let stats = try? context.fetch(descriptor).first,
                  stats.hadFocusSession else { break }

            streak += 1
            checkDate = start
        }
        return streak
    }
}

// MARK: - Widget Configuration Intent

import AppIntents

struct ConfigureFocusWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Configure Focus Widget"
    static let description = IntentDescription("Customize what Pepinillo shows on your Home Screen.")

    @Parameter(title: "Show Streak", default: true)
    var showStreak: Bool

    @Parameter(title: "Show Mode Breakdown", default: false)
    var showModeBreakdown: Bool
}
