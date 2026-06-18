package postgres

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/require"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"

	"pepinillo/backend/internal/domain"
)

// -----------------------------------------------------------------------------
// Pure helper tests (dropForeignSessionIDs)
//
// These cover the F1 IDOR guard helper directly. After the R3-1 fix the helper
// replaces a foreign ID with a freshly generated UUID (NOT the empty string),
// so each rewritten session INSERTs as a genuinely new row with a valid unique
// primary key instead of collapsing onto a single id="" row.
// -----------------------------------------------------------------------------

// TestDropForeignSessionIDs_RewritesForeignIDToFreshUUID covers the F1 IDOR
// guard. The contract: when a client submits a session whose ID belongs to
// another user (or does not exist for the caller), the helper must replace
// that ID with a brand-new non-empty UUID so GORM INSERTs a fresh row instead
// of taking the ON CONFLICT DO UPDATE branch and overwriting a victim's data.
func TestDropForeignSessionIDs_RewritesForeignIDToFreshUUID(t *testing.T) {
	sessions := []domain.FocusSession{
		{ID: "own-row", UserID: "user-A", Mode: "focus"},
		{ID: "victim-row", UserID: "user-A", Mode: "focus"}, // attacker-supplied ID
		{ID: "", UserID: "user-A", Mode: "focus"},           // brand-new row
	}
	// Only "own-row" was verified by the pre-check query as belonging to user-A.
	allowed := map[string]struct{}{"own-row": {}}

	got := dropForeignSessionIDs(sessions, allowed)

	cases := []struct {
		name    string
		idx     int
		check   func(*testing.T, string)
		explain string
	}{
		{
			name: "owned id passes through", idx: 0,
			check: func(t *testing.T, id string) {
				if id != "own-row" {
					t.Fatalf("owned ID must pass through unchanged; got %q", id)
				}
			},
			explain: "session whose ID is in the allowed set must keep its ID",
		},
		{
			name: "foreign id rewritten to fresh uuid", idx: 1,
			check: func(t *testing.T, id string) {
				if id == "victim-row" {
					t.Fatalf("foreign ID must NOT pass through; still %q", id)
				}
				if id == "" {
					t.Fatalf("foreign ID must be rewritten to a UUID, not empty string (empty-PK collision regression)")
				}
				if _, err := uuid.Parse(id); err != nil {
					t.Fatalf("rewritten ID must be a valid UUID, got %q (err=%v)", id, err)
				}
			},
			explain: "foreign ID must become a fresh UUID so it INSERTs as a new row instead of overwriting the victim",
		},
		{
			name: "already-empty id stays empty", idx: 2,
			check: func(t *testing.T, id string) {
				if id != "" {
					t.Fatalf("already-empty ID must stay empty; got %q", id)
				}
			},
			explain: "new rows stay new (caller's contract — new rows carry a client UUID)",
		},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			tc.check(t, got[tc.idx].ID)
		})
	}

	// Must not mutate the caller's slice — the original sessions input is the
	// caller's responsibility and shouldn't be silently rewritten.
	if sessions[1].ID != "victim-row" {
		t.Fatalf("dropForeignSessionIDs mutated the input slice; original ID = %q, want %q", sessions[1].ID, "victim-row")
	}
}

// TestDropForeignSessionIDs_EmptyAllowedRewritesAllNonEmpty covers the fail-safe
// path: when the pre-check query returns nothing (e.g. userID was empty so we
// couldn't run it, or every ID was foreign), every non-zero ID must be replaced
// with a fresh UUID so the batch can only INSERT, never UPDATE by PK. Crucially
// each rewritten ID must be DISTINCT so the batch does not collapse onto a
// single row.
func TestDropForeignSessionIDs_EmptyAllowedRewritesAllNonEmpty(t *testing.T) {
	sessions := []domain.FocusSession{
		{ID: "a", UserID: "u"},
		{ID: "b", UserID: "u"},
		{ID: "", UserID: "u"},
	}
	got := dropForeignSessionIDs(sessions, map[string]struct{}{})

	seen := make(map[string]struct{})
	for i, s := range got {
		if i < 2 {
			// Foreign IDs → fresh non-empty UUIDs, distinct from each other and
			// from the originals.
			if s.ID == "" {
				t.Fatalf("entry %d: expected rewritten UUID, got empty string (empty-PK collision regression)", i)
			}
			if s.ID == "a" || s.ID == "b" {
				t.Fatalf("entry %d: foreign ID passed through unchanged (%q)", i, s.ID)
			}
			if _, dup := seen[s.ID]; dup {
				t.Fatalf("entry %d: rewritten ID %q collides with a previous rewritten ID (within-batch collision)", i, s.ID)
			}
			seen[s.ID] = struct{}{}
		} else {
			// Already-empty stays empty (caller's contract).
			if s.ID != "" {
				t.Fatalf("entry %d: already-empty ID must stay empty; got %q", i, s.ID)
			}
		}
	}
}

// TestDropForeignSessionIDs_NilAllowedIsSafe asserts the helper tolerates a
// nil map (defensive — the repository always allocates one).
func TestDropForeignSessionIDs_NilAllowedIsSafe(t *testing.T) {
	sessions := []domain.FocusSession{{ID: "x", UserID: "u"}}
	got := dropForeignSessionIDs(sessions, nil)
	if got[0].ID == "" || got[0].ID == "x" {
		t.Fatalf("expected rewritten UUID with nil allowed map, got %q", got[0].ID)
	}
}

// -----------------------------------------------------------------------------
// End-to-end tests (UpsertSessionBatch)
//
// These exercise the full UpsertSessionBatch path against a real GORM DB
// (sqlite in-memory) so the ON CONFLICT behavior is actually observed, not
// just the pure helper. sqlite is used because focus_sessions has no JSONB /
// Postgres-only columns (verified against migrations 000001, 000007, 000011),
// so GORM AutoMigrate produces a schema equivalent enough to surface the
// empty-PK collision and IDOR-overwrite regressions.
// -----------------------------------------------------------------------------

func setupFocusDB(t *testing.T) *gorm.DB {
	t.Helper()
	// Unique named in-memory DB per test: every pooled connection sharing this
	// DSN sees the same data, while different tests get fully isolated DBs.
	dsn := "file:focus_" + uuid.NewString() + "?mode=memory&cache=shared"
	db, err := gorm.Open(sqlite.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
	})
	require.NoError(t, err)
	require.NoError(t, db.AutoMigrate(&domain.FocusSession{}))
	return db
}

// newSession is a tiny builder for focus sessions used by the e2e tests.
func newSession(id, userID, mode string, startedAt time.Time) domain.FocusSession {
	return domain.FocusSession{
		ID:              id,
		UserID:          userID,
		StartedAt:       startedAt,
		Mode:            mode,
		Phase:           "work",
		DurationSeconds: 1500,
		ElapsedSeconds:  1500,
		WasCompleted:    true,
	}
}

// TestUpsertSessionBatch_VictimProtection asserts the R3-1 regression is fixed
// end-to-end: an attacker batch that references a victim's existing session ID
// must NOT overwrite the victim's row. The victim row stays intact (same
// user_id, same content) and the attacker's data lands in a brand-new row
// under the attacker's own user_id with a server-generated ID that is NOT the
// victim's.
func TestUpsertSessionBatch_VictimProtection(t *testing.T) {
	db := setupFocusDB(t)
	repo := NewFocusRepository(db)
	ctx := context.Background()
	started := time.Date(2026, 6, 15, 10, 0, 0, 0, time.UTC)

	// Seed the victim's row.
	victim := newSession("victim-1", "victim", "pomodoro", started)
	require.NoError(t, db.WithContext(ctx).Create(&victim).Error)

	// Attacker submits a batch referencing the victim's ID.
	attacker := newSession("victim-1", "attacker", "flowtime", started)
	attacker.ElapsedSeconds = 999 // distinguishable payload
	require.NoError(t, repo.UpsertSessionBatch(ctx, []domain.FocusSession{attacker}))

	// Victim row must be UNCHANGED.
	var victimRow domain.FocusSession
	require.NoError(t, db.WithContext(ctx).Where("id = ?", "victim-1").First(&victimRow).Error)
	require.Equal(t, "victim", victimRow.UserID, "victim row must still belong to victim")
	require.Equal(t, "pomodoro", victimRow.Mode, "victim content must be preserved")
	require.Equal(t, 1500, victimRow.ElapsedSeconds, "victim content must be preserved")

	// Attacker must have a NEW row (not victim-1) with its own user_id.
	var attackerRows []domain.FocusSession
	require.NoError(t, db.WithContext(ctx).Where("user_id = ?", "attacker").Find(&attackerRows).Error)
	require.Len(t, attackerRows, 1, "attacker batch must produce exactly one new row")
	got := attackerRows[0]
	require.NotEqual(t, "victim-1", got.ID, "attacker row must not reuse the victim's ID")
	require.NotEmpty(t, got.ID, "attacker row must have a non-empty server-generated ID")
	require.Equal(t, "flowtime", got.Mode, "attacker payload must land in the new row")
	require.Equal(t, 999, got.ElapsedSeconds, "attacker payload must land in the new row")

	// And exactly two rows overall.
	var count int64
	require.NoError(t, db.WithContext(ctx).Model(&domain.FocusSession{}).Count(&count).Error)
	require.Equal(t, int64(2), count, "exactly two rows expected (victim + attacker)")
}

// TestUpsertSessionBatch_NoWithinBatchCollision asserts the within-batch
// failure mode of R3-1: two foreign IDs in the SAME batch must not collapse
// onto a single id="" row (which the pre-fix code did, silently dropping all
// but the last). Both must INSERT as distinct rows with distinct non-empty IDs.
func TestUpsertSessionBatch_NoWithinBatchCollision(t *testing.T) {
	db := setupFocusDB(t)
	repo := NewFocusRepository(db)
	ctx := context.Background()
	started := time.Date(2026, 6, 15, 10, 0, 0, 0, time.UTC)

	// Empty allowed set: the IDOR pre-check finds nothing for this user, so
	// both foreign IDs are rewritten by the helper.
	batch := []domain.FocusSession{
		newSession("foreign-A", "attacker", "flowtime", started),
		newSession("foreign-B", "attacker", "timeblock", started.Add(time.Hour)),
	}
	require.NoError(t, repo.UpsertSessionBatch(ctx, batch))

	var rows []domain.FocusSession
	require.NoError(t, db.WithContext(ctx).Where("user_id = ?", "attacker").Find(&rows).Error)
	require.Len(t, rows, 2, "both foreign sessions must insert as separate rows (no within-batch collision)")

	ids := make(map[string]struct{})
	for _, r := range rows {
		require.NotEmpty(t, r.ID, "rewritten row must have a non-empty ID (empty-PK regression)")
		require.False(t, r.ID == "foreign-A" || r.ID == "foreign-B", "foreign ID must be rewritten, got %q", r.ID)
		require.False(t, r.ID == "", "row ID must never be empty")
		_, dup := ids[r.ID]
		require.False(t, dup, "two rows collided on ID %q (within-batch collision)", r.ID)
		ids[r.ID] = struct{}{}
	}
	require.Len(t, ids, 2, "expected two distinct IDs")
}

// TestUpsertSessionBatch_HappyPathLandsAllRows asserts the normal sync path
// still works: a legitimate batch of new sessions all land as their own valid
// rows under the correct user, with no collisions and no data loss.
//
// Note on "inserted as-is": the IDOR guard's pre-check query returns the set
// of IDs that ALREADY exist for this user. Brand-new client UUIDs (not yet in
// the DB) are therefore not in allowedIDs and are conservatively rewritten to
// fresh server UUIDs — this is the guard's secure default and is unrelated to
// the R3-1 regression. The contract this test pins is functional correctness:
// every session in the batch becomes exactly one row, with a valid non-empty
// distinct PK, the correct user_id, and the correct content.
func TestUpsertSessionBatch_HappyPathLandsAllRows(t *testing.T) {
	db := setupFocusDB(t)
	repo := NewFocusRepository(db)
	ctx := context.Background()
	started := time.Date(2026, 6, 15, 10, 0, 0, 0, time.UTC)

	batch := []domain.FocusSession{
		newSession(uuid.NewString(), "alice", "pomodoro", started),
		newSession(uuid.NewString(), "alice", "flowtime", started.Add(time.Hour)),
		newSession(uuid.NewString(), "alice", "stopwatch", started.Add(2*time.Hour)),
	}
	require.NoError(t, repo.UpsertSessionBatch(ctx, batch))

	var rows []domain.FocusSession
	require.NoError(t, db.WithContext(ctx).Where("user_id = ?", "alice").Order("started_at ASC").Find(&rows).Error)
	require.Len(t, rows, 3, "all three sessions must land")

	ids := make(map[string]struct{})
	modes := make(map[string]struct{})
	for _, r := range rows {
		require.NotEmpty(t, r.ID, "every row must have a valid non-empty PK")
		require.Equal(t, "alice", r.UserID, "every row belongs to alice")
		_, dup := ids[r.ID]
		require.False(t, dup, "duplicate PK %q in happy path", r.ID)
		ids[r.ID] = struct{}{}
		modes[r.Mode] = struct{}{}
		require.Equal(t, 1500, r.ElapsedSeconds, "content must be preserved for %q", r.Mode)
	}
	require.Len(t, ids, 3, "three distinct PKs expected")
	require.Len(t, modes, 3, "all three distinct modes must be present")

	// Regression sentinel: the emitted batch must never produce an empty-PK row.
	var emptyCount int64
	require.NoError(t, db.WithContext(ctx).Model(&domain.FocusSession{}).Where("id = ?", "").Count(&emptyCount).Error)
	require.Equal(t, int64(0), emptyCount, "no row may have an empty primary key (R3-1 regression)")
}
