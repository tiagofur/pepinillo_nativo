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
        let now = Date.now
        let entry = await buildEntry(configuration: configuration)
        // Active countdown: emit staggered entries so the progress ring visibly
        // advances. Text(timerInterval:) self-ticks, but TimelineView(.periodic)
        // does NOT re-render inside WidgetKit views on macOS — a single-entry
        // timeline leaves the ring frozen until the next reload. Entries are
        // cheap snapshots (one SwiftData pass below, pure math per entry).
        if entry.isSessionActive, !entry.isPaused, !entry.isWaiting,
           let timerEnd = entry.timerEnd, timerEnd > now {
            let entries = staggeredEntries(base: entry, now: now, end: timerEnd)
            return Timeline(entries: entries, policy: .after(timerEnd))
        }
        if entry.isSessionActive, let timerEnd = entry.timerEnd, timerEnd > now {
            return Timeline(entries: [entry], policy: .after(timerEnd))
        }
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: now) ?? now
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }

    /// Snapshots every 30 s from `now` to `end` (capped), each carrying the
    /// progress computed for its own date. WidgetKit renders each snapshot in
    /// turn, so the ring advances deterministically even though the extension
    /// process never re-runs between entries. Math lives in
    /// `staggeredTimelineSnapshots` (WidgetIntents.swift) so tests can pin it.
    private func staggeredEntries(base: FocusWidgetEntry, now: Date, end: Date) -> [FocusWidgetEntry] {
        let snapshots = staggeredTimelineSnapshots(
            start: base.timerStart ?? now, now: now, end: end
        )
        guard !snapshots.isEmpty else { return [base] }
        return snapshots.map { base.with(date: $0.date, progress: $0.progress) }
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

            // Fetch stats for protected streak computation.
            // StreakProtectionService walks at most 730 days back; fetching 731
            // days is sufficient and avoids an unbounded table scan.
            let streakLookbackStart = Calendar.current.date(
                byAdding: .day, value: -731, to: today
            ) ?? Date.distantPast
            let allTimeDescriptor = FetchDescriptor<DailyStats>(
                predicate: #Predicate { $0.date >= streakLookbackStart },
                sortBy: [SortDescriptor(\.date)]
            )
            let allTimeStats = (try? context.fetch(allTimeDescriptor)) ?? []

            // Fetch user preferences for default mode and Pro status
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

            let configuredMode = configuration.preferredMode.rawValue
            let preferredModeID = AppGroupDefaults.widgetSelectedMode ?? prefs?.defaultMode ?? configuredMode
            let preferredTimerText = Self.idleTimerText(for: preferredModeID, preferences: prefs)

            // Check AppGroupDefaults for active session state.
            // A widget start tap is only a request until the app starts the engine, so
            // require a concrete active mode before rendering the live timer layout.
            let activeModeName = AppGroupDefaults.activeModeName
            let isActive = AppGroupDefaults.isSessionActive && activeModeName != nil
            let isPaused = isActive ? AppGroupDefaults.activeSessionIsPaused : false
            let isWaiting = isActive ? AppGroupDefaults.activeSessionIsWaiting : false
            let activeMode = isActive ? activeModeName : nil
            let activePhase = isActive ? AppGroupDefaults.activeSessionPhase : nil
            let activeIsBreak = isActive ? AppGroupDefaults.activeSessionPhaseIsBreak : false
            let activeIsLongBreak = isActive ? AppGroupDefaults.activeSessionPhaseIsLongBreak : false
            // Waiting hold: the only running-clock value is what comes next.
            // timerText shows the pending phase's full target (e.g. the break's
            // 5:00 after a pomodoro), never a stale leftover of the finished phase.
            let waitingTarget = isWaiting ? AppGroupDefaults.activeSessionNextPhaseTarget : nil
            let liveElapsed = isWaiting ? 0 : (isActive ? AppGroupDefaults.activeSessionLiveElapsed() : 0)
            let liveRemaining = isWaiting ? nil : (isActive ? AppGroupDefaults.activeSessionLiveRemaining() : nil)
            let activeProgress: Double?
            if let waitingTarget, waitingTarget > 0 {
                activeProgress = 0
            } else if isActive, let remaining = liveRemaining {
                let duration = max(liveElapsed + remaining, 1)
                activeProgress = min(max(liveElapsed / duration, 0), 1)
            } else {
                activeProgress = isActive && !isWaiting ? AppGroupDefaults.activeSessionProgress : nil
            }
            let activePomodoroNumber = isActive ? AppGroupDefaults.activeSessionPomodoroNumber : nil
            let activeTotalPomodoros = isActive ? AppGroupDefaults.activeSessionTotalPomodoros : nil
            let activeTaskTitle = isActive ? AppGroupDefaults.activeSessionTaskTitle : nil
            let timerStart = isWaiting ? nil : (isActive ? AppGroupDefaults.activeSessionTimerStart : nil)
            let timerEnd = isWaiting ? nil : (isActive ? AppGroupDefaults.activeSessionTimerEnd : nil)

            // Build a snapshot timer string. Live widget text uses timerStart/timerEnd where possible.
            let timerText: String?
            if isWaiting, let waitingTarget, waitingTarget > 0 {
                timerText = Self.formatTimer(waitingTarget)
            } else if isActive {
                if let remaining = liveRemaining {
                    timerText = Self.formatTimer(remaining)
                } else {
                    timerText = Self.formatTimer(liveElapsed)
                }
            } else {
                timerText = nil
            }

            let isPro = AppGroupDefaults.isProUser
            let calendar = Calendar.current
            var focusByDay: [Date: Bool] = [:]
            for stat in allTimeStats {
                let day = calendar.startOfDay(for: stat.date)
                focusByDay[day] = (focusByDay[day] ?? false) || stat.hadFocusSession
            }
            let streakResult = StreakProtectionService.computeProtectedStreak(
                focusByDay: focusByDay,
                isPro: isPro,
                today: today,
                calendar: calendar
            )

            let entry = FocusWidgetEntry(
                date: Date(),
                isProUser: isPro,
                preferredModeID: preferredModeID,
                preferredTimerText: preferredTimerText,
                // S2: honor the widget's configuration toggles.
                showStreak: configuration.showStreak,
                showModeBreakdown: configuration.showModeBreakdown,
                isSessionActive: isActive,
                isPaused: isPaused,
                isWaiting: isWaiting,
                isBreakPhase: activeIsBreak,
                isLongBreakPhase: activeIsLongBreak,
                nextPhaseTarget: waitingTarget,
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
                currentStreakDays: streakResult.days,
                streakProtectionApplied: streakResult.protectionApplied,
                dominantMode: dominantMode,
                modeMinutes: modeMinutes
            )
            return entry
        } catch {
            // SwiftData may be unavailable before first launch, during migration, or
            // while macOS debug signing uses a fallback container. Still honor the
            // lightweight App Group snapshot so the widget can show the live timer.
            return Self.defaultsBackedEntry(configuration: configuration)
        }
    }

    private static func defaultsBackedEntry(configuration: ConfigureFocusWidgetIntent) -> FocusWidgetEntry {
        let preferredModeID = AppGroupDefaults.widgetSelectedMode ?? configuration.preferredMode.rawValue
        let isActive = AppGroupDefaults.isSessionActive && AppGroupDefaults.activeModeName != nil
        let isPaused = isActive ? AppGroupDefaults.activeSessionIsPaused : false
        let isWaiting = isActive ? AppGroupDefaults.activeSessionIsWaiting : false
        let waitingTarget = isWaiting ? AppGroupDefaults.activeSessionNextPhaseTarget : nil
        let liveElapsed = isWaiting ? 0 : (isActive ? AppGroupDefaults.activeSessionLiveElapsed() : 0)
        let liveRemaining = isWaiting ? nil : (isActive ? AppGroupDefaults.activeSessionLiveRemaining() : nil)

        let activeProgress: Double?
        if let waitingTarget, waitingTarget > 0 {
            activeProgress = 0
        } else if isActive, let liveRemaining {
            let duration = max(liveElapsed + liveRemaining, 1)
            activeProgress = min(max(liveElapsed / duration, 0), 1)
        } else {
            activeProgress = isActive && !isWaiting ? AppGroupDefaults.activeSessionProgress : nil
        }

        let timerText: String?
        if isWaiting, let waitingTarget, waitingTarget > 0 {
            timerText = formatTimer(waitingTarget)
        } else if isActive {
            timerText = formatTimer(liveRemaining ?? liveElapsed)
        } else {
            timerText = nil
        }

        return FocusWidgetEntry(
            date: Date(),
            isProUser: AppGroupDefaults.isProUser,
            preferredModeID: preferredModeID,
            preferredTimerText: idleTimerText(for: preferredModeID, preferences: nil),
            // S2: honor the widget's configuration toggles (not the defaults).
            showStreak: configuration.showStreak,
            showModeBreakdown: configuration.showModeBreakdown,
            isSessionActive: isActive,
            isPaused: isPaused,
            isWaiting: isWaiting,
            isBreakPhase: isActive ? AppGroupDefaults.activeSessionPhaseIsBreak : false,
            isLongBreakPhase: isActive ? AppGroupDefaults.activeSessionPhaseIsLongBreak : false,
            nextPhaseTarget: waitingTarget,
            focusMode: isActive ? AppGroupDefaults.activeModeName : nil,
            phase: isActive ? AppGroupDefaults.activeSessionPhase : nil,
            timerText: timerText,
            progress: activeProgress,
            pomodoroNumber: isActive ? AppGroupDefaults.activeSessionPomodoroNumber : nil,
            totalPomodoros: isActive ? AppGroupDefaults.activeSessionTotalPomodoros : nil,
            linkedTaskTitle: isActive ? AppGroupDefaults.activeSessionTaskTitle : nil,
            timerStart: isWaiting ? nil : (isActive ? AppGroupDefaults.activeSessionTimerStart : nil),
            timerEnd: isWaiting ? nil : (isActive ? AppGroupDefaults.activeSessionTimerEnd : nil),
            todayFocusMinutes: 0,
            todaySessionsCompleted: 0,
            currentStreakDays: 0,
            streakProtectionApplied: false,
            dominantMode: nil,
            modeMinutes: [:]
        )
    }

    // MARK: - Idle Timer

    private static func idleTimerText(for modeID: String, preferences: UserPreferences?) -> String {
        let seconds: TimeInterval
        switch modeID {
        case "pomodoro":
            seconds = preferences?.pomodoroDuration ?? FocusConfig.default.pomodoroDuration
        case "timeBlock":
            seconds = preferences?.defaultBlockDuration ?? FocusConfig.default.defaultBlockDuration
        case "flowtime", "stopwatch":
            seconds = 0
        default:
            seconds = FocusConfig.default.pomodoroDuration
        }
        return formatTimer(seconds)
    }

    private static func formatTimer(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(max(0, seconds))
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Widget Configuration Intent

import AppIntents

struct ConfigureFocusWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Configure Focus Widget"
    static let description = IntentDescription("Customize what Pepinillo shows on your Home Screen.")

    @Parameter(title: "Preferred Mode", default: .pomodoro)
    var preferredMode: WidgetFocusMode

    @Parameter(title: "Show Streak", default: true)
    var showStreak: Bool

    @Parameter(title: "Show Mode Breakdown", default: false)
    var showModeBreakdown: Bool
}

// MARK: - Mode Entity for Configuration

enum WidgetFocusMode: String, AppEnum {
    case pomodoro
    case flowtime
    case timeBlock
    case stopwatch

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Focus Mode"
    static let caseDisplayRepresentations: [WidgetFocusMode: DisplayRepresentation] = [
        .pomodoro: "Pomodoro",
        .flowtime: "Flowtime",
        .timeBlock: "Time Block",
        .stopwatch: "Stopwatch"
    ]
}
