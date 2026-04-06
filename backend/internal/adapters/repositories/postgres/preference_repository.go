package postgres

import (
	"context"

	"gorm.io/gorm"

	"pepinillo/backend/internal/domain"
)

type PreferenceRepository struct {
	db *gorm.DB
}

func NewPreferenceRepository(db *gorm.DB) *PreferenceRepository {
	return &PreferenceRepository{db: db}
}

func (r *PreferenceRepository) GetByUser(ctx context.Context, userID string) ([]domain.UserPreference, error) {
	var prefs []domain.UserPreference
	err := r.db.WithContext(ctx).
		Where("user_id = ?", userID).
		Order("key ASC").
		Find(&prefs).Error
	if err != nil {
		return nil, err
	}
	return prefs, nil
}

func (r *PreferenceRepository) UpsertBatch(ctx context.Context, prefs []domain.UserPreference) ([]domain.UserPreference, error) {
	if len(prefs) == 0 {
		return prefs, nil
	}

	err := r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		for i := range prefs {
			err := tx.Exec(`
				INSERT INTO user_preferences (user_id, key, value, updated_at)
				VALUES (?, ?, ?, ?)
				ON CONFLICT (user_id, key) DO UPDATE
				SET value = EXCLUDED.value, updated_at = EXCLUDED.updated_at
				WHERE EXCLUDED.updated_at > user_preferences.updated_at
			`, prefs[i].UserID, prefs[i].Key, prefs[i].Value, prefs[i].UpdatedAt).Error
			if err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
		return nil, err
	}

	// Return the full merged set from the database
	userID := prefs[0].UserID
	return r.GetByUser(ctx, userID)
}
