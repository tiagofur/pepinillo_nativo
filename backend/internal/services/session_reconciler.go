package services

import (
	"context"
	"log/slog"
	"time"

	"pepinillo/backend/internal/observability"
	"pepinillo/backend/internal/ports"
)

// SessionReconciler closes focus sessions that the client never ended (issue #550).
//
// Sessions can be left dangling with ended_at IS NULL when a client crashes mid
// session with no recovery path, the device is lost/uninstalled, or a client bug
// forgets to emit the final end event. Without reconciliation these rows pollute
// daily stats forever (RecomputeStatsForDates does not filter on ended_at).
//
// Policy (product decision, 2026-07-26):
//   - A session open longer than TTL (default 7 days) is considered stale.
//   - It is closed by setting ended_at = now() and updated_at = now().
//   - was_completed is NOT touched: a completed-but-untimestamped session keeps
//     was_completed=true; an abandoned one stays false (now queryable as abandoned).
//
// The reconciler is idempotent: running it twice in the same day finds no stale
// rows the second time (they were already closed). It must be run as a periodic
// background job; see cmd/api/main.go startSessionReconciler.
type SessionReconciler struct {
	focusRepo ports.FocusRepository
	ttl       time.Duration
	// now is overridable in tests; defaults to time.Now.
	now func() time.Time
}

// NewSessionReconciler builds a reconciler with the given TTL.
func NewSessionReconciler(focusRepo ports.FocusRepository, ttl time.Duration) *SessionReconciler {
	return &SessionReconciler{
		focusRepo: focusRepo,
		ttl:       ttl,
		now:       time.Now,
	}
}

// Run closes all stale sessions and recomputes the affected daily stats.
//
// Returns a summary of what was closed for observability. A failure to
// recompute stats for one user does NOT abort the whole run: the sessions are
// already closed, so the next run will recompute the affected dates if needed
// (RecomputeStatsForDates is itself idempotent).
func (r *SessionReconciler) Run(ctx context.Context) (ReconcileSummary, error) {
	closed, err := r.focusRepo.CloseStaleSessions(ctx, r.ttl)
	if err != nil {
		slog.Error("stale session reconciler: CloseStaleSessions failed", "error", err)
		observability.CaptureError(err, map[string]string{"stage": "stale_session_reconciler"})
		return ReconcileSummary{}, err
	}

	summary := ReconcileSummary{
		UsersAffected:   make(map[string]int),
		SessionsClosed:  len(closed),
		DatesRecomputed: make(map[string][]string),
	}

	if len(closed) == 0 {
		return summary, nil
	}

	// Group closed sessions by (userID, calendar day of started_at) — the day
	// that RecomputeStatsForDates re-derives ((started_at AT TIME ZONE 'UTC')::date)
	// — and recompute each affected date once.
	type userDay struct {
		userID string
		day    string
	}
	seen := make(map[userDay]struct{})

	for _, c := range closed {
		dayStr := c.StartedAt.UTC().Format("2006-01-02")
		key := userDay{c.UserID, dayStr}
		if _, ok := seen[key]; ok {
			continue
		}
		seen[key] = struct{}{}

		day, parseErr := time.Parse("2006-01-02", dayStr)
		if parseErr != nil {
			// Should be impossible — dayStr is freshly formatted. Log and skip.
			slog.Error("stale session reconciler: cannot parse day", "day", dayStr, "error", parseErr)
			continue
		}
		if err := r.focusRepo.RecomputeStatsForDates(ctx, c.UserID, []time.Time{day}); err != nil {
			// Don't abort the whole run: the session is closed, the next run will
			// retry the recompute. Log per-user and continue.
			slog.Error("stale session reconciler: RecomputeStatsForDates failed",
				"userId", c.UserID, "date", dayStr, "error", err)
			observability.CaptureError(err, map[string]string{
				"stage":  "stale_session_reconciler_recompute",
				"userId": c.UserID,
				"date":   dayStr,
			})
			continue
		}
		summary.UsersAffected[c.UserID]++
		summary.DatesRecomputed[c.UserID] = append(summary.DatesRecomputed[c.UserID], dayStr)
	}

	slog.Info("stale session reconciler completed",
		"closed", summary.SessionsClosed,
		"usersWithRecompute", len(summary.DatesRecomputed),
	)
	return summary, nil
}

// ReconcileSummary is returned by Run for observability/logging.
type ReconcileSummary struct {
	SessionsClosed int
	// UsersAffected maps userID → number of distinct recomputed days for that user.
	UsersAffected map[string]int
	// DatesRecomputed maps userID → list of "YYYY-MM-DD" days recomputed.
	DatesRecomputed map[string][]string
}
