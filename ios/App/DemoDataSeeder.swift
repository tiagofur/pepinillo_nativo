// DemoDataSeeder.swift
// Pepinillo — Deep Work Companion for Apple
//
// Seeds realistic demo data for App Store screenshots.
// Activated by the `-seedDemoData` launch argument.
// Use `-proMode` to simulate Pepinillo+ subscription in debug builds.
// This file is only used in Debug builds.

#if DEBUG
import Foundation
import SwiftData

@MainActor
enum DemoDataSeeder {

    /// Whether debug mode should simulate a paid subscription.
    ///
    /// Persistence: `-proMode` and `-freeMode` launch arguments set a sticky
    /// UserDefaults flag so Pro state survives relaunches from springboard /
    /// Xcode without needing to pass the flag every time (useful for App Store
    /// screenshots). Launch via `launch_demo.sh` once to enable, then launch
    /// from anywhere — state persists until you pass `-freeMode`.
    nonisolated static var shouldSimulatePro: Bool {
        let defaultsKey = "pepinillo.debug.simulatePro"
        let args = CommandLine.arguments
        if args.contains("-proMode") {
            UserDefaults.standard.set(true, forKey: defaultsKey)
            return true
        }
        if args.contains("-freeMode") {
            UserDefaults.standard.set(false, forKey: defaultsKey)
            return false
        }
        return UserDefaults.standard.bool(forKey: defaultsKey)
    }

    /// Single source of truth for the effective Pro state in DEBUG builds.
    ///
    /// When the simulation flag is on, Pro is forced regardless of what SwiftData
    /// says. This prevents `SettingsFeature.preferencesLoaded` from clobbering the
    /// simulated state with the persisted (always-false) `prefs.isProUser`.
    /// In release builds `effectiveIsPro(persisted:)` simply returns `persisted`
    /// (see the non-DEBUG shim below).
    nonisolated static func effectiveIsPro(persisted: Bool) -> Bool {
        shouldSimulatePro || persisted
    }

    /// Spanish demo mode (`-esDemo`): swap seeded titles/notes for the
    /// Spanish set so manuals and ES store captures show localized data.
    private static let isSpanishDemo = CommandLine.arguments.contains("-esDemo")

    private static func t(_ en: String, _ es: String) -> String {
        isSpanishDemo ? es : en
    }

    static func seedIfNeeded(container: ModelContainer) {
        guard CommandLine.arguments.contains("-seedDemoData") else { return }

        let context = container.mainContext

        // Wipe existing data
        try? context.delete(model: FocusSessionRecord.self)
        try? context.delete(model: SubTask.self)
        try? context.delete(model: TaskItem.self)
        try? context.delete(model: DailyStats.self)
        try? context.delete(model: UserPreferences.self)
        try? context.save()

        // MARK: - Preferences (Pro user, onboarding done, streak active)

        let prefs = UserPreferences()
        prefs.hasCompletedOnboarding = true
        prefs.isProUser = true
        prefs.currentStreakDays = 12
        prefs.longestStreakDays = 18
        prefs.lastFocusDate = Calendar.current.startOfDay(for: Date())
        prefs.themeName = "default"
        prefs.soundEnabled = true
        prefs.hapticEnabled = true
        prefs.dailyReminderEnabled = true
        prefs.dailyReminderHour = 8
        prefs.dailyReminderMinute = 30
        context.insert(prefs)

        let cal = Calendar.current
        let now = Date()
        let today = cal.startOfDay(for: now)

        // MARK: - Tasks

        // Active deep work tasks (scheduled for today)
        let t1 = TaskItem(title: t("Finish API integration", "Terminar integración de la API"), priority: .high, energyLevel: .deep, estimatedPomodoros: 6, sortOrder: 0)
        t1.scheduledForToday = true
        t1.completedPomodoros = 4
        t1.preferredMode = "pomodoro"
        t1.notes = t("Auth endpoints + error handling. Use retry logic from NetworkClient.", "Endpoints de auth y manejo de errores. Usar la lógica de reintentos de NetworkClient.")
        let sub1a = SubTask(title: t("Auth endpoint", "Endpoint de auth"), sortOrder: 0); sub1a.isCompleted = true
        let sub1b = SubTask(title: t("User profile endpoint", "Endpoint de perfil"), sortOrder: 1); sub1b.isCompleted = true
        let sub1c = SubTask(title: t("Error handling", "Manejo de errores"), sortOrder: 2); sub1c.isCompleted = true
        let sub1d = SubTask(title: t("Retry logic", "Lógica de reintentos"), sortOrder: 3)
        let sub1e = SubTask(title: t("Write tests", "Escribir tests"), sortOrder: 4)
        t1.subtasks = [sub1a, sub1b, sub1c, sub1d, sub1e]

        let t2 = TaskItem(title: t("Design system audit", "Auditoría del design system"), priority: .medium, energyLevel: .deep, estimatedPomodoros: 4, sortOrder: 1)
        t2.scheduledForToday = true
        t2.completedPomodoros = 2
        t2.preferredMode = "flowtime"

        let t3 = TaskItem(title: t("Write blog post draft", "Escribir borrador del blog"), priority: .medium, energyLevel: .deep, estimatedPomodoros: 3, sortOrder: 2)
        t3.scheduledForToday = true
        t3.completedPomodoros = 0
        t3.preferredMode = "timeBlock"

        let t4 = TaskItem(title: t("Review pull requests", "Revisar pull requests"), priority: .low, energyLevel: .shallow, estimatedPomodoros: 2, sortOrder: 3)
        t4.scheduledForToday = true
        t4.completedPomodoros = 1

        let t5 = TaskItem(title: t("Update project roadmap", "Actualizar el roadmap del proyecto"), priority: .high, energyLevel: .admin, estimatedPomodoros: 2, sortOrder: 4)
        t5.scheduledForToday = true
        t5.dueDate = cal.date(byAdding: .day, value: 1, to: today)

        let t6 = TaskItem(title: t("Prepare weekly standup", "Preparar el standup semanal"), priority: .low, energyLevel: .admin, estimatedPomodoros: 1, sortOrder: 5)
        t6.scheduledForToday = true

        // Completed tasks
        let t7 = TaskItem(title: t("Set up CI/CD pipeline", "Configurar el pipeline de CI/CD"), priority: .high, energyLevel: .deep, estimatedPomodoros: 4, sortOrder: 6)
        t7.isCompleted = true
        t7.completedAt = cal.date(byAdding: .day, value: -1, to: now)
        t7.completedPomodoros = 4

        let t8 = TaskItem(title: t("Database schema migration", "Migración del schema de la base"), priority: .high, energyLevel: .deep, estimatedPomodoros: 3, sortOrder: 7)
        t8.isCompleted = true
        t8.completedAt = cal.date(byAdding: .day, value: -2, to: now)
        t8.completedPomodoros = 3

        // Future tasks (not for today)
        let t9 = TaskItem(title: t("Onboarding flow redesign", "Rediseño del onboarding"), priority: .medium, energyLevel: .deep, estimatedPomodoros: 5, sortOrder: 8)
        t9.dueDate = cal.date(byAdding: .day, value: 3, to: today)

        let t10 = TaskItem(title: t("Performance profiling", "Perfilado de performance"), priority: .low, energyLevel: .deep, estimatedPomodoros: 3, sortOrder: 9)

        let tasks = [t1, t2, t3, t4, t5, t6, t7, t8, t9, t10]
        tasks.forEach { context.insert($0) }

        // MARK: - Focus Sessions (past 14 days)

        var allSessions: [FocusSessionRecord] = []

        for dayOffset in (0...13).reversed() {
            let dayStart = cal.date(byAdding: .day, value: -dayOffset, to: today)!
            let sessionsForDay = generateSessionsForDay(
                dayStart: dayStart,
                dayOffset: dayOffset,
                tasks: tasks,
                cal: cal
            )
            allSessions.append(contentsOf: sessionsForDay)
        }

        allSessions.forEach { context.insert($0) }

        // MARK: - Daily Stats (past 14 days)
        //
        // Seeded with intentional variety so the 7-day spark chart shows
        // a realistic spread: a productive Tuesday, a quieter weekend,
        // a great Thursday, etc.  Each day's seconds are driven by the
        // generated sessions, then we add a per-day variance multiplier
        // so the bars differ noticeably.
        let dayVariance: [Int: Double] = [
            // dayOffset → multiplier applied to session seconds
            0: 1.0,  // today (partial)
            1: 1.4,  // yesterday (strong day)
            2: 0.6,  // 2 days ago (light)
            3: 1.2,  // 3 days ago (good)
            4: 0.3,  // 4 days ago (weekend — minimal)
            5: 0.4,  // 5 days ago (weekend — light)
            6: 1.1,  // 6 days ago (solid)
            7: 0.8,
            8: 1.3,
            9: 0.5,
            10: 1.0,
            11: 0.7,
            12: 1.2,
            13: 0.9,
        ]

        for dayOffset in (0...13).reversed() {
            let dayDate = cal.date(byAdding: .day, value: -dayOffset, to: today)!
            let stats = DailyStats(date: dayDate)

            let daySessions = allSessions.filter {
                cal.isDate($0.startedAt, inSameDayAs: dayDate)
            }

            let multiplier = dayVariance[dayOffset] ?? 1.0

            for session in daySessions {
                let rawSeconds = Int(session.actualDuration)
                let seconds = max(60, Int(Double(rawSeconds) * multiplier))
                stats.totalFocusSeconds += seconds
                stats.sessionsCompleted += 1
                stats.hadFocusSession = true

                switch session.mode {
                case "pomodoro":
                    stats.pomodoroSeconds += seconds
                    stats.pomodoroCount += 1
                case "flowtime":
                    stats.flowtimeSeconds += seconds
                    stats.flowtimeCount += 1
                case "timeBlock":
                    stats.timeBlockSeconds += seconds
                    stats.timeBlockCount += 1
                case "stopwatch":
                    stats.stopwatchSeconds += seconds
                    stats.stopwatchCount += 1
                default: break
                }
            }

            // Skip today's tasks-completed since the day is in progress.
            stats.tasksCompleted = dayOffset == 0 ? 0 : min(daySessions.count / 2, 3)
            context.insert(stats)
        }

        try? context.save()
    }

    // MARK: - Session Generator

    // Per-day session count override for last 7 days — drives visible chart variance.
    // Index 0 = today (rightmost bar), index 6 = 6 days ago (leftmost bar).
    private static let sessionCountByDayOffset: [Int: Int] = [
        0: 3,  // today: partial day
        1: 7,  // yesterday: strong productivity day
        2: 2,  // 2 days ago: light day (interruptions, meetings)
        3: 5,  // 3 days ago: solid day
        4: 1,  // 4 days ago: near-zero (weekend)
        5: 2,  // 5 days ago: weekend, light
        6: 6,  // 6 days ago: most productive day of the week
    ]

    private static func generateSessionsForDay(
        dayStart: Date,
        dayOffset: Int,
        tasks: [TaskItem],
        cal: Calendar
    ) -> [FocusSessionRecord] {
        var sessions: [FocusSessionRecord] = []

        // Use the per-day override for the chart window; fall back to weekday heuristic.
        let sessionCount: Int
        if let override = sessionCountByDayOffset[dayOffset] {
            sessionCount = override
        } else {
            let weekday = cal.component(.weekday, from: dayStart)
            let isWeekend = weekday == 1 || weekday == 7
            let baseCount = isWeekend ? 3 : 5
            let variance = dayOffset % 3 == 0 ? 1 : 0
            sessionCount = max(2, baseCount + variance)
        }

        var hour = 8 // Start at 8 AM

        for i in 0..<sessionCount {
            let startDate = cal.date(bySettingHour: hour, minute: Int.random(in: 0...45), second: 0, of: dayStart)!

            let mode: String
            let phase: String
            let duration: TimeInterval
            let target: TimeInterval?

            switch i % 4 {
            case 0: // Pomodoro
                mode = "pomodoro"
                phase = "work"
                duration = 25 * 60
                target = 25 * 60
            case 1: // Flowtime
                mode = "flowtime"
                phase = "flow"
                duration = TimeInterval(Int.random(in: 35...65) * 60)
                target = nil
            case 2: // Time Block
                mode = "timeBlock"
                phase = "block"
                duration = 60 * 60
                target = 60 * 60
            default: // Pomodoro again
                mode = "pomodoro"
                phase = "work"
                duration = 25 * 60
                target = 25 * 60
            }

            let endDate = startDate.addingTimeInterval(duration)

            let record = makeRecord(
                mode: mode,
                phase: phase,
                startedAt: startDate,
                endedAt: endDate,
                targetDuration: target,
                actualDuration: duration,
                wasCompleted: true,
                pomodoroNumber: mode == "pomodoro" ? (i / 2) + 1 : nil
            )

            // Link some sessions to tasks
            if i < tasks.count && !tasks[i].isCompleted {
                record.task = tasks[i % 6]
            }

            sessions.append(record)
            hour += Int(duration / 3600) + 1 // next session starts ~1h after
            if hour > 20 { break }
        }

        return sessions
    }

    private static func makeRecord(
        mode: String,
        phase: String,
        startedAt: Date,
        endedAt: Date,
        targetDuration: TimeInterval?,
        actualDuration: TimeInterval,
        wasCompleted: Bool,
        pomodoroNumber: Int?
    ) -> FocusSessionRecord {
        // Build via FocusSessionResult to use the existing init
        let focusMode = FocusMode(rawValue: mode) ?? .pomodoro
        let focusPhase: FocusPhase = switch phase {
        case "work": .work(number: pomodoroNumber ?? 1, total: 4)
        case "flow": .flow
        case "block": .block
        case "freeform": .freeform
        default: .work(number: 1, total: 4)
        }

        let result = FocusSessionResult(
            id: UUID(),
            mode: focusMode,
            phase: focusPhase,
            startedAt: startedAt,
            endedAt: endedAt,
            targetDuration: targetDuration,
            actualDuration: actualDuration,
            wasCompleted: wasCompleted,
            interruptions: 0,
            pomodoroNumber: pomodoroNumber,
            linkedTaskID: nil,
            pauseCount: 0,
            totalPauseDuration: 0
        )

        return FocusSessionRecord(from: result)
    }
}
#endif

// MARK: - Release shim for effectiveIsPro
//
// In DEBUG builds `DemoDataSeeder.effectiveIsPro(persisted:)` is defined inside
// the `#if DEBUG` enum above. In release builds the Pro simulation does not
// exist, so this shim returns the persisted value unchanged. This lets callers
// (AppFeature, SettingsFeature) use `DemoDataSeeder.effectiveIsPro(...)` without
// their own `#if DEBUG` guards.
#if !DEBUG
enum DemoDataSeeder {
    @inlinable static func effectiveIsPro(persisted: Bool) -> Bool { persisted }
}
#endif
