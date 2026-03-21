package postgres

import (
	"context"
	"errors"
	"time"

	"gorm.io/gorm"

	"pepinillo/backend/internal/domain"
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
			stats.ID = existing.ID
		}
		if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
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
	return r.db.WithContext(ctx).Save(session).Error
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
	return sessions, nil
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
