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

// UpdateSubscription writes ONLY the subscription columns (see port contract).
func (r *UserRepository) UpdateSubscription(ctx context.Context, userID, tier string, expiresAt *time.Time) error {
	return r.db.WithContext(ctx).Model(&domain.User{}).Where("id = ?", userID).
		Updates(map[string]any{
			"subscription_tier":       tier,
			"subscription_expires_at": expiresAt,
		}).Error
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

func (r *UserRepository) GetByGoogleID(ctx context.Context, googleID string) (*domain.User, error) {
	var user domain.User
	err := r.db.WithContext(ctx).Where("google_id = ?", googleID).First(&user).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &user, nil
}

func (r *UserRepository) GetByAppleID(ctx context.Context, appleID string) (*domain.User, error) {
	var user domain.User
	err := r.db.WithContext(ctx).Where("apple_id = ?", appleID).First(&user).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &user, nil
}

func (r *UserRepository) LinkGoogleAccount(ctx context.Context, userID, googleID, email, name, picture string) error {
	now := time.Now().UTC()
	return r.db.WithContext(ctx).Model(&domain.User{}).Where("id = ?", userID).
		Updates(map[string]any{
			"google_id":      googleID,
			"google_email":   email,
			"google_name":    name,
			"google_picture": picture,
			"updated_at":     &now,
		}).Error
}

func (r *UserRepository) UnlinkGoogleAccount(ctx context.Context, userID string) error {
	now := time.Now().UTC()
	return r.db.WithContext(ctx).Model(&domain.User{}).Where("id = ?", userID).
		Updates(map[string]any{
			"google_id":      nil,
			"google_email":   nil,
			"google_name":    nil,
			"google_picture": nil,
			"updated_at":     &now,
		}).Error
}

func (r *UserRepository) LinkAppleAccount(ctx context.Context, userID, appleID, email, name string) error {
	now := time.Now().UTC()
	return r.db.WithContext(ctx).Model(&domain.User{}).Where("id = ?", userID).
		Updates(map[string]any{
			"apple_id":    appleID,
			"apple_email": email,
			"apple_name":  name,
			"updated_at":  &now,
		}).Error
}

func (r *UserRepository) UnlinkAppleAccount(ctx context.Context, userID string) error {
	now := time.Now().UTC()
	return r.db.WithContext(ctx).Model(&domain.User{}).Where("id = ?", userID).
		Updates(map[string]any{
			"apple_id":    nil,
			"apple_email": nil,
			"apple_name":  nil,
			"updated_at":  &now,
		}).Error
}

func (r *UserRepository) ConsumeAiCredit(ctx context.Context, userID string) (bool, error) {
	result := r.db.WithContext(ctx).Model(&domain.User{}).
		Where("id = ? AND ai_credits_balance > 0", userID).
		UpdateColumn("ai_credits_balance", gorm.Expr("ai_credits_balance - 1"))

	if result.Error != nil {
		return false, result.Error
	}
	return result.RowsAffected > 0, nil
}

// ClaimPurchaseToken atomically claims (platform, token) for userID (B1).
// The PRIMARY KEY makes the claim atomic under concurrency: exactly one
// claimant wins, and every later caller reads the same owner.
func (r *UserRepository) ClaimPurchaseToken(ctx context.Context, platform, token, userID string) (string, error) {
	var owner string
	err := r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := tx.Exec(`INSERT INTO purchase_claims (platform, purchase_token, user_id) VALUES (?, ?, ?)
			ON CONFLICT (platform, purchase_token) DO NOTHING`, platform, token, userID).Error; err != nil {
			return err
		}
		return tx.Raw(`SELECT user_id FROM purchase_claims WHERE platform = ? AND purchase_token = ?`, platform, token).Scan(&owner).Error
	})
	return owner, err
}

// ClaimWebhookEvent records a processed webhook event ID (B3). Redeliveries
// of an already-claimed ID report claimed=false so the caller can skip them.
func (r *UserRepository) ClaimWebhookEvent(ctx context.Context, eventID, source string) (bool, error) {
	res := r.db.WithContext(ctx).Exec(`INSERT INTO webhook_events (event_id, source) VALUES (?, ?)
		ON CONFLICT (event_id) DO NOTHING`, eventID, source)
	if res.Error != nil {
		return false, res.Error
	}
	return res.RowsAffected == 1, nil
}

func (r *UserRepository) RefreshAiCredits(ctx context.Context, userID string, amount int) error {
	now := time.Now().UTC()
	return r.db.WithContext(ctx).Model(&domain.User{}).Where("id = ?", userID).
		Updates(map[string]any{
			"ai_credits_balance":          amount,
			"ai_credits_last_refreshed_at": &now,
			"updated_at":                  &now,
		}).Error
}
