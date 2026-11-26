package domain

import (
	"encoding/json"
	"os"
	"testing"
)

// Issue #989 (S7): the canonical wire fixture versioned in the repo. Every
// platform's suite decodes the same file and asserts the task-model fields
// survive its mapper — this is the backend leg.
func TestCanonicalWireFixtureDecodes(t *testing.T) {
	raw, err := os.ReadFile("../../../contracts/fixtures/task-canonical-989.json")
	if err != nil {
		t.Fatalf("fixture must exist in the repo: %v", err)
	}
	var task Task
	if err := json.Unmarshal(raw, &task); err != nil {
		t.Fatalf("fixture must decode into domain.Task: %v", err)
	}

	if task.SyncID != "fixture-989-canonical" {
		t.Fatalf("syncId = %q", task.SyncID)
	}
	if task.DueDate == nil || task.DueDate.Format("2006-01-02") != "2026-11-26" {
		t.Fatalf("dueDate = %v, want the fixture day", task.DueDate)
	}
	if task.CompletedAt != nil {
		t.Fatalf("unfinished fixture must carry completedAt = NULL, got %v", task.CompletedAt)
	}
	if !task.ScheduledForToday {
		t.Fatalf("scheduledForToday must survive the decode")
	}
	if task.SortOrder != 6 {
		t.Fatalf("sortOrder = %d, want 6", task.SortOrder)
	}
	if task.EnergyLevel == nil || *task.EnergyLevel != "shallow" {
		t.Fatalf("energyLevel = %v, want canonical shallow", task.EnergyLevel)
	}
	if len(task.SubTasks) != 2 {
		t.Fatalf("subTasks = %d, want 2", len(task.SubTasks))
	}

	// The canonical vocabulary is a fixed point of the server normalizer…
	normalized := NormalizeEnergyLevel(task.EnergyLevel)
	if normalized == nil || *normalized != *task.EnergyLevel {
		t.Fatalf("canonical energy must be a normalizer fixed point: %v → %v", task.EnergyLevel, normalized)
	}
	// …and the legacy finishDate decoy must not leak into an unfinished task's
	// canonical due date (the fixture carries dueDate explicitly, so the
	// fallback has nothing to bridge here).
	if task.DueDate == nil && task.FinishDate != nil {
		t.Fatalf("canonical dueDate missing while the legacy carrier is set")
	}
}
