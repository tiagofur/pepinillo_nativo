package postgres

import (
	"context"
	"errors"
	"fmt"
	"time"

	"gorm.io/gorm"

	"pepinillo/backend/internal/domain"
	"pepinillo/backend/internal/ports"
)

type TaskRepository struct {
	db *gorm.DB
}

func NewTaskRepository(db *gorm.DB) *TaskRepository {
	return &TaskRepository{db: db}
}

func (r *TaskRepository) ListByUser(ctx context.Context, userID string) ([]domain.Task, error) {
	tasks := make([]domain.Task, 0)
	err := r.db.WithContext(ctx).
		Preload("SubTasks").
		Where("user_id = ?", userID).
		Order("updated_at DESC").
		Find(&tasks).Error
	if err != nil {
		return nil, err
	}
	return tasks, nil
}

func (r *TaskRepository) ListByUserPaginated(ctx context.Context, userID string, cursor *ports.PaginationCursor, limit int) ([]domain.Task, error) {
	tasks := make([]domain.Task, 0)
	query := r.db.WithContext(ctx).
		Preload("SubTasks").
		Where("user_id = ?", userID)

	if cursor != nil {
		query = query.Where(
			"(updated_at > ? OR (updated_at = ? AND CAST(id AS TEXT) > ?))",
			cursor.UpdatedAt, cursor.UpdatedAt, cursor.ID,
		)
	}

	err := query.
		Order("updated_at ASC, id ASC").
		Limit(limit).
		Find(&tasks).Error
	if err != nil {
		return nil, fmt.Errorf("list tasks paginated: %w", err)
	}
	return tasks, nil
}

func (r *TaskRepository) GetByID(ctx context.Context, taskID int) (*domain.Task, error) {
	var task domain.Task
	err := r.db.WithContext(ctx).First(&task, taskID).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &task, nil
}

func (r *TaskRepository) ListUsersWithRecurrenceTemplates(ctx context.Context) ([]string, error) {
	userIDs := make([]string, 0)
	err := r.db.WithContext(ctx).
		Model(&domain.Task{}).
		Distinct("user_id").
		Where("is_deleted = false AND recurring_template_id IS NULL AND COALESCE(recurrence_rule, '') <> ''").
		Pluck("user_id", &userIDs).Error
	if err != nil {
		return nil, err
	}
	return userIDs, nil
}

func (r *TaskRepository) TryAcquireRecurrenceLock(ctx context.Context, lockKey, ownerID string, expiresAt time.Time) (bool, error) {
	var acquiredOwner string
	err := r.db.WithContext(ctx).Raw(`
		INSERT INTO recurrence_generation_locks (lock_key, owner_id, expires_at, created_at, updated_at)
		VALUES (?, ?, ?, NOW(), NOW())
		ON CONFLICT (lock_key) DO UPDATE
		SET owner_id = EXCLUDED.owner_id,
		    expires_at = EXCLUDED.expires_at,
		    updated_at = NOW()
		WHERE recurrence_generation_locks.expires_at <= NOW()
		RETURNING owner_id
	`, lockKey, ownerID, expiresAt.UTC()).Scan(&acquiredOwner).Error
	if err != nil {
		return false, err
	}
	return acquiredOwner == ownerID, nil
}

func (r *TaskRepository) ReleaseRecurrenceLock(ctx context.Context, lockKey, ownerID string) error {
	return r.db.WithContext(ctx).Exec(`
		DELETE FROM recurrence_generation_locks
		WHERE lock_key = ? AND owner_id = ?
	`, lockKey, ownerID).Error
}

func (r *TaskRepository) ListByFinishDate(ctx context.Context, userID string, date time.Time) ([]domain.Task, error) {
	var tasks []domain.Task
	err := r.db.WithContext(ctx).
		Preload("SubTasks").
		Where("user_id = ? AND finish_date::date = ?", userID, date.Format("2006-01-02")).
		Order("updated_at DESC").
		Find(&tasks).Error
	if err != nil {
		return nil, err
	}
	return tasks, nil
}

func (r *TaskRepository) Upsert(ctx context.Context, task *domain.Task) error {
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		// IDOR guard: when the client supplies an ID, verify the existing row
		// belongs to the same user before allowing an UPDATE-by-PK via Save.
		if task.ID != 0 {
			var existing domain.Task
			err := tx.Where("id = ?", task.ID).First(&existing).Error
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return gorm.ErrRecordNotFound
			}
			if err != nil {
				return err
			}
			if existing.UserID != task.UserID {
				return gorm.ErrRecordNotFound
			}
		}
		if err := tx.Save(task).Error; err != nil {
			return err
		}
		// Only replace subtasks when the client explicitly provides them (non-nil slice).
		// A nil SubTasks means "not provided" — leave existing subtasks untouched.
		if task.SubTasks != nil {
			if err := tx.Where("task_id = ?", task.ID).Delete(&domain.SubTask{}).Error; err != nil {
				return err
			}
			for i := range task.SubTasks {
				task.SubTasks[i].TaskID = task.ID
			}
			if len(task.SubTasks) > 0 {
				if err := tx.Create(&task.SubTasks).Error; err != nil {
					return err
				}
			}
		}
		return nil
	})
}

func (r *TaskRepository) Delete(ctx context.Context, userID string, taskID int) error {
	return r.db.WithContext(ctx).
		Model(&domain.Task{}).
		Where("id = ? AND user_id = ?", taskID, userID).
		Updates(map[string]any{"is_deleted": true, "updated_at": time.Now().UTC()}).Error
}

func (r *TaskRepository) Sync(ctx context.Context, userID string, tasks []domain.Task, deletedSyncIDs []string, since *time.Time) ([]domain.Task, []string, time.Time, error) {
	now := time.Now().UTC()

	var serverTasks []domain.Task
	var tombstones []domain.Task

	err := r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		for i := range tasks {
			incoming := tasks[i]
			incoming.UserID = userID
			clientUpdatedAt := incoming.UpdatedAt
			if clientUpdatedAt.IsZero() {
				clientUpdatedAt = now
			}

			if incoming.SyncID == "" {
				// No sync id: force INSERT. Never trust a client-supplied ID,
				// which could overwrite another user's row via Save-by-PK.
				incoming.ID = 0
				incoming.UpdatedAt = now
				if err := tx.Save(&incoming).Error; err != nil {
					return err
				}
				continue
			}

			var existing domain.Task
			err := tx.Where("user_id = ? AND sync_id = ?", userID, incoming.SyncID).First(&existing).Error
			if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
				return err
			}

			if err == nil {
				if !shouldApplyClientUpdate(existing.UpdatedAt, clientUpdatedAt) {
					continue
				}
				incoming.ID = existing.ID
			} else {
				// Lookup missed: do NOT trust the client-supplied ID; force INSERT.
				incoming.ID = 0
			}

			incoming.UpdatedAt = now
			if err := tx.Save(&incoming).Error; err != nil {
				return err
			}
		}
		if len(deletedSyncIDs) > 0 {
			if err := tx.Model(&domain.Task{}).
				Where("user_id = ? AND sync_id IN ?", userID, deletedSyncIDs).
				Updates(map[string]any{"is_deleted": true, "updated_at": now}).Error; err != nil {
				return err
			}
		}

		// Query server tasks inside the transaction for consistency.
		query := tx.Where("user_id = ?", userID)
		if since != nil {
			query = query.Where("updated_at >= ?", since.UTC())
		}
		if err := query.Preload("SubTasks").Find(&serverTasks).Error; err != nil {
			return err
		}

		// Tombstones are also filtered by since to avoid unbounded growth.
		tombstoneQuery := tx.Select("sync_id").
			Where("user_id = ? AND is_deleted = true", userID)
		if since != nil {
			tombstoneQuery = tombstoneQuery.Where("updated_at >= ?", since.UTC())
		}
		return tombstoneQuery.Find(&tombstones).Error
	})
	if err != nil {
		return nil, nil, time.Time{}, err
	}

	deleted := make([]string, 0, len(tombstones))
	for _, task := range tombstones {
		if task.SyncID != "" {
			deleted = append(deleted, task.SyncID)
		}
	}

	return serverTasks, deleted, now, nil
}

func shouldApplyClientUpdate(existingUpdatedAt, clientUpdatedAt time.Time) bool {
	return !existingUpdatedAt.After(clientUpdatedAt)
}

func (r *TaskRepository) UpdateTrackingMode(ctx context.Context, userID string, taskID int, mode string) error {
	result := r.db.WithContext(ctx).Model(&domain.Task{}).
		Where("id = ? AND user_id = ?", taskID, userID).
		Update("tracking_mode", mode)
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}
	return nil
}

func (r *TaskRepository) IncrementCompletionCount(ctx context.Context, userID string, taskID int, mode string) error {
	var updateSQL string
	switch mode {
	case "pomodoro":
		updateSQL = "UPDATE tasks SET completed_pomodoros = completed_pomodoros + 1 WHERE id = ? AND user_id = ?"
	case "flowtime":
		updateSQL = "UPDATE tasks SET completed_flowtime_sessions = completed_flowtime_sessions + 1 WHERE id = ? AND user_id = ?"
	case "timeblock":
		updateSQL = "UPDATE tasks SET completed_timeblock_sessions = completed_timeblock_sessions + 1 WHERE id = ? AND user_id = ?"
	case "stopwatch":
		updateSQL = "UPDATE tasks SET completed_stopwatch_seconds = completed_stopwatch_seconds + 1 WHERE id = ? AND user_id = ?"
	default:
		return nil
	}
	result := r.db.WithContext(ctx).Exec(updateSQL, taskID, userID)
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}
	return nil
}

func (r *TaskRepository) IncrementFocusTime(ctx context.Context, userID string, taskID int, mode string, seconds int) error {
	var updateSQL string
	switch mode {
	case "pomodoro":
		updateSQL = "UPDATE tasks SET focused_seconds = focused_seconds + ?, focused_seconds_pomodoro = focused_seconds_pomodoro + ? WHERE id = ? AND user_id = ?"
	case "flowtime":
		updateSQL = "UPDATE tasks SET focused_seconds = focused_seconds + ?, focused_seconds_flowtime = focused_seconds_flowtime + ? WHERE id = ? AND user_id = ?"
	case "timeblock":
		updateSQL = "UPDATE tasks SET focused_seconds = focused_seconds + ?, focused_seconds_timeblock = focused_seconds_timeblock + ? WHERE id = ? AND user_id = ?"
	case "stopwatch":
		updateSQL = "UPDATE tasks SET focused_seconds = focused_seconds + ?, focused_seconds_stopwatch = focused_seconds_stopwatch + ? WHERE id = ? AND user_id = ?"
	default:
		return nil
	}
	result := r.db.WithContext(ctx).Exec(updateSQL, seconds, seconds, taskID, userID)
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}
	return nil
}

func (r *TaskRepository) SetActiveSession(ctx context.Context, userID string, taskID int, sessionID *string) error {
	result := r.db.WithContext(ctx).Model(&domain.Task{}).
		Where("id = ? AND user_id = ?", taskID, userID).
		Update("active_session_id", sessionID)
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}
	return nil
}
