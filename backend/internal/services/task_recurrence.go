package services

// Recurrence rule parsing, day math and instance generation helpers.
// Mechanically extracted verbatim from task_service.go (AGENTS.md ~500-line
// file budget; issue #989 review round 1) — no behavior changes in this commit.

import (
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"

	"pepinillo/backend/internal/domain"
)

type parsedRecurrenceRule struct {
	freq      string
	interval  int
	byDays    map[time.Weekday]bool
	anchorDay time.Time
}

func parseRecurrenceRule(raw string, anchorDay time.Time) (*parsedRecurrenceRule, bool) {
	parts := strings.Split(strings.ToUpper(strings.TrimSpace(raw)), ";")
	data := map[string]string{}
	for _, part := range parts {
		chunk := strings.SplitN(strings.TrimSpace(part), "=", 2)
		if len(chunk) != 2 {
			continue
		}
		data[chunk[0]] = chunk[1]
	}

	freq := data["FREQ"]
	if freq != "DAILY" && freq != "WEEKLY" && freq != "MONTHLY" {
		return nil, false
	}

	interval := 1
	if value, ok := data["INTERVAL"]; ok {
		if parsed, err := strconv.Atoi(value); err == nil && parsed > 0 {
			interval = parsed
		}
	}

	byDays := map[time.Weekday]bool{}
	if freq == "WEEKLY" {
		source := data["BYDAY"]
		if source == "" {
			byDays[anchorDay.Weekday()] = true
		} else {
			for _, token := range strings.Split(source, ",") {
				if weekday, ok := weekdayFromRRuleToken(strings.TrimSpace(token)); ok {
					byDays[weekday] = true
				}
			}
			if len(byDays) == 0 {
				byDays[anchorDay.Weekday()] = true
			}
		}
	}

	return &parsedRecurrenceRule{
		freq:      freq,
		interval:  interval,
		byDays:    byDays,
		anchorDay: dayStartUTC(anchorDay),
	}, true
}

func (r *parsedRecurrenceRule) matches(day time.Time) bool {
	d := dayStartUTC(day)
	if d.Before(r.anchorDay) {
		return false
	}

	switch r.freq {
	case "DAILY":
		diff := int(d.Sub(r.anchorDay).Hours() / 24)
		return diff%r.interval == 0
	case "WEEKLY":
		if !r.byDays[d.Weekday()] {
			return false
		}
		weeks := int(d.Sub(weekStart(r.anchorDay)).Hours() / (24 * 7))
		return weeks%r.interval == 0
	case "MONTHLY":
		if d.Day() != r.anchorDay.Day() {
			return false
		}
		months := (d.Year()-r.anchorDay.Year())*12 + int(d.Month()-r.anchorDay.Month())
		return months%r.interval == 0
	default:
		return false
	}
}

func weekdayFromRRuleToken(token string) (time.Weekday, bool) {
	switch token {
	case "MO":
		return time.Monday, true
	case "TU":
		return time.Tuesday, true
	case "WE":
		return time.Wednesday, true
	case "TH":
		return time.Thursday, true
	case "FR":
		return time.Friday, true
	case "SA":
		return time.Saturday, true
	case "SU":
		return time.Sunday, true
	default:
		return time.Sunday, false
	}
}

func weekStart(day time.Time) time.Time {
	d := dayStartUTC(day)
	offset := int(d.Weekday()+6) % 7 // monday based
	return d.AddDate(0, 0, -offset)
}

func dayStartUTC(t time.Time) time.Time {
	u := t.UTC()
	return time.Date(u.Year(), u.Month(), u.Day(), 0, 0, 0, 0, time.UTC)
}

func pickTaskDay(task domain.Task) time.Time {
	if task.CreatedDate != nil {
		return dayStartUTC(*task.CreatedDate)
	}
	// Issue #989: resolve the scheduled day through the canonical due date
	// with the legacy finishDate fallback.
	if due := domain.TaskDueDate(task); due != nil {
		return dayStartUTC(*due)
	}
	if !task.UpdatedAt.IsZero() {
		return dayStartUTC(task.UpdatedAt)
	}
	return time.Time{}
}

func recurrenceDedupKey(templateSyncID string, day time.Time) string {
	return templateSyncID + "|" + dayStartUTC(day).Format("2006-01-02")
}

func buildRecurringInstance(template domain.Task, day time.Time, now time.Time) domain.Task {
	var (
		title       = template.Title
		description = template.Description
		category    = template.Category
		energy      = template.EnergyLevel
	)

	instance := domain.Task{
		SyncID:              uuid.NewString(),
		UserID:              template.UserID,
		Title:               title,
		Description:         description,
		EnergyLevel:         energy,
		RecurrenceRule:      nil,
		RecurringTemplateID: &template.SyncID,
		CreatedDate:         ptrTimeTask(day),
		FinishDate:          nil,
		IsFinished:          false,
		Priority:            template.Priority,
		Category:            category,
		SortOrder:           template.SortOrder,
		EstimatedPomodoros:  template.EstimatedPomodoros,
		CompletedPomodoros:  0,
		FocusedSeconds:      0,
		ActiveSessionID:     nil,
		IsDeleted:           false,
		UpdatedAt:           now,
	}

	// The instance offset comes from whichever due carrier the template
	// carries: the canonical dueDate, or the legacy finishDate while clients
	// migrate (issue #989 round 1: a dueDate-only template must still
	// generate scheduled instances).
	base := template.DueDate
	if base == nil {
		base = template.FinishDate
	}
	if template.CreatedDate != nil && base != nil {
		offset := base.Sub(*template.CreatedDate)
		finish := day.Add(offset)
		// Mirror the scheduled day into BOTH carriers so old and new clients
		// read the same day.
		instance.FinishDate = &finish
		instance.DueDate = &finish
	}

	return instance
}

func ptrTimeTask(v time.Time) *time.Time {
	return &v
}
