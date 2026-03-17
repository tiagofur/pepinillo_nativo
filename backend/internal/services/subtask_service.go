package services

import (
	"context"

	"pepinillo/backend/internal/domain"
	"pepinillo/backend/internal/ports"
)

type SubTaskService struct {
	repo           ports.SubTaskRepository
	taskRepo       ports.TaskRepository
	behaviorLogger ports.BehaviorLogger
}

func NewSubTaskService(repo ports.SubTaskRepository, taskRepo ports.TaskRepository, behaviorLogger ports.BehaviorLogger) *SubTaskService {
	return &SubTaskService{repo: repo, taskRepo: taskRepo, behaviorLogger: behaviorLogger}
}

func (s *SubTaskService) verifyTaskOwnership(ctx context.Context, userID string, taskID int) error {
	task, err := s.taskRepo.GetByID(ctx, taskID)
	if err != nil {
		return err
	}
	if task == nil || task.UserID != userID {
		return ErrTaskNotFound
	}
	return nil
}

func (s *SubTaskService) Create(ctx context.Context, userID string, taskID int, subtask *domain.SubTask) error {
	if err := s.verifyTaskOwnership(ctx, userID, taskID); err != nil {
		return err
	}
	subtask.TaskID = taskID
	if err := s.repo.Create(ctx, subtask); err != nil {
		return err
	}
	_ = s.behaviorLogger.LogEvent(ctx, userID, "subtask_created", map[string]any{"taskId": taskID, "subtaskId": subtask.ID})
	return nil
}

func (s *SubTaskService) Update(ctx context.Context, userID string, taskID int, subtask *domain.SubTask) error {
	if err := s.verifyTaskOwnership(ctx, userID, taskID); err != nil {
		return err
	}
	subtask.TaskID = taskID
	if err := s.repo.Update(ctx, subtask); err != nil {
		return err
	}
	_ = s.behaviorLogger.LogEvent(ctx, userID, "subtask_updated", map[string]any{"taskId": taskID, "subtaskId": subtask.ID})
	return nil
}

func (s *SubTaskService) Delete(ctx context.Context, userID string, taskID int, subtaskID int) error {
	if err := s.verifyTaskOwnership(ctx, userID, taskID); err != nil {
		return err
	}
	if err := s.repo.Delete(ctx, taskID, subtaskID); err != nil {
		return err
	}
	_ = s.behaviorLogger.LogEvent(ctx, userID, "subtask_deleted", map[string]any{"taskId": taskID, "subtaskId": subtaskID})
	return nil
}

func (s *SubTaskService) ListByTask(ctx context.Context, userID string, taskID int) ([]domain.SubTask, error) {
	if err := s.verifyTaskOwnership(ctx, userID, taskID); err != nil {
		return nil, err
	}
	return s.repo.ListByTask(ctx, taskID)
}
