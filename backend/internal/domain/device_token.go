package domain

import "time"

type DeviceToken struct {
	ID         int       `json:"id" gorm:"primaryKey;autoIncrement"`
	UserID     string    `json:"userId" gorm:"type:uuid;index;not null"`
	Platform   string    `json:"platform" gorm:"size:20;index;not null"` // ios|android
	Token      string    `json:"token" gorm:"uniqueIndex;not null"`
	DeviceID   *string   `json:"deviceId"`
	AppVersion *string   `json:"appVersion"`
	IsActive   bool      `json:"isActive" gorm:"default:true;not null"`
	CreatedAt  time.Time `json:"createdAt"`
	UpdatedAt  time.Time `json:"updatedAt"`
}
