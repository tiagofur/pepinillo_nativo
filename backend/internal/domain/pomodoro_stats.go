package domain

import "time"

type PomodoroStats struct {
	ID               int       `json:"id" gorm:"primaryKey;autoIncrement"`
	UserID           string    `json:"userId" gorm:"type:uuid;index;not null"`
	Date             time.Time `json:"date" gorm:"type:date;index;not null"`
	Pomodoros        int       `json:"pomodoros" gorm:"default:0;not null"`
	PomodoroDuration int       `json:"pomodoroDuration" gorm:"default:0;not null"`
	Breaks           int       `json:"breaks" gorm:"default:0;not null"`
	BreakDuration    int       `json:"breakDuration" gorm:"default:0;not null"`
	Rests            int       `json:"rests" gorm:"default:0;not null"`
	RestDuration     int       `json:"restDuration" gorm:"default:0;not null"`
	DailyGoal        int       `json:"dailyGoal" gorm:"default:0;not null"`
	DailyCompleted   bool      `json:"dailyCompleted" gorm:"default:false;not null"`
	Count            int       `json:"count" gorm:"default:0;not null"`
	CreatedAt        time.Time `json:"createdAt"`
	UpdatedAt        time.Time `json:"updatedAt"`
}

// TableName maps the legacy PomodoroStats struct onto the focus_stats
// table that replaced pomodoro_stats in migration 000007_focus_modes.
func (PomodoroStats) TableName() string { return "focus_stats" }
