package ports

import (
	"context"
	"time"

	"pepinillo/backend/internal/domain"
)

type UserRepository interface {
	Create(ctx context.Context, user *domain.User) error
	GetByID(ctx context.Context, userID string) (*domain.User, error)
	GetByEmail(ctx context.Context, email string) (*domain.User, error)
	Update(ctx context.Context, user *domain.User) error
	Delete(ctx context.Context, userID string) error
	MarkEmailVerified(ctx context.Context, userID string) error
	UpdateEmailPending(ctx context.Context, userID, newEmail string) error
	ConfirmEmailChange(ctx context.Context, userID, newEmail string) error
	RollbackEmailChange(ctx context.Context, userID string) error
}

type TaskRepository interface {
	GetByID(ctx context.Context, taskID int) (*domain.Task, error)
	ListByUser(ctx context.Context, userID string) ([]domain.Task, error)
	ListUsersWithRecurrenceTemplates(ctx context.Context) ([]string, error)
	TryAcquireRecurrenceLock(ctx context.Context, lockKey, ownerID string, expiresAt time.Time) (bool, error)
	ReleaseRecurrenceLock(ctx context.Context, lockKey, ownerID string) error
	ListByFinishDate(ctx context.Context, userID string, date time.Time) ([]domain.Task, error)
	Upsert(ctx context.Context, task *domain.Task) error
	Delete(ctx context.Context, userID string, taskID int) error
	Sync(ctx context.Context, userID string, tasks []domain.Task, deletedSyncIDs []string, since *time.Time) ([]domain.Task, []string, time.Time, error)
}

type SubTaskRepository interface {
	Create(ctx context.Context, subtask *domain.SubTask) error
	Update(ctx context.Context, subtask *domain.SubTask) error
	Delete(ctx context.Context, taskID int, subtaskID int) error
	ListByTask(ctx context.Context, taskID int) ([]domain.SubTask, error)
}

type PomodoroRepository interface {
	GetConfig(ctx context.Context, userID string) (*domain.PomodoroConfig, error)
	UpsertConfig(ctx context.Context, config *domain.PomodoroConfig) error
	UpsertStats(ctx context.Context, stats *domain.PomodoroStats) error
	ListStatsByRange(ctx context.Context, userID string, from, to time.Time) ([]domain.PomodoroStats, error)
	GetStatsByDate(ctx context.Context, userID string, date time.Time) (*domain.PomodoroStats, error)
	InsertSession(ctx context.Context, session *domain.PomodoroSession) error
	UpdateSession(ctx context.Context, session *domain.PomodoroSession) error
	ListAllSessions(ctx context.Context, userID string) ([]domain.PomodoroSession, error)
	ListSessionsByTask(ctx context.Context, userID string, taskID int) ([]domain.PomodoroSession, error)
	ListSessionsByRange(ctx context.Context, userID string, from, to time.Time) ([]domain.PomodoroSession, error)
	GetTaskStats(ctx context.Context, userID string, taskID int) (*domain.TaskPomodoroStats, error)
}

type AIInsightRepository interface {
	Create(ctx context.Context, insight *domain.AIInsight) error
	ListByUser(ctx context.Context, userID string, limit, offset int) ([]domain.AIInsight, error)
}

type DeviceTokenRepository interface {
	Upsert(ctx context.Context, token *domain.DeviceToken) error
	ListByUser(ctx context.Context, userID string) ([]domain.DeviceToken, error)
	DeleteByToken(ctx context.Context, userID, token string) error
}
