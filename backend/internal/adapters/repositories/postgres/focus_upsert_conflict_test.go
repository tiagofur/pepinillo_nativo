package postgres

import (
	"testing"

)

// D3: the session upsert must carry LWW + monotonic ended_at. Structural
// assertions (no database needed): the generated-SQL text is standard
// Postgres ON CONFLICT ... DO UPDATE ... WHERE, reviewed once by hand.
func TestSessionUpsertConflictClause(t *testing.T) {
	c := sessionUpsertConflict()

	if len(c.Columns) != 1 || c.Columns[0].Name != "id" {
		t.Fatalf("conflict target must be (id), got %+v", c.Columns)
	}
	assigns := c.DoUpdates.Assignments()
	wantKeys := []string{
		"ended_at", "duration_seconds", "elapsed_seconds", "task_id", "mode", "phase",
		"was_completed", "pause_count", "total_pause_seconds", "interruptions",
		"pomodoro_number", "satisfaction_rating", "journal_note", "updated_at",
	}
	if len(assigns) != len(wantKeys) {
		t.Fatalf("expected %d assignments, got %d", len(wantKeys), len(assigns))
	}
	gotKeys := make(map[string]bool, len(assigns))
	for _, a := range assigns {
		gotKeys[a.Column.Name] = true
	}
	for _, k := range wantKeys {
		if !gotKeys[k] {
			t.Fatalf("missing assignment for %q", k)
		}
	}
	if len(c.Where.Exprs) == 0 {
		t.Fatalf("LWW WHERE guard must be present (unconditional upsert resurrects sessions)")
	}
}
