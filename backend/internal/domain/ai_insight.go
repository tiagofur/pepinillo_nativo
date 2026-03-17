package domain

import "time"

type AIInsight struct {
	ID          int        `json:"id" gorm:"primaryKey;autoIncrement"`
	UserID      string     `json:"userId" gorm:"type:uuid;index;not null"`
	Type        string     `json:"type" gorm:"index;not null"`
	Title       string     `json:"title" gorm:"not null"`
	Content     string     `json:"content" gorm:"type:text;not null"`
	DataJSON    string     `json:"dataJson" gorm:"type:jsonb;default:'{}';not null"`
	GeneratedAt time.Time  `json:"generatedAt" gorm:"index;not null"`
	ExpiresAt   *time.Time `json:"expiresAt"`
	IsRead      bool       `json:"isRead" gorm:"default:false;not null"`
	CreatedAt   time.Time  `json:"createdAt"`
	UpdatedAt   time.Time  `json:"updatedAt"`
}
