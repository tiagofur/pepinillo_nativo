package ports

import (
	"context"
	"time"

	"pepinillo/backend/internal/domain"
)

// PaginationCursor represents a cursor for keyset-based pagination.
type PaginationCursor struct {
	UpdatedAt time.Time
	ID        string
}

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

	// OAuth methods
	GetByGoogleID(ctx context.Context, googleID string) (*domain.User, error)
	GetByAppleID(ctx context.Context, appleID string) (*domain.User, error)
	LinkGoogleAccount(ctx context.Context, userID, googleID, email, name, picture string) error
	UnlinkGoogleAccount(ctx context.Context, userID string) error
	LinkAppleAccount(ctx context.Context, userID, appleID, email, name string) error
	UnlinkAppleAccount(ctx context.Context, userID string) error

	// AI Credits
	ConsumeAiCredit(ctx context.Context, userID string) (bool, error)
	RefreshAiCredits(ctx context.Context, userID string, amount int) error
}

// TaskSyncResult is the outcome of a task sync push. AppliedSyncIDs are the
// client rows the server accepted (or inserted); RejectedSyncIDs are the rows
// skipped because a newer server version existed (LWW). Clients must not
// mark rejected rows as synced until they have applied the server version
// returned in ServerTasks.
type TaskSyncResult struct {
	ServerTasks    []domain.Task
	DeletedSyncIDs []string
	AppliedSyncIDs []string
	RejectedSyncIDs []string
	SyncedAt       time.Time
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
	Sync(ctx context.Context, userID string, tasks []domain.Task, deletedSyncIDs []string, since *time.Time) (*TaskSyncResult, error)

	// Paginated listing for full sync
	ListByUserPaginated(ctx context.Context, userID string, cursor *PaginationCursor, limit int) ([]domain.Task, error)

	// Mode-specific tracking methods
	UpdateTrackingMode(ctx context.Context, userID string, taskID int, mode string) error
	IncrementCompletionCount(ctx context.Context, userID string, taskID int, mode string) error
	IncrementFocusTime(ctx context.Context, userID string, taskID int, mode string, seconds int) error
	SetActiveSession(ctx context.Context, userID string, taskID int, sessionID *string) error
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

type FocusRepository interface {
	GetConfig(ctx context.Context, userID string) (*domain.FocusConfig, error)
	UpsertConfig(ctx context.Context, config *domain.FocusConfig) error
	UpsertStats(ctx context.Context, stats *domain.FocusStats) error
	ListStatsByRange(ctx context.Context, userID string, from, to time.Time) ([]domain.FocusStats, error)
	GetStatsByDate(ctx context.Context, userID string, date time.Time) (*domain.FocusStats, error)
	InsertSession(ctx context.Context, session *domain.FocusSession) error
	UpdateSession(ctx context.Context, session *domain.FocusSession) error
	ListAllSessions(ctx context.Context, userID string) ([]domain.FocusSession, error)
	ListSessionsByTask(ctx context.Context, userID string, taskID int) ([]domain.FocusSession, error)
	ListSessionsByRange(ctx context.Context, userID string, from, to time.Time) ([]domain.FocusSession, error)
	GetTaskStats(ctx context.Context, userID string, taskID int) (*domain.TaskFocusStats, error)

	// Paginated listing for full sync
	ListSessionsByUserPaginated(ctx context.Context, userID string, cursor *PaginationCursor, limit int) ([]domain.FocusSession, error)

	// Cheap existence check for the merge-decision flow (GET /sync/has-data).
	CountSessionsByUser(ctx context.Context, userID string) (int64, error)

	// Sync methods
	UpsertSessionBatch(ctx context.Context, sessions []domain.FocusSession) error
	ListSessionsUpdatedSince(ctx context.Context, userID string, since time.Time) ([]domain.FocusSession, error)
	RecomputeStatsForDates(ctx context.Context, userID string, dates []time.Time) error

	// CloseStaleSessions closes focus sessions left open beyond ttl (issue #550):
	// rows with ended_at IS NULL AND started_at < now() - ttl are updated to
	// ended_at = now() and updated_at = now(), without touching was_completed.
	// Returns one StaleSessionClosed per affected row so the caller can group by
	// (user, day-of-started_at) and recompute the affected daily stats.
	CloseStaleSessions(ctx context.Context, ttl time.Duration) ([]domain.StaleSessionClosed, error)
}

type AnalyticsRepository interface {
	GenerateWeeklyReport(ctx context.Context, userID string, weekStart, weekEnd time.Time) (*domain.WeeklyReport, error)
	GenerateMonthlyReport(ctx context.Context, userID string, monthStart, monthEnd time.Time) (*domain.MonthlyReport, error)
	GetCompletionRate(ctx context.Context, userID string, periodStart, periodEnd time.Time) (*domain.CompletionRateStats, error)
	GetStreakStats(ctx context.Context, userID string) (*domain.StreakStats, error)
}

type PreferenceRepository interface {
	GetByUser(ctx context.Context, userID string) ([]domain.UserPreference, error)
	UpsertBatch(ctx context.Context, prefs []domain.UserPreference) ([]domain.UserPreference, error)
}
