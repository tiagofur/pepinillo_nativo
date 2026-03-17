package domain

import "time"

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
	FinishDate          *time.Time `json:"finishDate"`
	IsFinished          bool       `json:"isFinished" gorm:"default:false;not null"`
	Priority            int        `json:"priority" gorm:"default:0;not null"`
	Category            *string    `json:"category"`
	EstimatedPomodoros  int        `json:"estimatedPomodoros" gorm:"default:0;not null"`
	CompletedPomodoros  int        `json:"completedPomodoros" gorm:"default:0;not null"`
	FocusedSeconds      int        `json:"focusedSeconds" gorm:"default:0;not null"`
	ActiveSessionID     *string    `json:"activeSessionId"`
	IsDeleted           bool       `json:"isDeleted" gorm:"default:false;not null"`
	UpdatedAt           time.Time  `json:"updatedAt" gorm:"not null"`
	SubTasks            []SubTask  `json:"subTasks" gorm:"foreignKey:TaskID;constraint:OnDelete:CASCADE"`
}
