package postgres

import (
	"context"
	"errors"
	"time"

	"gorm.io/gorm"

	"pepinillo/backend/internal/domain"
)

type UserRepository struct {
	db *gorm.DB
}

func NewUserRepository(db *gorm.DB) *UserRepository {
	return &UserRepository{db: db}
}

func (r *UserRepository) Create(ctx context.Context, user *domain.User) error {
	return r.db.WithContext(ctx).Create(user).Error
}

func (r *UserRepository) GetByID(ctx context.Context, userID string) (*domain.User, error) {
	var user domain.User
	err := r.db.WithContext(ctx).Where("id = ?", userID).First(&user).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &user, nil
}

func (r *UserRepository) GetByEmail(ctx context.Context, email string) (*domain.User, error) {
	var user domain.User
	err := r.db.WithContext(ctx).Where("email = ?", email).First(&user).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &user, nil
}

func (r *UserRepository) Update(ctx context.Context, user *domain.User) error {
	return r.db.WithContext(ctx).Save(user).Error
}

func (r *UserRepository) Delete(ctx context.Context, userID string) error {
	return r.db.WithContext(ctx).Where("id = ?", userID).Delete(&domain.User{}).Error
}

func (r *UserRepository) MarkEmailVerified(ctx context.Context, userID string) error {
	now := time.Now().UTC()
	return r.db.WithContext(ctx).Model(&domain.User{}).Where("id = ?", userID).
		Updates(map[string]any{
			"email_verified":    true,
			"email_verified_at": &now,
		}).Error
}

func (r *UserRepository) UpdateEmailPending(ctx context.Context, userID, newEmail string) error {
	now := time.Now().UTC()
	return r.db.WithContext(ctx).Model(&domain.User{}).Where("id = ?", userID).
		Updates(map[string]any{
			"pending_email":    &newEmail,
			"email_changed_at": &now,
		}).Error
}

func (r *UserRepository) ConfirmEmailChange(ctx context.Context, userID, newEmail string) error {
	now := time.Now().UTC()
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := tx.Model(&domain.User{}).Where("id = ?", userID).
			Updates(map[string]any{
				"email":            newEmail,
				"pending_email":    nil,
				"email_changed_at": nil,
			}).Error; err != nil {
			return err
		}

		return tx.Model(&domain.User{}).Where("id = ?", userID).
			Update("email_verified_at", &now).Error
	})
}

func (r *UserRepository) RollbackEmailChange(ctx context.Context, userID string) error {
	return r.db.WithContext(ctx).Model(&domain.User{}).Where("id = ?", userID).
		Updates(map[string]any{
			"pending_email":    nil,
			"email_changed_at": nil,
		}).Error
}
