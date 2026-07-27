package postgres

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"pepinillo/backend/internal/domain"
	"pepinillo/backend/internal/ports"
)

type FocusRepository struct {
	db *gorm.DB
}

func NewFocusRepository(db *gorm.DB) *FocusRepository {
	return &FocusRepository{db: db}
}

func (r *FocusRepository) GetConfig(ctx context.Context, userID string) (*domain.FocusConfig, error) {
	var cfg domain.FocusConfig
	err := r.db.WithContext(ctx).Where("user_id = ?", userID).First(&cfg).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &cfg, nil
}

func (r *FocusRepository) UpsertConfig(ctx context.Context, config *domain.FocusConfig) error {
	return r.db.WithContext(ctx).Save(config).Error
}

func (r *FocusRepository) UpsertStats(ctx context.Context, stats *domain.FocusStats) error {
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var existing domain.FocusStats
		err := tx.Where("user_id = ? AND date = ?", stats.UserID, stats.Date.Format("2006-01-02")).First(&existing).Error
		if err == nil {
			// Trusted lookup hit: use the server-assigned ID.
			stats.ID = existing.ID
		} else if errors.Is(err, gorm.ErrRecordNotFound) {
			// Lookup missed: never trust a client-supplied ID, force INSERT so
			// Save cannot overwrite another user's stats row by PK.
			stats.ID = 0
		} else {
			return err
		}
		return tx.Save(stats).Error
	})
}

func (r *FocusRepository) ListStatsByRange(ctx context.Context, userID string, from, to time.Time) ([]domain.FocusStats, error) {
	var stats []domain.FocusStats
	err := r.db.WithContext(ctx).
		Where("user_id = ? AND date BETWEEN ? AND ?", userID, from.Format("2006-01-02"), to.Format("2006-01-02")).
		Order("date ASC").
		Find(&stats).Error
	if err != nil {
		return nil, err
	}
	return stats, nil
}

func (r *FocusRepository) InsertSession(ctx context.Context, session *domain.FocusSession) error {
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		// IDOR guard: when the client supplies a session ID, verify any
		// existing row belongs to the same user before Save-by-PK.
		if session.ID != "" {
			var existing domain.FocusSession
			err := tx.Where("id = ?", session.ID).First(&existing).Error
			if err == nil && existing.UserID != session.UserID {
				return gorm.ErrRecordNotFound
			} else if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
				return err
			}
		}
		return tx.Save(session).Error
	})
}

func (r *FocusRepository) ListSessionsByTask(ctx context.Context, userID string, taskID int) ([]domain.FocusSession, error) {
	var sessions []domain.FocusSession
	err := r.db.WithContext(ctx).
		Where("user_id = ? AND task_id = ?", userID, taskID).
		Order("started_at DESC").
		Find(&sessions).Error
	if err != nil {
		return nil, err
	}
	return sessions, nil
}

func (r *FocusRepository) ListSessionsByRange(ctx context.Context, userID string, from, to time.Time) ([]domain.FocusSession, error) {
	var sessions []domain.FocusSession
	err := r.db.WithContext(ctx).
		Where("user_id = ? AND started_at BETWEEN ? AND ?", userID, from, to).
		Order("started_at DESC").
		Find(&sessions).Error
	if err != nil {
		return nil, err
	}
	return sessions, nil
}

func (r *FocusRepository) UpdateSession(ctx context.Context, session *domain.FocusSession) error {
	return r.db.WithContext(ctx).
		Model(&domain.FocusSession{}).
		Where("id = ? AND user_id = ?", session.ID, session.UserID).
		Updates(session).Error
}

func (r *FocusRepository) ListAllSessions(ctx context.Context, userID string) ([]domain.FocusSession, error) {
	var sessions []domain.FocusSession
	err := r.db.WithContext(ctx).
		Where("user_id = ?", userID).
		Order("started_at DESC").
		Find(&sessions).Error
	if err != nil {
		return nil, err
	}
	return r.enrichWithTaskSyncIDs(ctx, sessions)
}

// enrichWithTaskSyncIDs looks up the sync_id for each session's task_id and
// populates the transient TaskSyncID field so clients can resolve task links
// by UUID instead of server integer ID.
func (r *FocusRepository) enrichWithTaskSyncIDs(ctx context.Context, sessions []domain.FocusSession) ([]domain.FocusSession, error) {
	// Collect unique task IDs
	taskIDs := make(map[int]struct{})
	for _, s := range sessions {
		if s.TaskID != nil {
			taskIDs[*s.TaskID] = struct{}{}
		}
	}
	if len(taskIDs) == 0 {
		return sessions, nil
	}

	ids := make([]int, 0, len(taskIDs))
	for id := range taskIDs {
		ids = append(ids, id)
	}

	// Batch-fetch task sync IDs
	type taskSyncRow struct {
		ID     int
		SyncID string
	}
	var rows []taskSyncRow
	err := r.db.WithContext(ctx).
		Table("tasks").
		Select("id, sync_id").
		Where("id IN ?", ids).
		Find(&rows).Error
	if err != nil {
		return nil, fmt.Errorf("fetch task sync IDs: %w", err)
	}

	syncMap := make(map[int]string, len(rows))
	for _, row := range rows {
		syncMap[row.ID] = row.SyncID
	}

	// Populate TaskSyncID on each session
	for i := range sessions {
		if sessions[i].TaskID != nil {
			if syncID, ok := syncMap[*sessions[i].TaskID]; ok {
				sessions[i].TaskSyncID = &syncID
			}
		}
	}
	return sessions, nil
}

func (r *FocusRepository) ListSessionsByUserPaginated(ctx context.Context, userID string, cursor *ports.PaginationCursor, limit int) ([]domain.FocusSession, error) {
	sessions := make([]domain.FocusSession, 0)
	query := r.db.WithContext(ctx).
		Where("user_id = ?", userID)

	if cursor != nil {
		query = query.Where(
			"(updated_at > ? OR (updated_at = ? AND id > ?))",
			cursor.UpdatedAt, cursor.UpdatedAt, cursor.ID,
		)
	}

	err := query.
		Order("updated_at ASC, id ASC").
		Limit(limit).
		Find(&sessions).Error
	if err != nil {
		return nil, fmt.Errorf("list sessions paginated: %w", err)
	}
	return r.enrichWithTaskSyncIDs(ctx, sessions)
}

func (r *FocusRepository) GetStatsByDate(ctx context.Context, userID string, date time.Time) (*domain.FocusStats, error) {
	var stats domain.FocusStats
	err := r.db.WithContext(ctx).
		Where("user_id = ? AND date = ?", userID, date.Format("2006-01-02")).
		First(&stats).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &stats, nil
}

func (r *FocusRepository) GetTaskStats(ctx context.Context, userID string, taskID int) (*domain.TaskFocusStats, error) {
	var result domain.TaskFocusStats
	err := r.db.WithContext(ctx).Raw(`
		SELECT
			? AS task_id,
			COUNT(*) AS total_sessions,
			COUNT(*) FILTER (WHERE was_completed = true) AS completed_count,
			COALESCE(SUM(elapsed_seconds), 0) AS total_focus_seconds,
			COALESCE(SUM(total_pause_seconds), 0) AS total_pause_seconds,
			CASE WHEN COUNT(*) > 0 THEN COALESCE(SUM(elapsed_seconds), 0) / COUNT(*) ELSE 0 END AS average_focus
		FROM focus_sessions
		WHERE user_id = ? AND task_id = ?
	`, taskID, userID, taskID).Scan(&result).Error
	if err != nil {
		return nil, err
	}
	return &result, nil
}

func (r *FocusRepository) UpsertSessionBatch(ctx context.Context, sessions []domain.FocusSession) error {
	if len(sessions) == 0 {
		return nil
	}
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		// IDOR guard: callers (sync_service.SyncSessions / InitialUpload)
		// stamp every session with the authenticated user's ID, so the batch
		// is scoped to a single user. Collect that user ID and the set of
		// non-zero client-supplied IDs, then look up which of those IDs
		// actually belong to this user. Any ID that exists for a DIFFERENT
		// user must NOT take the ON CONFLICT DO UPDATE branch — otherwise an
		// attacker could overwrite a victim's row by submitting their id.
		var userID string
		idSet := make(map[string]struct{})
		for i := range sessions {
			if userID == "" {
				userID = sessions[i].UserID
			}
			if sessions[i].ID != "" {
				idSet[sessions[i].ID] = struct{}{}
			}
		}

		allowedIDs := make(map[string]struct{})
		if len(idSet) > 0 && userID != "" {
			ids := make([]string, 0, len(idSet))
			for id := range idSet {
				ids = append(ids, id)
			}
			var owned []string
			if err := tx.
				Model(&domain.FocusSession{}).
				Where("id IN ? AND user_id = ?", ids, userID).
				Pluck("id", &owned).Error; err != nil {
				return fmt.Errorf("upsert session batch idor pre-check: %w", err)
			}
			for _, id := range owned {
				allowedIDs[id] = struct{}{}
			}
		}

		filtered := dropForeignSessionIDs(sessions, allowedIDs)
		return tx.Clauses(clause.OnConflict{
			Columns: []clause.Column{{Name: "id"}},
			DoUpdates: clause.AssignmentColumns([]string{
				"ended_at", "duration_seconds", "elapsed_seconds",
				"was_completed", "pause_count", "total_pause_seconds",
				"interruptions", "pomodoro_number", "satisfaction_rating",
				"journal_note", "updated_at",
			}),
		}).Create(&filtered).Error
	})
}

// dropForeignSessionIDs returns a copy of sessions in which any session whose
// ID is non-empty AND not present in allowedIDs has its ID replaced with a
// freshly generated UUID so GORM INSERTs it as a genuinely new row (valid,
// unique primary key) instead of following the ON CONFLICT DO UPDATE branch
// (which would overwrite another user's existing row by primary key).
// Sessions with an empty ID (new rows) or whose ID is in allowedIDs (verified
// to belong to the caller) are passed through unchanged.
//
// Using uuid.NewString() (rather than clearing to "") is load-bearing:
// focus_sessions.id is VARCHAR(255) PRIMARY KEY with no DEFAULT and
// domain.FocusSession has no default tag or BeforeCreate hook, so an empty ID
// would collapse N rewritten rows onto a single id="" row (within-batch
// collision via ON CONFLICT) and could even let a later batch overwrite an
// earlier batch's id="" row while leaving the original user_id in place
// (cross-user data leak).
//
// This is a pure helper extracted for direct unit testing — the IDOR guard
// lives in the query that populates allowedIDs inside UpsertSessionBatch.
func dropForeignSessionIDs(sessions []domain.FocusSession, allowedIDs map[string]struct{}) []domain.FocusSession {
	out := make([]domain.FocusSession, len(sessions))
	copy(out, sessions)
	for i := range out {
		if out[i].ID == "" {
			continue
		}
		if _, ok := allowedIDs[out[i].ID]; ok {
			continue
		}
		slog.Warn("UpsertSessionBatch: dropping foreign session ID from batch (would overwrite another user's row); forcing INSERT as new row",
			"sessionId", out[i].ID, "userId", out[i].UserID)
		out[i].ID = uuid.NewString()
	}
	return out
}

func (r *FocusRepository) ListSessionsUpdatedSince(ctx context.Context, userID string, since time.Time) ([]domain.FocusSession, error) {
	var sessions []domain.FocusSession
	err := r.db.WithContext(ctx).
		Where("user_id = ? AND updated_at > ?", userID, since).
		Order("updated_at ASC").
		Find(&sessions).Error
	if err != nil {
		return nil, err
	}
	return r.enrichWithTaskSyncIDs(ctx, sessions)
}

func (r *FocusRepository) RecomputeStatsForDates(ctx context.Context, userID string, dates []time.Time) error {
	if len(dates) == 0 {
		return nil
	}

	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		for _, date := range dates {
			dateStr := date.Format("2006-01-02")

			var result struct {
				Count                 int
				Pomodoros             int
				PomodoroDuration      int
				Breaks                int
				BreakDuration         int
				Rests                 int
				RestDuration          int
				FlowtimeSeconds       int
				TimeblockSeconds      int
				StopwatchSeconds      int
				FlowtimeCount         int
				TimeblockCount        int
				StopwatchCount        int
				LongestSessionSeconds int
			}

			err := tx.Raw(`
				SELECT
					COUNT(*) AS count,
					COUNT(*) FILTER (WHERE mode = 'pomodoro' AND phase = 'work') AS pomodoros,
					COALESCE(SUM(elapsed_seconds) FILTER (WHERE mode = 'pomodoro' AND phase = 'work'), 0) AS pomodoro_duration,
					COUNT(*) FILTER (WHERE mode = 'pomodoro' AND phase IN ('short_break', 'break')) AS breaks,
					COALESCE(SUM(elapsed_seconds) FILTER (WHERE mode = 'pomodoro' AND phase IN ('short_break', 'break')), 0) AS break_duration,
					COUNT(*) FILTER (WHERE mode = 'pomodoro' AND phase = 'long_break') AS rests,
					COALESCE(SUM(elapsed_seconds) FILTER (WHERE mode = 'pomodoro' AND phase = 'long_break'), 0) AS rest_duration,
					COALESCE(SUM(elapsed_seconds) FILTER (WHERE mode = 'flowtime'), 0) AS flowtime_seconds,
					COALESCE(SUM(elapsed_seconds) FILTER (WHERE mode = 'timeblock'), 0) AS timeblock_seconds,
					COALESCE(SUM(elapsed_seconds) FILTER (WHERE mode = 'stopwatch'), 0) AS stopwatch_seconds,
					COUNT(*) FILTER (WHERE mode = 'flowtime') AS flowtime_count,
					COUNT(*) FILTER (WHERE mode = 'timeblock') AS timeblock_count,
					COUNT(*) FILTER (WHERE mode = 'stopwatch') AS stopwatch_count,
					COALESCE(MAX(elapsed_seconds), 0) AS longest_session_seconds
				FROM focus_sessions
				WHERE user_id = ? AND DATE(started_at) = ?
			`, userID, dateStr).Scan(&result).Error
			if err != nil {
				return err
			}

			// Find existing stats row for this date or create new
			var existing domain.FocusStats
			err = tx.Where("user_id = ? AND date = ?", userID, dateStr).First(&existing).Error
			if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
				return err
			}

			stats := domain.FocusStats{
				UserID:                userID,
				Date:                  date,
				Count:                 result.Count,
				Pomodoros:             result.Pomodoros,
				PomodoroDuration:      result.PomodoroDuration,
				Breaks:                result.Breaks,
				BreakDuration:         result.BreakDuration,
				Rests:                 result.Rests,
				RestDuration:          result.RestDuration,
				FlowtimeSeconds:       result.FlowtimeSeconds,
				TimeblockSeconds:      result.TimeblockSeconds,
				StopwatchSeconds:      result.StopwatchSeconds,
				FlowtimeCount:         result.FlowtimeCount,
				TimeblockCount:        result.TimeblockCount,
				StopwatchCount:        result.StopwatchCount,
				LongestSessionSeconds: result.LongestSessionSeconds,
			}

			if existing.ID != 0 {
				stats.ID = existing.ID
				stats.DailyGoal = existing.DailyGoal
				stats.DailyCompleted = existing.DailyCompleted
				stats.TasksCompleted = existing.TasksCompleted
			}

			if err := tx.Save(&stats).Error; err != nil {
				return err
			}
		}
		return nil
	})
}

// CloseStaleSessions closes focus sessions that have been left open longer than
// ttl (ended_at IS NULL AND started_at < now() - ttl), setting ended_at = now()
// and updated_at = now(). It does not touch was_completed — a session that was
// completed but never got its ended_at timestamp keeps was_completed=true, and a
// session abandoned by the client stays was_completed=false (now queryable as
// abandoned since ended_at is set). Returns one StaleSessionClosed per row so
// the caller can recompute the affected daily stats.
//
// Uses explicit SQL rather than gorm.Updates(struct) because the latter ignores
// zero-value fields and ended_at/updated_at are being set to non-zero values
// that must always be written.
func (r *FocusRepository) CloseStaleSessions(ctx context.Context, ttl time.Duration) ([]domain.StaleSessionClosed, error) {
	threshold := time.Now().Add(-ttl)

	rows, err := r.db.WithContext(ctx).Raw(`
		UPDATE focus_sessions
		SET ended_at = now(),
		    updated_at = now()
		WHERE ended_at IS NULL
		  AND started_at < ?
		RETURNING user_id, started_at
	`, threshold).Rows()
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []domain.StaleSessionClosed
	for rows.Next() {
		var c domain.StaleSessionClosed
		if err := rows.Scan(&c.UserID, &c.StartedAt); err != nil {
			return nil, err
		}
		result = append(result, c)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return result, nil
}
