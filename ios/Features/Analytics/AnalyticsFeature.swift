// AnalyticsFeature.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA Reducer for the Analytics dashboard.
// Aggregates FocusSessionRecord data from SwiftData to power charts, summary cards,
// productivity insights, and achievements.

import Foundation
import AppIntents
import ComposableArchitecture

@Reducer
struct AnalyticsFeature {

    @ObservableState
    struct State: Equatable {
        var period: Period = .week
        var chartData: [DayPoint] = []
        var modeBreakdown: [ModeShare] = []
        var totalFocusMinutes: Int = 0
        var sessionsCompleted: Int = 0
        var currentStreakDays: Int = 0
        var longestStreakDays: Int = 0
        var streakProtectionApplied: Bool = false
        var dominantMode: FocusMode?
        var achievements: [UserAchievement] = []
        var weeklyInsights: [FocusInsight] = []
        var isLoading: Bool = false
        var hasLoadedData: Bool = false
        var loadError: String?
        var isProUser: Bool = false
        @Presents var weeklyReview: WeeklyReviewFeature.State?
        @Presents var monthlyReview: MonthlyReviewFeature.State?
        @Presents var aiReport: AIReportFeature.State?

        // Productivity Insights
        var peakHourRange: String = ""
        var bestDayOfWeek: String = ""
        var sessionCompletionRate: Double = 0
        var avgInterruptions: Double = 0
        var focusQualityScore: Int = 0

        enum Period: String, CaseIterable, Equatable {
            case week  = "7D"
            case month = "30D"
            case year  = "Year"

            var displayName: String {
                switch self {
                case .week:  return String(localized: "7D")
                case .month: return String(localized: "30D")
                case .year:  return String(localized: "Year")
                }
            }

            var days: Int {
                switch self {
                case .week:  return 7
                case .month: return 30
                case .year:  return 364
                }
            }
        }

        /// One bar in the bar chart — represents a single day.
        struct DayPoint: Identifiable, Equatable {
            let id: Date
            let date: Date
            let totalMinutes: Int
            let pomodoroMinutes: Int
            let flowtimeMinutes: Int
            let timeBlockMinutes: Int
            let stopwatchMinutes: Int
            let sessionsCompleted: Int

            var label: String {
                let formatter = DateFormatter()
                formatter.dateFormat = "EEE"
                return formatter.string(from: date)
            }
        }

        /// Pie/donut chart slice for mode distribution.
        struct ModeShare: Identifiable, Equatable {
            let id: String
            let mode: FocusMode
            let minutes: Int
            let percentage: Double

            var label: String { "\(mode.displayName) \(Int(percentage * 100))%" }
        }
    }

    enum Action: Equatable {
        case onAppear
        case refresh
        case periodChanged(State.Period)
        case allDataLoaded(
            snapshots: [DayDataSnapshot],
            insights: ProductivityInsights,
            streakDays: Int,
            longestStreak: Int,
            streakProtectionApplied: Bool,
            achievements: [UserAchievement],
            weeklyInsights: [FocusInsight]
        )
        case loadFailed(String)
        case retryTapped
        case weeklyReviewTapped
        case weeklyReviewDismissed
        case weeklyReview(PresentationAction<WeeklyReviewFeature.Action>)
        case monthlyReviewTapped
        case monthlyReviewDismissed
        case monthlyReview(PresentationAction<MonthlyReviewFeature.Action>)
        case aiReportTapped(ReportPeriod)
        case aiReportDismissed
        case aiReport(PresentationAction<AIReportFeature.Action>)
        case paywallRequested
    }

    /// Value-type snapshot for transferring daily aggregated data across concurrency boundaries.
    struct DayDataSnapshot: Equatable, Sendable {
        let date: Date
        let totalFocusSeconds: Int
        let sessionsCompleted: Int
        let pomodoroSeconds: Int
        let flowtimeSeconds: Int
        let timeBlockSeconds: Int
        let stopwatchSeconds: Int
        let hadFocusSession: Bool
    }

    /// Computed productivity insights derived from raw session records.
    struct ProductivityInsights: Equatable, Sendable {
        var peakHourRange: String
        var bestDayOfWeek: String
        var sessionCompletionRate: Double  // 0.0–1.0
        var avgInterruptions: Double       // per session
        var focusQualityScore: Int         // 0–100

        static let empty = ProductivityInsights(
            peakHourRange: "",
            bestDayOfWeek: "",
            sessionCompletionRate: 0,
            avgInterruptions: 0,
            focusQualityScore: 0
        )
    }

    @Dependency(\.persistenceClient) var persistence

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {

            case .onAppear:
                guard !state.isLoading, !state.hasLoadedData else { return .none }
                state.isLoading = true
                return .merge(
                    loadData(for: state.period, isPro: state.isProUser),
                    .run { _ in _ = try? await CheckStatsIntent().donate() }
                )

            case .refresh:
                guard !state.isLoading else { return .none }
                state.isLoading = true
                return loadData(for: state.period, isPro: state.isProUser)

            case .periodChanged(let period):
                if !state.isProUser && period != .week {
                    return .send(.paywallRequested)
                }
                state.period = period
                state.isLoading = true
                return loadData(for: period, isPro: state.isProUser)

            case let .allDataLoaded(snapshots, insights, streakDays, longestStreak, streakProtectionApplied, achievements, weeklyInsights):
                state.isLoading = false
                state.hasLoadedData = true
                state.weeklyInsights = weeklyInsights

                // Build chart points (one per day, fill gaps with zeros)
                let calendar = Calendar.current
                let snapshotsByDay = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.date, $0) })
                var points: [State.DayPoint] = []

                for dayOffset in 0..<state.period.days {
                    guard let date = calendar.date(
                        byAdding: .day,
                        value: -(state.period.days - 1 - dayOffset),
                        to: calendar.startOfDay(for: Date.now)
                    ) else { continue }

                    let snap = snapshotsByDay[date]
                    points.append(State.DayPoint(
                        id: date,
                        date: date,
                        totalMinutes: (snap?.totalFocusSeconds ?? 0) / 60,
                        pomodoroMinutes: (snap?.pomodoroSeconds ?? 0) / 60,
                        flowtimeMinutes: (snap?.flowtimeSeconds ?? 0) / 60,
                        timeBlockMinutes: (snap?.timeBlockSeconds ?? 0) / 60,
                        stopwatchMinutes: (snap?.stopwatchSeconds ?? 0) / 60,
                        sessionsCompleted: snap?.sessionsCompleted ?? 0
                    ))
                }
                state.chartData = points

                // Totals
                state.totalFocusMinutes = snapshots.reduce(0) { $0 + $1.totalFocusSeconds } / 60
                state.sessionsCompleted = snapshots.reduce(0) { $0 + $1.sessionsCompleted }

                // Mode breakdown
                let pom   = snapshots.reduce(0) { $0 + $1.pomodoroSeconds }
                let flow  = snapshots.reduce(0) { $0 + $1.flowtimeSeconds }
                let block = snapshots.reduce(0) { $0 + $1.timeBlockSeconds }
                let sw    = snapshots.reduce(0) { $0 + $1.stopwatchSeconds }
                let total = max(1, pom + flow + block + sw)
                let t = Double(total)

                state.modeBreakdown = [
                    State.ModeShare(id: "pomodoro",  mode: .pomodoro,  minutes: pom / 60,   percentage: Double(pom)   / t),
                    State.ModeShare(id: "flowtime",  mode: .flowtime,  minutes: flow / 60,  percentage: Double(flow)  / t),
                    State.ModeShare(id: "timeBlock", mode: .timeBlock, minutes: block / 60, percentage: Double(block) / t),
                    State.ModeShare(id: "stopwatch", mode: .stopwatch, minutes: sw / 60,    percentage: Double(sw)    / t),
                ].filter { $0.minutes > 0 }

                state.dominantMode = state.modeBreakdown.max(by: { $0.minutes < $1.minutes })?.mode

                // Productivity Insights
                state.peakHourRange = insights.peakHourRange
                state.bestDayOfWeek = insights.bestDayOfWeek
                state.sessionCompletionRate = insights.sessionCompletionRate
                state.avgInterruptions = insights.avgInterruptions
                state.focusQualityScore = insights.focusQualityScore

                // Streaks & achievements
                state.currentStreakDays = streakDays
                state.longestStreakDays = longestStreak
                state.streakProtectionApplied = streakProtectionApplied
                state.achievements = achievements

                return .none

            case let .loadFailed(message):
                state.isLoading = false
                state.hasLoadedData = false
                state.loadError = message
                return .none

            case .retryTapped:
                state.loadError = nil
                state.isLoading = true
                return loadData(for: state.period, isPro: state.isProUser)

            case .weeklyReviewTapped:
                guard state.isProUser else { return .send(.paywallRequested) }
                state.weeklyReview = WeeklyReviewFeature.State()
                return .none

            case .weeklyReviewDismissed:
                state.weeklyReview = nil
                return .none

            case .weeklyReview:
                return .none

            case .monthlyReviewTapped:
                guard state.isProUser else { return .send(.paywallRequested) }
                state.monthlyReview = MonthlyReviewFeature.State()
                return .none

            case .monthlyReviewDismissed:
                state.monthlyReview = nil
                return .none

            case .monthlyReview:
                return .none

            case .aiReportTapped(let period):
                guard state.isProUser else { return .send(.paywallRequested) }
                state.aiReport = AIReportFeature.State(period: period)
                return .none

            case .aiReportDismissed:
                state.aiReport = nil
                return .none

            case .aiReport:
                return .none

            case .paywallRequested:
                return .none
            }
        }
        .ifLet(\.$weeklyReview, action: \.weeklyReview) {
            WeeklyReviewFeature()
        }
        .ifLet(\.$monthlyReview, action: \.monthlyReview) {
            MonthlyReviewFeature()
        }
        .ifLet(\.$aiReport, action: \.aiReport) {
            AIReportFeature()
        }
    }

    // MARK: - Data Loading

    private func loadData(for period: State.Period, isPro: Bool) -> Effect<Action> {
        .run { [persistence, isPro] send in
            let calendar = Calendar.current
            let end = Date.now
            guard let start = calendar.date(byAdding: .day, value: -(period.days - 1), to: end) else {
                await send(.allDataLoaded(snapshots: [], insights: .empty, streakDays: 0, longestStreak: 0, streakProtectionApplied: false, achievements: [], weeklyInsights: []))
                return
            }

            do {
                // Fetch concurrently: period sessions, preferences, all-time daily
                // stats for streak computation. Achievement counts use scoped SQLite
                // COUNTs instead of loading the entire FocusSessionRecord table
                // (issue #73). They are lifetime tallies, querying from
                // Date.distantPast — but the work happens in SQLite (SELECT COUNT +
                // predicate) instead of deserializing every row in Swift.
                async let periodSessionsFetch = persistence.fetchSessions(start, end)
                async let prefsFetch = persistence.fetchPreferences()
                async let allStatsFetch = persistence.fetchDailyStatsRange(Date.distantPast, end)
                async let earlyBirdCountFetch = persistence.fetchEarlyBirdSessionCount(Date.distantPast)
                async let pomodoroCompletedFetch = persistence.fetchCompletedPomodoroCount(Date.distantPast)
                async let flowtimeCompletedFetch = persistence.fetchCompletedFlowtimeCount(Date.distantPast)
                async let allTimeTotalFetch = persistence.fetchSessionCount(Date.distantPast)

                let (periodSessions, prefs, allDailyStats,
                     earlyBirdCount, pomodoroCompleted, flowtimeCompleted, allTimeTotal) = try await (
                    periodSessionsFetch,
                    prefsFetch,
                    allStatsFetch,
                    earlyBirdCountFetch,
                    pomodoroCompletedFetch,
                    flowtimeCompletedFetch,
                    allTimeTotalFetch
                )

                let snapshots = buildSnapshots(from: periodSessions, calendar: calendar)
                let insights = buildInsights(from: periodSessions, calendar: calendar)

                // Compute protected streak on-the-fly from full DailyStats history.
                let streakResult = StreakProtectionService.computeProtectedStreak(
                    history: allDailyStats,
                    isPro: isPro,
                    today: end,
                    calendar: calendar
                )

                // Seed the store on first load and overlay stored first-unlock
                // dates over recomputed `now` stamps (S1-S2).
                let achievements = try await persistence.resolveAchievements(
                    buildAchievements(
                        totalSessions: allTimeTotal,
                        currentStreak: streakResult.days,
                        pomodoroCompleted: pomodoroCompleted,
                        flowtimeCompleted: flowtimeCompleted,
                        earlyBirdCount: earlyBirdCount
                    )
                )

                // Generate weekly insights (C6)
                let insightsService = InsightsService()
                let dailyStatsDTOs = snapshots.map { snap in
                    DailyStatsDTO(
                        date: snap.date,
                        totalFocusMinutes: snap.totalFocusSeconds / 60,
                        sessionsCompleted: snap.sessionsCompleted,
                        tasksCompleted: 0
                    )
                }
                let weeklyInsights = insightsService.generateWeeklyInsights(
                    sessions: periodSessions,
                    dailyStats: dailyStatsDTOs,
                    periodDays: period.days
                )

                await send(.allDataLoaded(
                    snapshots: snapshots,
                    insights: insights,
                    streakDays: streakResult.days,
                    longestStreak: prefs.longestStreakDays,
                    streakProtectionApplied: streakResult.protectionApplied,
                    achievements: achievements,
                    weeklyInsights: weeklyInsights
                ))
            } catch {
                await send(.loadFailed(error.localizedDescription))
            }
        }
    }

    // MARK: - Private: Builders

    private func buildSnapshots(from sessions: [SessionRecordDTO], calendar: Calendar) -> [DayDataSnapshot] {
        var dailyData: [Date: (Int, Int, Int, Int, Int, Int, Bool)] = [:]
        // (totalSecs, sessions, pomSecs, flowSecs, blockSecs, swSecs, hadSession)

        for record in sessions {
            let day = calendar.startOfDay(for: record.startedAt)
            var (tot, ses, pom, flow, blk, sw, had) = dailyData[day] ?? (0, 0, 0, 0, 0, 0, false)
            let secs = Int(record.actualDuration)
            tot += secs; ses += 1; had = true
            switch FocusMode(rawValue: record.mode) {
            case .pomodoro:  pom += secs
            case .flowtime:  flow += secs
            case .timeBlock: blk += secs
            case .stopwatch: sw += secs
            case .none: break
            }
            dailyData[day] = (tot, ses, pom, flow, blk, sw, had)
        }

        return dailyData.map { date, data in
            DayDataSnapshot(
                date: date,
                totalFocusSeconds: data.0,
                sessionsCompleted: data.1,
                pomodoroSeconds:   data.2,
                flowtimeSeconds:   data.3,
                timeBlockSeconds:  data.4,
                stopwatchSeconds:  data.5,
                hadFocusSession:   data.6
            )
        }
    }

    private func buildInsights(from sessions: [SessionRecordDTO], calendar: Calendar) -> ProductivityInsights {
        guard !sessions.isEmpty else { return .empty }

        var hourBuckets = [Int: Double]()
        var weekdayBuckets = [Int: Double]()
        var completedCount = 0
        var totalInterruptions = 0

        for record in sessions {
            let hour = calendar.component(.hour, from: record.startedAt)
            hourBuckets[hour, default: 0] += record.actualDuration

            let weekday = calendar.component(.weekday, from: record.startedAt)
            weekdayBuckets[weekday, default: 0] += record.actualDuration

            if record.wasCompleted { completedCount += 1 }
            totalInterruptions += record.interruptions
        }

        let total = sessions.count
        let completionRate = Double(completedCount) / Double(total)
        let avgInterruptions = Double(totalInterruptions) / Double(total)

        // Peak 2-hour window around the hour with most focus time
        let peakHour = hourBuckets.max(by: { $0.value < $1.value })?.key ?? -1
        let peakHourRange: String
        if peakHour >= 0 {
            let endHour = (peakHour + 2) % 24
            let fmt = DateFormatter()
            fmt.dateFormat = "h a"
            var sc = DateComponents(); sc.hour = peakHour
            var ec = DateComponents(); ec.hour = endHour
            if let sd = calendar.date(from: sc), let ed = calendar.date(from: ec) {
                peakHourRange = "\(fmt.string(from: sd))–\(fmt.string(from: ed))"
            } else {
                peakHourRange = ""
            }
        } else {
            peakHourRange = ""
        }

        // Best weekday by total focus minutes
        let bestWeekday = weekdayBuckets.max(by: { $0.value < $1.value })?.key ?? 0
        let bestDayOfWeek = bestWeekday > 0 ? calendar.weekdaySymbols[bestWeekday - 1] : ""

        // Quality score: 60% completion weight + 40% low-interruption weight
        let interruptionFactor = min(avgInterruptions / 3.0, 1.0)
        let focusQualityScore = Int(completionRate * 60.0 + (1.0 - interruptionFactor) * 40.0)

        return ProductivityInsights(
            peakHourRange: peakHourRange,
            bestDayOfWeek: bestDayOfWeek,
            sessionCompletionRate: completionRate,
            avgInterruptions: avgInterruptions,
            focusQualityScore: focusQualityScore
        )
    }

    private func buildAchievements(
        totalSessions: Int,
        currentStreak: Int,
        pomodoroCompleted: Int,
        flowtimeCompleted: Int,
        earlyBirdCount: Int
    ) -> [UserAchievement] {
        Achievement.allCases.map { achievement in
            let progress: Int
            switch achievement {
            case .firstSession:
                progress = min(totalSessions, 1)
            case .weekStreak:
                progress = min(currentStreak, achievement.requiredCount)
            case .centuryClub:
                progress = min(totalSessions, achievement.requiredCount)
            case .pomodoroMaster:
                progress = min(pomodoroCompleted, achievement.requiredCount)
            case .deepDiver:
                progress = min(flowtimeCompleted, achievement.requiredCount)
            case .earlyBird:
                progress = min(earlyBirdCount, achievement.requiredCount)
            }
            return UserAchievement(
                achievement: achievement,
                unlockedAt: progress >= achievement.requiredCount ? Date.now : nil,
                progress: progress
            )
        }
    }
}
