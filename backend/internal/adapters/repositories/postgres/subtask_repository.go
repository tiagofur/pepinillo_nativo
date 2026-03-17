package postgres

import (
	"context"

	"gorm.io/gorm"

	"pepinillo/backend/internal/domain"
)

type SubTaskRepository struct {
	db *gorm.DB
}

func NewSubTaskRepository(db *gorm.DB) *SubTaskRepository {
	return &SubTaskRepository{db: db}
}

func (r *SubTaskRepository) Create(ctx context.Context, subtask *domain.SubTask) error {
	return r.db.WithContext(ctx).Create(subtask).Error
}

func (r *SubTaskRepository) Update(ctx context.Context, subtask *domain.SubTask) error {
	return r.db.WithContext(ctx).Save(subtask).Error
}

func (r *SubTaskRepository) Delete(ctx context.Context, taskID int, subtaskID int) error {
	return r.db.WithContext(ctx).
		Where("id = ? AND task_id = ?", subtaskID, taskID).
		Delete(&domain.SubTask{}).Error
}

func (r *SubTaskRepository) ListByTask(ctx context.Context, taskID int) ([]domain.SubTask, error) {
	var subtasks []domain.SubTask
	err := r.db.WithContext(ctx).Where("task_id = ?", taskID).Find(&subtasks).Error
	return subtasks, err
}
