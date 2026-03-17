package postgres

import (
	"context"
	"errors"

	"gorm.io/gorm"

	"pepinillo/backend/internal/domain"
)

type DeviceTokenRepository struct {
	db *gorm.DB
}

func NewDeviceTokenRepository(db *gorm.DB) *DeviceTokenRepository {
	return &DeviceTokenRepository{db: db}
}

func (r *DeviceTokenRepository) Upsert(ctx context.Context, token *domain.DeviceToken) error {
	var existing domain.DeviceToken
	err := r.db.WithContext(ctx).Where("token = ?", token.Token).First(&existing).Error
	if err == nil {
		existing.UserID = token.UserID
		existing.Platform = token.Platform
		existing.DeviceID = token.DeviceID
		existing.AppVersion = token.AppVersion
		existing.IsActive = true
		return r.db.WithContext(ctx).Save(&existing).Error
	}
	if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
		return err
	}
	return r.db.WithContext(ctx).Create(token).Error
}

func (r *DeviceTokenRepository) ListByUser(ctx context.Context, userID string) ([]domain.DeviceToken, error) {
	items := make([]domain.DeviceToken, 0)
	err := r.db.WithContext(ctx).
		Where("user_id = ? AND is_active = true", userID).
		Order("updated_at DESC").
		Find(&items).Error
	if err != nil {
		return nil, err
	}
	return items, nil
}

func (r *DeviceTokenRepository) DeleteByToken(ctx context.Context, userID, token string) error {
	return r.db.WithContext(ctx).
		Model(&domain.DeviceToken{}).
		Where("user_id = ? AND token = ?", userID, token).
		Update("is_active", false).Error
}
