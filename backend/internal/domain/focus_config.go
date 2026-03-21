package domain

import "time"

type FocusConfig struct {
	UserID string `json:"userId" gorm:"type:uuid;primaryKey"`

	// Default focus mode
	DefaultMode FocusMode `json:"defaultMode" gorm:"type:varchar(20);default:pomodoro;not null"`

	// Pomodoro defaults
	PomodoroMinutes    int `json:"pomodoroMinutes" gorm:"default:25;not null"`
	ShortBreakMinutes  int `json:"shortBreakMinutes" gorm:"default:5;not null"`
	LongBreakMinutes   int `json:"longBreakMinutes" gorm:"default:15;not null"`
	PomodorosUntilLong int `json:"pomodorosUntilLong" gorm:"default:4;not null"`

	// Flowtime defaults
	FlowtimeCheckInMinutes int `json:"flowtimeCheckInMinutes" gorm:"default:25;not null"`

	// Timeblock defaults
	TimeblockMinutes int `json:"timeblockMinutes" gorm:"default:60;not null"`

	// General settings
	DailyGoal     int  `json:"dailyGoal" gorm:"default:8;not null"`
	Notifications bool `json:"notifications" gorm:"default:false;not null"`
	AutoStart     bool `json:"autoStart" gorm:"default:false;not null"`
	AutoBreak     bool `json:"autoBreak" gorm:"default:false;not null"`

	LastUpdate *time.Time `json:"lastUpdate"`
	CreatedAt  time.Time  `json:"createdAt"`
	UpdatedAt  time.Time  `json:"updatedAt"`
}
