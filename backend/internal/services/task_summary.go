package services

// Pure task-state counting for the AI data summary. Extracted from
// ai_service.go (issue #989 review round 1) so the canonical-due-date
// overdue resolution is regression-testable without a database.

import (
	"time"

	"pepinillo/backend/internal/domain"
)

// countTaskStates tallies live tasks into totals/completed/pending/overdue
// and folds task categories into the given map. Overdue resolves through
// domain.TaskDueDate (canonical due date, legacy finishDate fallback).
// Returns totals in the order (total, completed, pending, overdue).
func countTaskStates(tasks []domain.Task, now time.Time, categories map[string]int) (int, int, int, int) {
	var total, completed, pending, overdue int
	for _, t := range tasks {
		if t.IsDeleted {
			continue
		}
		total++
		if t.IsFinished {
			completed++
		} else {
			pending++
			if due := domain.TaskDueDate(t); due != nil && due.Before(now) {
				overdue++
			}
		}
		cat := "sin categoría"
		if t.Category != nil && *t.Category != "" {
			cat = *t.Category
		}
		categories[cat]++
	}
	return total, completed, pending, overdue
}
