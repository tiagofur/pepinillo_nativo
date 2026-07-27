package services

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"pepinillo/backend/internal/domain"
)

// newReconciler builds a SessionReconciler wired to a fresh fake repo, returning
// both so tests can assert on the recorded interactions. TTL is arbitrary here —
// the fake returns whatever closeStaleResult is configured, so the TTL is only
// asserted to be forwarded.
func newReconciler(t *testing.T, ttl time.Duration) (*SessionReconciler, *fakeFocusRepository) {
	t.Helper()
	fake := &fakeFocusRepository{}
	return NewSessionReconciler(fake, ttl), fake
}

func TestSessionReconciler_NoStaleSessions(t *testing.T) {
	reconciler, fake := newReconciler(t, 168*time.Hour)

	summary, err := reconciler.Run(context.Background())

	require.NoError(t, err)
	assert.Equal(t, 0, summary.SessionsClosed)
	assert.Empty(t, summary.DatesRecomputed)
	assert.Empty(t, fake.recomputedDates, "RecomputeStatsForDates must not run when nothing was closed")
	// TTL must still be forwarded to the repo even when there's no work.
	assert.Equal(t, 168*time.Hour, fake.closeStaleTTLDur)
}

func TestSessionReconciler_SingleStaleSession(t *testing.T) {
	reconciler, fake := newReconciler(t, 168*time.Hour)
	started := time.Date(2026, 7, 20, 10, 0, 0, 0, time.UTC) // 7 days ago-ish
	fake.closeStaleResult = []domain.StaleSessionClosed{
		{UserID: "user-1", StartedAt: started},
	}

	summary, err := reconciler.Run(context.Background())

	require.NoError(t, err)
	assert.Equal(t, 1, summary.SessionsClosed)
	require.Len(t, fake.recomputedDates, 1)
	// The reconciler re-derives the day from the closed session's started_at
	// (DATE(started_at)) and recomputes at midnight of that calendar day — this
	// matches how RecomputeStatsForDates filters (DATE(started_at)).
	expectedDay := time.Date(2026, 7, 20, 0, 0, 0, 0, time.UTC)
	assert.True(t, fake.recomputedDates[0].Equal(expectedDay),
		"expected %v, got %v", expectedDay, fake.recomputedDates[0])
	assert.Equal(t, []string{"2026-07-20"}, summary.DatesRecomputed["user-1"])
}

func TestSessionReconciler_MultipleStaleSessionsSameDayDedup(t *testing.T) {
	// Two stale sessions for the same user, started the same calendar day.
	// RecomputeStatsForDates must run ONCE for that day (dedup).
	reconciler, fake := newReconciler(t, 168*time.Hour)
	day := time.Date(2026, 7, 20, 10, 0, 0, 0, time.UTC)
	fake.closeStaleResult = []domain.StaleSessionClosed{
		{UserID: "user-1", StartedAt: day},
		{UserID: "user-1", StartedAt: day.Add(2 * time.Hour)},
		{UserID: "user-1", StartedAt: day.Add(5 * time.Hour)},
	}

	summary, err := reconciler.Run(context.Background())

	require.NoError(t, err)
	assert.Equal(t, 3, summary.SessionsClosed)
	require.Len(t, fake.recomputedDates, 1, "same-day sessions must collapse to one recompute")
	assert.Equal(t, 1, summary.UsersAffected["user-1"])
}

func TestSessionReconciler_MultipleDaysAndUsers(t *testing.T) {
	reconciler, fake := newReconciler(t, 168*time.Hour)
	fake.closeStaleResult = []domain.StaleSessionClosed{
		{UserID: "user-1", StartedAt: time.Date(2026, 7, 19, 22, 0, 0, 0, time.UTC)},
		{UserID: "user-1", StartedAt: time.Date(2026, 7, 20, 9, 0, 0, 0, time.UTC)},
		{UserID: "user-2", StartedAt: time.Date(2026, 7, 20, 11, 0, 0, 0, time.UTC)},
	}

	summary, err := reconciler.Run(context.Background())

	require.NoError(t, err)
	assert.Equal(t, 3, summary.SessionsClosed)
	// user-1: 2 distinct days (07-19, 07-20); user-2: 1 day (07-20).
	require.Len(t, fake.recomputedDates, 3)
	assert.ElementsMatch(t, []string{"2026-07-19", "2026-07-20"}, summary.DatesRecomputed["user-1"])
	assert.ElementsMatch(t, []string{"2026-07-20"}, summary.DatesRecomputed["user-2"])
}

func TestSessionReconciler_RecomputeFailureDoesNotAbortRun(t *testing.T) {
	// If RecomputeStatsForDates fails for one user, the run must continue and
	// still recompute other users/days. Sessions are already closed by the repo.
	reconciler, fake := newReconciler(t, 168*time.Hour)
	fake.recomputeErr = errors.New("db connection lost")
	fake.closeStaleResult = []domain.StaleSessionClosed{
		{UserID: "user-1", StartedAt: time.Date(2026, 7, 20, 9, 0, 0, 0, time.UTC)},
		{UserID: "user-2", StartedAt: time.Date(2026, 7, 20, 11, 0, 0, 0, time.UTC)},
	}

	summary, err := reconciler.Run(context.Background())

	// No error at the Run level — per-user recompute failures are swallowed and
	// logged. The summary reflects that no dates were successfully recomputed.
	require.NoError(t, err)
	assert.Equal(t, 2, summary.SessionsClosed)
	assert.Empty(t, summary.DatesRecomputed, "failed recomputes must not be counted as recomputed")
}

func TestSessionReconciler_CloseStaleSessionsError(t *testing.T) {
	reconciler, fake := newReconciler(t, 168*time.Hour)
	fake.closeStaleErr = errors.New("connection refused")

	summary, err := reconciler.Run(context.Background())

	require.Error(t, err)
	assert.Equal(t, 0, summary.SessionsClosed)
	assert.Empty(t, fake.recomputedDates)
}

func TestSessionReconciler_TTLForwardedToRepo(t *testing.T) {
	// Confirms the configured TTL reaches the repo query (so the threshold is
	// now() - ttl inside CloseStaleSessions).
	reconciler, fake := newReconciler(t, 48*time.Hour)

	_, _ = reconciler.Run(context.Background())

	assert.Equal(t, 48*time.Hour, fake.closeStaleTTLDur)
}

func TestSessionReconciler_IsIdempotent(t *testing.T) {
	// Second run returns no new closed sessions (the repo returns empty because
	// they were already closed on the first run), so no recompute fires.
	reconciler, fake := newReconciler(t, 168*time.Hour)
	fake.closeStaleResult = []domain.StaleSessionClosed{
		{UserID: "user-1", StartedAt: time.Date(2026, 7, 20, 9, 0, 0, 0, time.UTC)},
	}

	first, err := reconciler.Run(context.Background())
	require.NoError(t, err)
	require.Equal(t, 1, first.SessionsClosed)
	require.Len(t, fake.recomputedDates, 1)

	// Simulate the repo finding nothing on the second pass.
	fake.closeStaleResult = nil
	fake.recomputedDates = nil

	second, err := reconciler.Run(context.Background())
	require.NoError(t, err)
	assert.Equal(t, 0, second.SessionsClosed)
	assert.Empty(t, fake.recomputedDates)
}
