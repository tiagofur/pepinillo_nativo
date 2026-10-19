package services

import (
	"context"
	"testing"

	"github.com/stretchr/testify/require"

	"pepinillo/backend/internal/adapters/behavior"
)

func TestUpdateTaskTrackingMode_RejectsUnknownMode(t *testing.T) {
	repo := &fakeSyncTaskRepository{}
	svc := NewTaskService(repo, behavior.NewNoopLogger(), nil)
	err := svc.UpdateTaskTrackingMode(context.Background(), "u1", 1, "turbo")
	require.ErrorIs(t, err, ErrInvalidTrackingMode)
}

func TestIncrementTaskCompletion_RejectsUnknownMode(t *testing.T) {
	repo := &fakeSyncTaskRepository{}
	svc := NewTaskService(repo, behavior.NewNoopLogger(), nil)
	err := svc.IncrementTaskCompletion(context.Background(), "u1", 1, "turbo")
	require.ErrorIs(t, err, ErrInvalidTrackingMode)
}
