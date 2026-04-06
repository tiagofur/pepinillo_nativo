package domain

import "time"

type UserPreference struct {
	UserID    string    `json:"userId" gorm:"type:uuid;primaryKey"`
	Key       string    `json:"key" gorm:"primaryKey;type:varchar(100)"`
	Value     string    `json:"value" gorm:"type:text"`
	UpdatedAt time.Time `json:"updatedAt"`
}
