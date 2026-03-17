package domain

import "time"

type PomodoroConfig struct {
	UserID       string     `json:"userId" gorm:"type:uuid;primaryKey"`
	PomodoroTime int        `json:"pomodoroTime" gorm:"default:25;not null"`
	BreakTime    int        `json:"breakTime" gorm:"default:5;not null"`
	RestTime     int        `json:"restTime" gorm:"default:15;not null"`
	QtyPomodoros int        `json:"qtyPomodoros" gorm:"default:4;not null"`
	DailyGoal    int        `json:"dailyGoal" gorm:"default:8;not null"`
	Notifications bool      `json:"notifications" gorm:"default:false;not null"`
	AutoPomodoro bool       `json:"autoPomodoro" gorm:"default:false;not null"`
	AutoBreak    bool       `json:"autoBreak" gorm:"default:false;not null"`
	LastUpdate   *time.Time `json:"lastUpdate"`
	CreatedAt    time.Time  `json:"createdAt"`
	UpdatedAt    time.Time  `json:"updatedAt"`
}
