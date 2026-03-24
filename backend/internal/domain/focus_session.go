package domain

import "time"

type FocusSession struct {
	ID                 string     `json:"id" gorm:"primaryKey"`
	UserID             string     `json:"userId" gorm:"type:uuid;index;not null"`
	TaskID             *int       `json:"taskId" gorm:"index"`
	StartedAt          time.Time  `json:"startedAt" gorm:"index;not null"`
	EndedAt            *time.Time `json:"endedAt"`
	Mode               string     `json:"mode" gorm:"type:varchar(50);index;not null"`
	Phase              string     `json:"phase" gorm:"not null"`
	DurationSeconds    int        `json:"durationSeconds" gorm:"not null"`
	ElapsedSeconds     int        `json:"elapsedSeconds" gorm:"not null"`
	PauseCount         int        `json:"pauseCount" gorm:"default:0;not null"`
	TotalPauseSeconds  int        `json:"totalPauseSeconds" gorm:"default:0;not null"`
	WasCompleted       bool       `json:"wasCompleted" gorm:"default:false;not null"`
	SharedWithTaskIDs  *string    `json:"sharedWithTaskIds"`
	Interruptions      int        `json:"interruptions" gorm:"default:0"`
	PomodoroNumber     int        `json:"pomodoroNumber" gorm:"default:0"`
	SatisfactionRating int        `json:"satisfactionRating" gorm:"default:0"`
	JournalNote        string     `json:"journalNote" gorm:"type:text;default:''"`
	CreatedAt          time.Time  `json:"createdAt"`
	UpdatedAt          time.Time  `json:"updatedAt"`
}
