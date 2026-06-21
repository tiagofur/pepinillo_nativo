package postgres

import (
	"context"
	"errors"
	"time"

	"gorm.io/gorm"

	"pepinillo/backend/internal/domain"
)

type PomodoroRepository struct {
	db *gorm.DB
}

func NewPomodoroRepository(db *gorm.DB) *PomodoroRepository {
	return &PomodoroRepository{db: db}
}

func (r *PomodoroRepository) GetConfig(ctx context.Context, userID string) (*domain.PomodoroConfig, error) {
	var cfg domain.PomodoroConfig
	err := r.db.WithContext(ctx).Where("user_id = ?", userID).First(&cfg).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &cfg, nil
}

func (r *PomodoroRepository) UpsertConfig(ctx context.Context, config *domain.PomodoroConfig) error {
	return r.db.WithContext(ctx).Save(config).Error
}

func (r *PomodoroRepository) UpsertStats(ctx context.Context, stats *domain.PomodoroStats) error {
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var existing domain.PomodoroStats
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

func (r *PomodoroRepository) ListStatsByRange(ctx context.Context, userID string, from, to time.Time) ([]domain.PomodoroStats, error) {
	var stats []domain.PomodoroStats
	err := r.db.WithContext(ctx).
		Where("user_id = ? AND date BETWEEN ? AND ?", userID, from.Format("2006-01-02"), to.Format("2006-01-02")).
		Order("date ASC").
		Find(&stats).Error
	if err != nil {
		return nil, err
	}
	return stats, nil
}

func (r *PomodoroRepository) InsertSession(ctx context.Context, session *domain.PomodoroSession) error {
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		// IDOR guard: when the client supplies a session ID, verify any
		// existing row belongs to the same user before Save-by-PK.
		if session.ID != "" {
			var existing domain.PomodoroSession
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

func (r *PomodoroRepository) ListSessionsByTask(ctx context.Context, userID string, taskID int) ([]domain.PomodoroSession, error) {
	var sessions []domain.PomodoroSession
	err := r.db.WithContext(ctx).
		Where("user_id = ? AND task_id = ?", userID, taskID).
		Order("started_at DESC").
		Find(&sessions).Error
	if err != nil {
		return nil, err
	}
	return sessions, nil
}

func (r *PomodoroRepository) ListSessionsByRange(ctx context.Context, userID string, from, to time.Time) ([]domain.PomodoroSession, error) {
	var sessions []domain.PomodoroSession
	err := r.db.WithContext(ctx).
		Where("user_id = ? AND started_at BETWEEN ? AND ?", userID, from, to).
		Order("started_at DESC").
		Find(&sessions).Error
	if err != nil {
		return nil, err
	}
	return sessions, nil
}

func (r *PomodoroRepository) UpdateSession(ctx context.Context, session *domain.PomodoroSession) error {
	return r.db.WithContext(ctx).
		Model(&domain.PomodoroSession{}).
		Where("id = ? AND user_id = ?", session.ID, session.UserID).
		Updates(session).Error
}

func (r *PomodoroRepository) ListAllSessions(ctx context.Context, userID string) ([]domain.PomodoroSession, error) {
	var sessions []domain.PomodoroSession
	err := r.db.WithContext(ctx).
		Where("user_id = ?", userID).
		Order("started_at DESC").
		Find(&sessions).Error
	if err != nil {
		return nil, err
	}
	return sessions, nil
}

func (r *PomodoroRepository) GetStatsByDate(ctx context.Context, userID string, date time.Time) (*domain.PomodoroStats, error) {
	var stats domain.PomodoroStats
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

func (r *PomodoroRepository) GetTaskStats(ctx context.Context, userID string, taskID int) (*domain.TaskPomodoroStats, error) {
	var result domain.TaskPomodoroStats
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
