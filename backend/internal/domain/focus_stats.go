package domain

import "time"

type FocusStats struct {
	ID     int       `json:"id" gorm:"primaryKey;autoIncrement"`
	UserID string    `json:"userId" gorm:"type:uuid;index;not null"`
	Date   time.Time `json:"date" gorm:"type:date;index;not null"`

	// Legacy Pomodoro columns (kept for backward compatibility)
	Pomodoros        int `json:"pomodoros" gorm:"default:0;not null"`
	PomodoroDuration int `json:"pomodoroDuration" gorm:"default:0;not null"`
	Breaks           int `json:"breaks" gorm:"default:0;not null"`
	BreakDuration    int `json:"breakDuration" gorm:"default:0;not null"`
	Rests            int `json:"rests" gorm:"default:0;not null"`
	RestDuration     int `json:"restDuration" gorm:"default:0;not null"`

	// Mode-specific columns
	FlowtimeSeconds  int `json:"flowtimeSeconds" gorm:"default:0;not null"`
	TimeblockSeconds int `json:"timeblockSeconds" gorm:"default:0;not null"`
	StopwatchSeconds int `json:"stopwatchSeconds" gorm:"default:0;not null"`

	// Session counts per mode
	FlowtimeCount  int `json:"flowtimeCount" gorm:"default:0;not null"`
	TimeblockCount int `json:"timeblockCount" gorm:"default:0;not null"`
	StopwatchCount int `json:"stopwatchCount" gorm:"default:0;not null"`

	// General stats
	DailyGoal      int       `json:"dailyGoal" gorm:"default:0;not null"`
	DailyCompleted bool      `json:"dailyCompleted" gorm:"default:false;not null"`
	Count          int       `json:"count" gorm:"default:0;not null"`
	CreatedAt      time.Time `json:"createdAt"`
	UpdatedAt      time.Time `json:"updatedAt"`
}
