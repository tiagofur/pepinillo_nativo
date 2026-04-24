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
        let t1 = TaskItem(title: "Finish API integration", priority: .high, energyLevel: .deep, estimatedPomodoros: 6, sortOrder: 0)
        t1.scheduledForToday = true
        t1.completedPomodoros = 4
        t1.preferredMode = "pomodoro"
        t1.notes = "Auth endpoints + error handling. Use retry logic from NetworkClient."
        let sub1a = SubTask(title: "Auth endpoint", sortOrder: 0); sub1a.isCompleted = true
        let sub1b = SubTask(title: "User profile endpoint", sortOrder: 1); sub1b.isCompleted = true
        let sub1c = SubTask(title: "Error handling", sortOrder: 2); sub1c.isCompleted = true
        let sub1d = SubTask(title: "Retry logic", sortOrder: 3)
        let sub1e = SubTask(title: "Write tests", sortOrder: 4)
        t1.subtasks = [sub1a, sub1b, sub1c, sub1d, sub1e]

        let t2 = TaskItem(title: "Design system audit", priority: .medium, energyLevel: .deep, estimatedPomodoros: 4, sortOrder: 1)
        t2.scheduledForToday = true
        t2.completedPomodoros = 2
        t2.preferredMode = "flowtime"

        let t3 = TaskItem(title: "Write blog post draft", priority: .medium, energyLevel: .deep, estimatedPomodoros: 3, sortOrder: 2)
        t3.scheduledForToday = true
        t3.completedPomodoros = 0
        t3.preferredMode = "timeBlock"

        let t4 = TaskItem(title: "Review pull requests", priority: .low, energyLevel: .shallow, estimatedPomodoros: 2, sortOrder: 3)
        t4.scheduledForToday = true
        t4.completedPomodoros = 1

        let t5 = TaskItem(title: "Update project roadmap", priority: .high, energyLevel: .admin, estimatedPomodoros: 2, sortOrder: 4)
        t5.scheduledForToday = true
        t5.dueDate = cal.date(byAdding: .day, value: 1, to: today)

        let t6 = TaskItem(title: "Prepare weekly standup", priority: .low, energyLevel: .admin, estimatedPomodoros: 1, sortOrder: 5)
        t6.scheduledForToday = true

        // Completed tasks
        let t7 = TaskItem(title: "Set up CI/CD pipeline", priority: .high, energyLevel: .deep, estimatedPomodoros: 4, sortOrder: 6)
        t7.isCompleted = true
        t7.completedAt = cal.date(byAdding: .day, value: -1, to: now)
        t7.completedPomodoros = 4

        let t8 = TaskItem(title: "Database schema migration", priority: .high, energyLevel: .deep, estimatedPomodoros: 3, sortOrder: 7)
        t8.isCompleted = true
        t8.completedAt = cal.date(byAdding: .day, value: -2, to: now)
        t8.completedPomodoros = 3

        // Future tasks (not for today)
        let t9 = TaskItem(title: "Onboarding flow redesign", priority: .medium, energyLevel: .deep, estimatedPomodoros: 5, sortOrder: 8)
        t9.dueDate = cal.date(byAdding: .day, value: 3, to: today)

        let t10 = TaskItem(title: "Performance profiling", priority: .low, energyLevel: .deep, estimatedPomodoros: 3, sortOrder: 9)

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

        for dayOffset in (0...13).reversed() {
            let dayDate = cal.date(byAdding: .day, value: -dayOffset, to: today)!
            let stats = DailyStats(date: dayDate)

            let daySessions = allSessions.filter {
                cal.isDate($0.startedAt, inSameDayAs: dayDate)
            }

            for session in daySessions {
                let seconds = Int(session.actualDuration)
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

            stats.tasksCompleted = dayOffset == 0 ? 0 : min(daySessions.count / 2, 3)
            context.insert(stats)
        }

        try? context.save()
    }

    // MARK: - Session Generator

    private static func generateSessionsForDay(
        dayStart: Date,
        dayOffset: Int,
        tasks: [TaskItem],
        cal: Calendar
    ) -> [FocusSessionRecord] {
        var sessions: [FocusSessionRecord] = []

        // Vary the session count by day (more on weekdays, less on weekends)
        let weekday = cal.component(.weekday, from: dayStart)
        let isWeekend = weekday == 1 || weekday == 7
        let baseCount = isWeekend ? 3 : 5
        let variance = dayOffset == 0 ? -1 : (dayOffset % 3 == 0 ? 1 : 0)
        let sessionCount = max(2, baseCount + variance)

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
