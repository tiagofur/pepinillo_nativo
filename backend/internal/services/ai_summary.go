package services

// Issue #995: mechanical split of ai_service.go (verbatim moves, no
// behavior change). This file owns the data-gathering and summary-assembly
// seam the daily-tip/report/analyze pipelines share.

import (
	"context"
	"encoding/json"
	"time"

	"pepinillo/backend/internal/domain"
)

// ---------- helpers to gather user data ----------

func (s *AIService) gatherRecentStats(ctx context.Context, userID string, days int) ([]domain.PomodoroStats, error) {
	to := time.Now().UTC()
	from := to.AddDate(0, 0, -days)
	return s.pomodoroRepo.ListStatsByRange(ctx, userID, from, to)
}

func (s *AIService) gatherRecentSessions(ctx context.Context, userID string, days int) ([]domain.PomodoroSession, error) {
	to := time.Now().UTC()
	from := to.AddDate(0, 0, -days)
	return s.pomodoroRepo.ListSessionsByRange(ctx, userID, from, to)
}

func (s *AIService) gatherTasks(ctx context.Context, userID string) ([]domain.Task, error) {
	return s.taskRepo.ListByUser(ctx, userID)
}

type userDataSummary struct {
	TotalTasks       int            `json:"totalTasks"`
	CompletedTasks   int            `json:"completedTasks"`
	PendingTasks     int            `json:"pendingTasks"`
	OverdueTasks     int            `json:"overdueTasks"`
	Categories       map[string]int `json:"categories"`
	StatsWindow      int            `json:"statsWindowDays"`
	TotalPomodoros   int            `json:"totalPomodoros"`
	TotalFocusMin    int            `json:"totalFocusMinutes"`
	TotalBreaks      int            `json:"totalBreaks"`
	DaysWithActivity int            `json:"daysWithActivity"`
	AvgPomPerDay     float64        `json:"avgPomodorosPerDay"`
	SessionCount     int            `json:"sessionCount"`
	CompletedSess    int            `json:"completedSessions"`
	SessionHours     map[int]int    `json:"sessionsByHour"` // hour -> count
}

func (s *AIService) buildDataSummary(ctx context.Context, userID string, days int) (*userDataSummary, error) {
	tasks, err := s.gatherTasks(ctx, userID)
	if err != nil {
		return nil, err
	}
	stats, err := s.gatherRecentStats(ctx, userID, days)
	if err != nil {
		return nil, err
	}
	sessions, err := s.gatherRecentSessions(ctx, userID, days)
	if err != nil {
		return nil, err
	}

	now := time.Now().UTC()
	summary := &userDataSummary{
		Categories:   make(map[string]int),
		SessionHours: make(map[int]int),
		StatsWindow:  days,
	}

	// Task counting extracted to a pure seam (issue #989 round 1): overdue
	// resolves through the canonical due date with the legacy finishDate
	// fallback, testable without a database.
	summary.TotalTasks, summary.CompletedTasks, summary.PendingTasks, summary.OverdueTasks = countTaskStates(tasks, now, summary.Categories)

	for _, st := range stats {
		summary.TotalPomodoros += st.Pomodoros
		summary.TotalFocusMin += st.PomodoroDuration / 60
		summary.TotalBreaks += st.Breaks
		if st.Pomodoros > 0 {
			summary.DaysWithActivity++
		}
	}
	if summary.DaysWithActivity > 0 {
		summary.AvgPomPerDay = float64(summary.TotalPomodoros) / float64(summary.DaysWithActivity)
	}

	for _, sess := range sessions {
		summary.SessionCount++
		if sess.WasCompleted {
			summary.CompletedSess++
		}
		summary.SessionHours[sess.StartedAt.Hour()]++
	}

	return summary, nil
}

func summaryToPromptContext(s *userDataSummary) string {
	b, _ := json.MarshalIndent(s, "", "  ")
	return string(b)
}
