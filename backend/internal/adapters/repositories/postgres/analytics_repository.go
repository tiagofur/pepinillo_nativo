package postgres

import (
	"context"
	"time"

	"gorm.io/gorm"

	"pepinillo/backend/internal/domain"
)

type AnalyticsRepository struct {
	db *gorm.DB
}

func NewAnalyticsRepository(db *gorm.DB) *AnalyticsRepository {
	return &AnalyticsRepository{db: db}
}

func (r *AnalyticsRepository) GenerateWeeklyReport(ctx context.Context, userID string, weekStart, weekEnd time.Time) (*domain.WeeklyReport, error) {
	report := &domain.WeeklyReport{
		UserID:    userID,
		WeekStart: weekStart,
		WeekEnd:   weekEnd,
	}

	var stats struct {
		TotalFocusTime int
		TotalSessions  int
		TasksCompleted int
		TasksCreated   int
	}

	err := r.db.WithContext(ctx).Model(&domain.FocusSession{}).
		Select("COALESCE(SUM(elapsed_seconds), 0) as total_focus_time, COUNT(*) as total_sessions").
		Where("user_id = ? AND started_at BETWEEN ? AND ?", userID, weekStart, weekEnd).
		Scan(&stats).Error
	if err != nil {
		return nil, err
	}

	report.TotalFocusTime = stats.TotalFocusTime
	report.TotalSessions = stats.TotalSessions

	// Mode-specific stats
	report.PomodoroStats = r.getModeStats(ctx, userID, "pomodoro", weekStart, weekEnd)
	report.FlowtimeStats = r.getModeStats(ctx, userID, "flowtime", weekStart, weekEnd)
	report.TimeblockStats = r.getModeStats(ctx, userID, "timeblock", weekStart, weekEnd)
	report.StopwatchStats = r.getModeStats(ctx, userID, "stopwatch", weekStart, weekEnd)

	// Task stats
	err = r.db.WithContext(ctx).Model(&domain.Task{}).
		Select("COUNT(*) FILTER (WHERE is_finished = true) as tasks_completed, COUNT(*) as tasks_created").
		Where("user_id = ? AND updated_at BETWEEN ? AND ?", userID, weekStart, weekEnd).
		Scan(&stats).Error
	if err != nil {
		return nil, err
	}

	report.TasksCompleted = stats.TasksCompleted
	report.TasksCreated = stats.TasksCreated

	// Top tasks
	report.TopTasks = r.getTopTasks(ctx, userID, weekStart, weekEnd, 5)

	// Best day of week
	bestDay := r.getBestDayOfWeek(ctx, userID, weekStart, weekEnd)
	report.BestDayOfWeek = bestDay

	// Average focus time
	if report.TotalSessions > 0 {
		report.AverageFocusTime = report.TotalFocusTime / report.TotalSessions
	}

	// Current streak
	streak, err := r.getCurrentStreak(ctx, userID)
	if err == nil {
		report.Streak = streak.CurrentStreak
	}

	return report, nil
}

func (r *AnalyticsRepository) GenerateMonthlyReport(ctx context.Context, userID string, monthStart, monthEnd time.Time) (*domain.MonthlyReport, error) {
	report := &domain.MonthlyReport{
		UserID:     userID,
		MonthStart: monthStart,
		MonthEnd:   monthEnd,
	}

	var stats struct {
		TotalFocusTime int
		TotalSessions  int
		TasksCompleted int
		TasksCreated   int
	}

	err := r.db.WithContext(ctx).Model(&domain.FocusSession{}).
		Select("COALESCE(SUM(elapsed_seconds), 0) as total_focus_time, COUNT(*) as total_sessions").
		Where("user_id = ? AND started_at BETWEEN ? AND ?", userID, monthStart, monthEnd).
		Scan(&stats).Error
	if err != nil {
		return nil, err
	}

	report.TotalFocusTime = stats.TotalFocusTime
	report.TotalSessions = stats.TotalSessions

	// Mode-specific stats
	report.PomodoroStats = r.getModeStats(ctx, userID, "pomodoro", monthStart, monthEnd)
	report.FlowtimeStats = r.getModeStats(ctx, userID, "flowtime", monthStart, monthEnd)
	report.TimeblockStats = r.getModeStats(ctx, userID, "timeblock", monthStart, monthEnd)
	report.StopwatchStats = r.getModeStats(ctx, userID, "stopwatch", monthStart, monthEnd)

	// Task stats
	err = r.db.WithContext(ctx).Model(&domain.Task{}).
		Select("COUNT(*) FILTER (WHERE is_finished = true) as tasks_completed, COUNT(*) as tasks_created").
		Where("user_id = ? AND updated_at BETWEEN ? AND ?", userID, monthStart, monthEnd).
		Scan(&stats).Error
	if err != nil {
		return nil, err
	}

	report.TasksCompleted = stats.TasksCompleted
	report.TasksCreated = stats.TasksCreated

	// Top tasks
	report.TopTasks = r.getTopTasks(ctx, userID, monthStart, monthEnd, 10)

	// Best day of month
	bestDay := r.getBestDayOfMonth(ctx, userID, monthStart, monthEnd)
	report.BestDayOfMonth = bestDay

	// Average focus time
	if report.TotalSessions > 0 {
		report.AverageFocusTime = report.TotalFocusTime / report.TotalSessions
	}

	// Longest streak
	streak, err := r.getLongestStreak(ctx, userID)
	if err == nil {
		report.LongestStreak = streak.LongestStreak
	}

	return report, nil
}

func (r *AnalyticsRepository) GetCompletionRate(ctx context.Context, userID string, periodStart, periodEnd time.Time) (*domain.CompletionRateStats, error) {
	stats := &domain.CompletionRateStats{
		UserID:      userID,
		PeriodStart: periodStart,
		PeriodEnd:   periodEnd,
	}

	var totalStats struct {
		TotalSessions     int
		CompletedSessions int
	}

	err := r.db.WithContext(ctx).Model(&domain.FocusSession{}).
		Select("COUNT(*) as total_sessions, COUNT(*) FILTER (WHERE was_completed = true) as completed_sessions").
		Where("user_id = ? AND started_at BETWEEN ? AND ?", userID, periodStart, periodEnd).
		Scan(&totalStats).Error
	if err != nil {
		return nil, err
	}

	stats.TotalSessions = totalStats.TotalSessions
	stats.CompletedSessions = totalStats.CompletedSessions
	stats.AbandonedSessions = totalStats.TotalSessions - totalStats.CompletedSessions

	if stats.TotalSessions > 0 {
		stats.CompletionRate = float64(stats.CompletedSessions) / float64(stats.TotalSessions) * 100
	}

	// Mode-specific completion rates
	stats.PomodoroRate = r.getModeCompletionRate(ctx, userID, "pomodoro", periodStart, periodEnd)
	stats.FlowtimeRate = r.getModeCompletionRate(ctx, userID, "flowtime", periodStart, periodEnd)
	stats.TimeblockRate = r.getModeCompletionRate(ctx, userID, "timeblock", periodStart, periodEnd)

	// Abandoned by mode
	stats.AbandonedByMode = r.getAbandonedByMode(ctx, userID, periodStart, periodEnd)

	return stats, nil
}

func (r *AnalyticsRepository) GetStreakStats(ctx context.Context, userID string) (*domain.StreakStats, error) {
	current, err := r.getCurrentStreak(ctx, userID)
	if err != nil {
		return nil, err
	}

	longest, err := r.getLongestStreak(ctx, userID)
	if err != nil {
		return nil, err
	}

	return &domain.StreakStats{
		UserID:           userID,
		CurrentStreak:    current.CurrentStreak,
		LongestStreak:    longest.LongestStreak,
		LastActivityDate: current.LastActivityDate,
		StreakStartDate:  current.StreakStartDate,
		PomodoroStreak:   current.PomodoroStreak,
		FlowtimeStreak:   current.FlowtimeStreak,
		TimeblockStreak:  current.TimeblockStreak,
		StopwatchStreak:  current.StopwatchStreak,
	}, nil
}

func (r *AnalyticsRepository) getModeStats(ctx context.Context, userID, mode string, start, end time.Time) domain.ModeStats {
	var stats struct {
		TotalTime    int
		SessionCount int
		Completed    int
	}

	r.db.WithContext(ctx).Model(&domain.FocusSession{}).
		Select("COALESCE(SUM(elapsed_seconds), 0) as total_time, COUNT(*) as session_count, COUNT(*) FILTER (WHERE was_completed = true) as completed").
		Where("user_id = ? AND mode = ? AND started_at BETWEEN ? AND ?", userID, mode, start, end).
		Scan(&stats)

	avgDuration := 0
	if stats.SessionCount > 0 {
		avgDuration = stats.TotalTime / stats.SessionCount
	}

	return domain.ModeStats{
		TotalTime:    stats.TotalTime,
		SessionCount: stats.SessionCount,
		Completed:    stats.Completed,
		AvgDuration:  avgDuration,
	}
}

func (r *AnalyticsRepository) getTopTasks(ctx context.Context, userID string, start, end time.Time, limit int) []domain.TaskStat {
	var taskStats []domain.TaskStat

	r.db.WithContext(ctx).Table("focus_sessions").
		Select("task_id, COUNT(*) as session_count, COALESCE(SUM(elapsed_seconds), 0) as focus_time").
		Where("user_id = ? AND task_id IS NOT NULL AND started_at BETWEEN ? AND ?", userID, start, end).
		Group("task_id").
		Order("focus_time DESC").
		Limit(limit).
		Find(&taskStats)

	// Get task titles
	for i := range taskStats {
		var task domain.Task
		r.db.WithContext(ctx).First(&task, taskStats[i].TaskID)
		if task.Title != nil {
			taskStats[i].TaskTitle = *task.Title
		}
		taskStats[i].Completed = task.IsFinished
	}

	return taskStats
}

func (r *AnalyticsRepository) getBestDayOfWeek(ctx context.Context, userID string, start, end time.Time) string {
	var result struct {
		DayOfWeek string
		TotalTime int
	}

	r.db.WithContext(ctx).Table("focus_sessions").
		Select("EXTRACT(DOW FROM started_at) as day_of_week, COALESCE(SUM(elapsed_seconds), 0) as total_time").
		Where("user_id = ? AND started_at BETWEEN ? AND ?", userID, start, end).
		Group("day_of_week").
		Order("total_time DESC").
		Scan(&result)

	return result.DayOfWeek
}

func (r *AnalyticsRepository) getBestDayOfMonth(ctx context.Context, userID string, start, end time.Time) string {
	var result struct {
		DayOfMonth string
		TotalTime  int
	}

	r.db.WithContext(ctx).Table("focus_sessions").
		Select("EXTRACT(DAY FROM started_at)::text as day_of_month, COALESCE(SUM(elapsed_seconds), 0) as total_time").
		Where("user_id = ? AND started_at BETWEEN ? AND ?", userID, start, end).
		Group("day_of_month").
		Order("total_time DESC").
		Scan(&result)

	return result.DayOfMonth
}

func (r *AnalyticsRepository) getCurrentStreak(ctx context.Context, userID string) (*domain.StreakStats, error) {
	type DailyActivity struct {
		Date   time.Time
		Active bool
	}

	var activities []DailyActivity
	r.db.WithContext(ctx).Raw(`
		SELECT date, COUNT(*) > 0 as active
		FROM (
			SELECT DATE(started_at) as date
			FROM focus_sessions
			WHERE user_id = ? AND started_at >= CURRENT_DATE - INTERVAL '30 days'
			UNION ALL
			SELECT DATE(updated_at) as date
			FROM tasks
			WHERE user_id = ? AND is_finished = true AND updated_at >= CURRENT_DATE - INTERVAL '30 days'
		) as dates
		GROUP BY date
		ORDER BY date DESC
	`, userID, userID).Scan(&activities)

	if len(activities) == 0 {
		return &domain.StreakStats{UserID: userID}, nil
	}

	streak := 0
	today := time.Now().Truncate(24 * time.Hour)

	for _, activity := range activities {
		if activity.Active {
			streak++
		} else {
			break
		}
	}

	return &domain.StreakStats{
		UserID:           userID,
		CurrentStreak:    streak,
		LastActivityDate: activities[0].Date,
	}, nil
}

func (r *AnalyticsRepository) getLongestStreak(ctx context.Context, userID string) (*domain.StreakStats, error) {
	type StreakPeriod struct {
		StartDate time.Time
		EndDate   time.Time
	}

	var periods []StreakPeriod
	r.db.WithContext(ctx).Raw(`
		WITH dates AS (
			SELECT DISTINCT DATE(started_at) as date
			FROM focus_sessions
			WHERE user_id = ? AND started_at >= CURRENT_DATE - INTERVAL '90 days'
			UNION
			SELECT DISTINCT DATE(updated_at) as date
			FROM tasks
			WHERE user_id = ? AND is_finished = true AND updated_at >= CURRENT_DATE - INTERVAL '90 days'
			ORDER BY date
		),
		grouped AS (
			SELECT date, date - (SELECT MAX(date) FROM dates d2 WHERE d2.date < dates.date AND NOT EXISTS (SELECT 1 FROM dates d3 WHERE d3.date BETWEEN d2.date + 1 AND dates.date - 1)) as group_id
			FROM dates
		)
		SELECT MIN(date) as start_date, MAX(date) as end_date
		FROM grouped
		GROUP BY group_id
		ORDER BY (MAX(date) - MIN(date)) DESC
		LIMIT 1
	`, userID, userID).Scan(&periods)

	if len(periods) == 0 {
		return &domain.StreakStats{UserID: userID}, nil
	}

	duration := int(periods[0].EndDate.Sub(periods[0].StartDate).Hours() / 24)

	return &domain.StreakStats{
		UserID:          userID,
		LongestStreak:   duration,
		StreakStartDate: periods[0].StartDate,
	}, nil
}

func (r *AnalyticsRepository) getModeCompletionRate(ctx context.Context, userID, mode string, start, end time.Time) float64 {
	var stats struct {
		TotalSessions     int
		CompletedSessions int
	}

	r.db.WithContext(ctx).Model(&domain.FocusSession{}).
		Select("COUNT(*) as total_sessions, COUNT(*) FILTER (WHERE was_completed = true) as completed_sessions").
		Where("user_id = ? AND mode = ? AND started_at BETWEEN ? AND ?", userID, mode, start, end).
		Scan(&stats)

	if stats.TotalSessions == 0 {
		return 0
	}

	return float64(stats.CompletedSessions) / float64(stats.TotalSessions) * 100
}

func (r *AnalyticsRepository) getAbandonedByMode(ctx context.Context, userID string, start, end time.Time) map[string]int {
	var results []struct {
		Mode  string
		Count int
	}

	r.db.WithContext(ctx).Model(&domain.FocusSession{}).
		Select("mode, COUNT(*) as count").
		Where("user_id = ? AND was_completed = false AND started_at BETWEEN ? AND ?", userID, start, end).
		Group("mode").
		Scan(&results)

	abandonedByMode := make(map[string]int)
	for _, result := range results {
		abandonedByMode[result.Mode] = result.Count
	}

	return abandonedByMode
}
