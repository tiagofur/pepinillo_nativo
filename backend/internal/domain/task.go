package domain

import (
	"strings"
	"time"
)

type Task struct {
	ID                  int        `json:"id" gorm:"primaryKey;autoIncrement"`
	SyncID              string     `json:"syncId" gorm:"uniqueIndex;not null"`
	UserID              string     `json:"userId" gorm:"type:uuid;index;not null"`
	Title               *string    `json:"title"`
	Description         *string    `json:"description"`
	EnergyLevel         *string    `json:"energyLevel"`
	RecurrenceRule      *string    `json:"recurrenceRule"`
	RecurringTemplateID *string    `json:"recurringTemplateId"`
	CreatedDate         *time.Time `json:"createdDate"`
	FinishDate          *time.Time `json:"finishDate"` // Deprecated carrier (issue #989): Apple sent due dates here, Android completion instants. Superseded by DueDate/CompletedAt; still mirrored for old clients.
	// Canonical task-model fields (issue #989). Clients kept these locally
	// until the contract declared them; full-row LWW syncs persist them.
	DueDate           *time.Time `json:"dueDate"`
	CompletedAt       *time.Time `json:"completedAt"`
	ScheduledForToday bool       `json:"scheduledForToday"`
	// PlannedDate is the local calendar day the user plans to work on this
	// task (issue #991 S9). Replaces ScheduledForToday, which expired
	// client-side; past plans stay visible as "postponed" (S6).
	PlannedDate *time.Time `json:"plannedDate"`
	SortOrder   int        `json:"sortOrder"`
	IsFinished        bool       `json:"isFinished" gorm:"default:false;not null"`
	Priority          int        `json:"priority" gorm:"default:0;not null"`
	Category          *string    `json:"category"`

	// Legacy Pomodoro fields (for backward compatibility)
	EstimatedPomodoros int `json:"estimatedPomodoros" gorm:"default:0;not null"`
	CompletedPomodoros int `json:"completedPomodoros" gorm:"default:0;not null"`
	FocusedSeconds     int `json:"focusedSeconds" gorm:"default:0;not null"`

	// Mode-specific tracking fields
	TrackingMode               string `json:"trackingMode" gorm:"type:varchar(20);default:'pomodoro';not null"`
	CompletedFlowtimeSessions  int    `json:"completedFlowtimeSessions" gorm:"default:0;not null"`
	CompletedTimeblockSessions int    `json:"completedTimeblockSessions" gorm:"default:0;not null"`
	CompletedStopwatchSeconds  int    `json:"completedStopwatchSeconds" gorm:"default:0;not null"`

	FocusedSecondsPomodoro  int `json:"focusedSecondsPomodoro" gorm:"default:0;not null"`
	FocusedSecondsFlowtime  int `json:"focusedSecondsFlowtime" gorm:"default:0;not null"`
	FocusedSecondsTimeblock int `json:"focusedSecondsTimeblock" gorm:"default:0;not null"`
	FocusedSecondsStopwatch int `json:"focusedSecondsStopwatch" gorm:"default:0;not null"`

	ActiveSessionID *string   `json:"activeSessionId"`
	IsDeleted       bool      `json:"isDeleted" gorm:"default:false;not null"`
	UpdatedAt       time.Time `json:"updatedAt" gorm:"not null"`
	SubTasks        []SubTask `json:"subTasks" gorm:"foreignKey:TaskID;constraint:OnDelete:CASCADE"`
}

// ValidTrackingMode is the single allow-list for tracking_mode across HTTP
// handlers and the sync repository (matches chk_tasks_tracking_mode).
func ValidTrackingMode(mode string) bool {
	switch mode {
	case "pomodoro", "flowtime", "timeblock", "stopwatch":
		return true
	}
	return false
}

// NormalizeEnergyLevel maps the legacy client vocabularies onto the canonical
// enum (deep | shallow | admin), mirroring the web mapper
// (web/src/lib/data/sync/mappers.ts normalizeEnergy): Android shipped
// Deep/Regular/Light and web legacy used low/medium/high. Canonical values
// pass through; empty and anything unknown fail safe to shallow (never
// deep — an unrecognized value must not upgrade a task to Deep Work).
// nil passes through so unset stays unset.
func NormalizeEnergyLevel(raw *string) *string {
	if raw == nil {
		return nil
	}
	switch strings.ToLower(strings.TrimSpace(*raw)) {
	case "deep", "high":
		return ptrString("deep")
	case "shallow", "light", "medium", "":
		return ptrString("shallow")
	case "admin", "regular", "low":
		return ptrString("admin")
	default:
		return ptrString("shallow")
	}
}

// TaskDueDate returns the canonical due date of a task, falling back to the
// legacy finishDate carrier (issue #989 backfill makes them equal for old
// rows, so this is only a bridge while clients migrate).
func TaskDueDate(t Task) *time.Time {
	if t.DueDate != nil {
		return t.DueDate
	}
	return t.FinishDate
}

func ptrString(v string) *string { return &v }
