package domain

import "time"

type UserBehaviorLog struct {
	ID        int64     `json:"id" gorm:"primaryKey;autoIncrement"`
	UserID    string    `json:"userId" gorm:"type:uuid;index;not null"`
	EventType string    `json:"eventType" gorm:"index;not null"`
	EventData string    `json:"eventData" gorm:"type:jsonb;default:'{}';not null"`
	Timestamp time.Time `json:"timestamp" gorm:"index;not null"`
	CreatedAt time.Time `json:"createdAt"`
}

// TableName specifies the table name to prevent GORM pluralization
func (UserBehaviorLog) TableName() string {
	return "user_behavior_log"
}
