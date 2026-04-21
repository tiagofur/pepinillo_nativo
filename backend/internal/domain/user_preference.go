package domain

import (
	"encoding/json"
	"strings"
	"time"
)

type UserPreference struct {
	UserID    string    `json:"userId" gorm:"type:uuid;primaryKey"`
	Key       string    `json:"key" gorm:"primaryKey;type:varchar(100)"`
	Value     string    `json:"value" gorm:"type:text"`
	UpdatedAt time.Time `json:"updatedAt"`
}

func (p *UserPreference) UnmarshalJSON(data []byte) error {
	type preferenceAlias struct {
		UserID        string    `json:"userId"`
		Key           string    `json:"key"`
		PreferenceKey string    `json:"preferenceKey"`
		Value         string    `json:"value"`
		UpdatedAt     time.Time `json:"updatedAt"`
	}

	var alias preferenceAlias
	if err := json.Unmarshal(data, &alias); err != nil {
		return err
	}

	key := strings.TrimSpace(alias.Key)
	if key == "" {
		key = strings.TrimSpace(alias.PreferenceKey)
	}

	p.UserID = alias.UserID
	p.Key = key
	p.Value = alias.Value
	p.UpdatedAt = alias.UpdatedAt

	return nil
}
