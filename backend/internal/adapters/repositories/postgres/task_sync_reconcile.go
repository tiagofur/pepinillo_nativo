package postgres

import (
	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"pepinillo/backend/internal/domain"
)

// reconcileSyncSubtasks applies the SAME slice-not-nil replacement rule as
// repo.Upsert (#998 S1), but reconciles by id/content instead of blind
// delete-and-recreate so server PKs survive sync pushes:
//   - an incoming row whose PK belongs to THIS task is updated in place;
//   - a zero-PK row matches an existing row by content (task + coalesced
//     title) before inserting — a client that forgets the server id can no
//     longer duplicate the list;
//   - a PK belonging to another task is never touched (Save-by-PK IDOR
//     guard) and falls through to the content path;
//   - existing rows matched by neither are deleted (missing = deleted on
//     the client, instead of resurrecting on the next pull).
// incoming.ID must already be resolved (0 for fresh inserts). A nil
// incoming.SubTasks means "not provided" — existing subtasks stay untouched,
// same as Upsert.
func reconcileSyncSubtasks(tx *gorm.DB, incoming *domain.Task) error {
	if incoming.SubTasks == nil {
		return nil
	}

	var existing []domain.SubTask
	if err := tx.Where("task_id = ?", incoming.ID).Find(&existing).Error; err != nil {
		return err
	}
	existingByID := make(map[int]domain.SubTask, len(existing))
	for _, st := range existing {
		existingByID[st.ID] = st
	}
	// Rows matched by id or content; everything else gets deleted.
	matched := make(map[int]bool, len(existing))

	for i := range incoming.SubTasks {
		row := incoming.SubTasks[i]
		row.TaskID = incoming.ID

		var target *domain.SubTask
		if row.ID != 0 {
			if local, ok := existingByID[row.ID]; ok && !matched[local.ID] {
				// PK owned by this task (the map only holds this task's
				// rows: a foreign PK is never here) and not consumed yet.
				target = &local
			}
		}
		if target == nil {
			// Content fallback: title is nullable — match coalesced.
			for j := range existing {
				cand := existing[j]
				if matched[cand.ID] {
					continue
				}
				sameTitle := (cand.Title == nil && row.Title == nil) ||
					(cand.Title != nil && row.Title != nil && *cand.Title == *row.Title)
				if sameTitle {
					target = &cand
					break
				}
			}
		}
		if target == nil {
			// Genuinely new row: never trust the incoming PK — a foreign PK
			// would either collide or hijack another task's child.
			row.ID = 0
			if err := tx.Omit(clause.Associations).Create(&row).Error; err != nil {
				return err
			}
			existing = append(existing, row)
			existingByID[row.ID] = row
			matched[row.ID] = true
			continue
		}
		updates := map[string]any{"title": row.Title, "is_finished": row.IsFinished}
		if err := tx.Model(&domain.SubTask{}).
			Where("id = ? AND task_id = ?", target.ID, incoming.ID).
			Updates(updates).Error; err != nil {
			return err
		}
		matched[target.ID] = true
	}

	for _, st := range existing {
		if !matched[st.ID] {
			if err := tx.Where("id = ? AND task_id = ?", st.ID, incoming.ID).
				Delete(&domain.SubTask{}).Error; err != nil {
				return err
			}
		}
	}
	return nil
}
