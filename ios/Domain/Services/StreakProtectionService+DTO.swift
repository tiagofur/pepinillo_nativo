// StreakProtectionService+DTO.swift
// Pepinillo — Deep Work Companion for Apple
//
// App-side convenience overload built on DailyStatsDTO.
// Kept separate from StreakProtectionService.swift so the core service can be
// compiled into the widget extensions, which do not include PersistenceClient
// (where DailyStatsDTO is defined).

import Foundation

extension StreakProtectionService {

    /// Convenience overload for use in the main app with `DailyStatsDTO` history.
    public static func computeProtectedStreak(
        history: [DailyStatsDTO],
        isPro: Bool,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> StreakResult {
        guard !history.isEmpty else { return .zero }

        var focusByDay: [Date: Bool] = [:]
        for stat in history {
            let day = calendar.startOfDay(for: stat.date)
            let hadSession = stat.sessionsCompleted > 0
            focusByDay[day] = (focusByDay[day] ?? false) || hadSession
        }

        return computeProtectedStreak(
            focusByDay: focusByDay,
            isPro: isPro,
            today: today,
            calendar: calendar
        )
    }
}
