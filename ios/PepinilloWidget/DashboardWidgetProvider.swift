// DashboardWidgetProvider.swift
// Pepinillo — Deep Work Companion for Apple
//
// Timeline provider for the Dashboard widget.
// Reads DailyStats for the last 7 days from the shared SwiftData store.

import WidgetKit
import SwiftData
import Foundation

struct DashboardWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = DashboardWidgetEntry
    typealias Intent = ConfigureDashboardWidgetIntent

    func placeholder(in context: Context) -> DashboardWidgetEntry {
        .placeholder
    }

    func snapshot(for configuration: ConfigureDashboardWidgetIntent, in context: Context) async -> DashboardWidgetEntry {
        context.isPreview ? .placeholder : await buildEntry(configuration: configuration)
    }

    func timeline(for configuration: ConfigureDashboardWidgetIntent, in context: Context) async -> Timeline<DashboardWidgetEntry> {
        let entry = await buildEntry(configuration: configuration)
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date.now) ?? Date.now
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }

    // MARK: - Entry Construction

    private func buildEntry(configuration: ConfigureDashboardWidgetIntent) async -> DashboardWidgetEntry {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date.now)
        guard let weekAgo = calendar.date(byAdding: .day, value: -6, to: today),
              let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else {
            return .empty
        }
        
        guard AppGroupDefaults.isProUser else { return .pepinilloPlusRequired }
        
        do {
            let container = try makeWidgetModelContainer()
            let context = ModelContext(container)

            // Fetch last 7 days of stats
            let descriptor = FetchDescriptor<DailyStats>(
                predicate: #Predicate { $0.date >= weekAgo && $0.date < tomorrow },
                sortBy: [SortDescriptor(\.date)]
            )
            let allStats = try context.fetch(descriptor)

            // Build day data for each of the 7 days
            let formatter = DateFormatter()
            formatter.locale = Locale.current
            var weeklyData: [DashboardWidgetEntry.DayData] = []
            var weeklyTotal = 0
            var bestDay = 0
            var bestDayName = ""
            var yesterdayMinutes = 0

            for offset in 0..<7 {
                guard let dayDate = calendar.date(byAdding: .day, value: offset, to: weekAgo),
                      let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayDate) else { continue }
                let isToday = calendar.isDate(dayDate, inSameDayAs: today)
                let isYesterday = offset == 5 // 6th index (0-based) minus 1

                formatter.dateFormat = "EEE"
                let abbrev = formatter.string(from: dayDate)

                let stats = allStats.first { $0.date >= dayDate && $0.date < dayEnd }
                if stats == nil {
                    print("[DashboardWidget] No DailyStats found for \(abbrev) \(dayDate)")
                }

                let pomMin = (stats?.pomodoroSeconds ?? 0) / 60
                let flowMin = (stats?.flowtimeSeconds ?? 0) / 60
                let blockMin = (stats?.timeBlockSeconds ?? 0) / 60
                let watchMin = (stats?.stopwatchSeconds ?? 0) / 60
                let dayTotal = pomMin + flowMin + blockMin + watchMin

                weeklyData.append(DashboardWidgetEntry.DayData(
                    id: dayDate,
                    dayAbbrev: abbrev,
                    pomodoroMinutes: pomMin,
                    flowtimeMinutes: flowMin,
                    timeBlockMinutes: blockMin,
                    stopwatchMinutes: watchMin,
                    isToday: isToday
                ))

                weeklyTotal += dayTotal
                if dayTotal > bestDay {
                    bestDay = dayTotal
                    bestDayName = abbrev
                }
                if isYesterday {
                    yesterdayMinutes = dayTotal
                }
            }

            // Today's stats
            let todayStats = allStats.first { calendar.isDate($0.date, inSameDayAs: today) }
            let todayMinutes = todayStats?.totalFocusMinutes ?? 0
            let todaySessions = todayStats?.sessionsCompleted ?? 0

            // Streak — fetch all-time stats for protected streak computation
            let allTimeDescriptor = FetchDescriptor<DailyStats>()
            let allTimeStats = (try? context.fetch(allTimeDescriptor)) ?? []
            let isPro = AppGroupDefaults.isProUser
            let streak = computeProtectedStreak(
                allStats: allTimeStats,
                isPro: isPro,
                today: today,
                calendar: calendar
            )

            return DashboardWidgetEntry(
                date: Date.now,
                isProUser: isPro,
                todayMinutes: todayMinutes,
                todaySessions: todaySessions,
                streakDays: streak,
                weeklyData: weeklyData,
                weeklyTotalMinutes: weeklyTotal,
                bestDayMinutes: bestDay,
                bestDayName: bestDayName,
                yesterdayMinutes: yesterdayMinutes
            )
        } catch {
            return .empty
        }
    }

    // MARK: - Streak Calculation (with Pro protection)

    private func computeProtectedStreak(
        allStats: [DailyStats],
        isPro: Bool,
        today: Date,
        calendar: Calendar
    ) -> Int {
        var focusByDay: [Date: Bool] = [:]
        for stat in allStats {
            let day = calendar.startOfDay(for: stat.date)
            focusByDay[day] = (focusByDay[day] ?? false) || stat.hadFocusSession
        }

        guard !focusByDay.isEmpty else { return 0 }

        let startOfToday = calendar.startOfDay(for: today)
        let earliestFocusDate = focusByDay.filter { $0.value }.keys.min() ?? startOfToday

        var streak = 0
        var lastSkipUsedDate: Date? = nil
        var checkDate = startOfToday

        for _ in 0..<730 {
            let hadFocus = focusByDay[checkDate] ?? false

            if hadFocus {
                streak += 1
            } else if isPro && checkDate >= earliestFocusDate {
                let canSkip: Bool
                if let lastSkip = lastSkipUsedDate {
                    let daysApart = calendar.dateComponents([.day], from: checkDate, to: lastSkip).day ?? 0
                    canSkip = daysApart >= 7
                } else {
                    canSkip = true
                }
                if canSkip {
                    streak += 1
                    lastSkipUsedDate = checkDate
                } else {
                    break
                }
            } else {
                break
            }

            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = previousDay
        }
        return streak
    }
}
