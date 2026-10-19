package handlers

import (
	"context"
	"time"
	"pepinillo/backend/internal/domain"
)

type fakeUserRepository struct {
	byID    map[string]*domain.User
	byEmail map[string]*domain.User
}

func newFakeUserRepository() *fakeUserRepository {
	return &fakeUserRepository{
		byID:    make(map[string]*domain.User),
		byEmail: make(map[string]*domain.User),
	}
}

func (r *fakeUserRepository) Create(_ context.Context, user *domain.User) error {
	r.byID[user.ID] = user
	r.byEmail[user.Email] = user
	return nil
}

func (r *fakeUserRepository) GetByID(_ context.Context, userID string) (*domain.User, error) {
	return r.byID[userID], nil
}

func (r *fakeUserRepository) GetByEmail(_ context.Context, email string) (*domain.User, error) {
	return r.byEmail[email], nil
}

func (r *fakeUserRepository) Update(_ context.Context, user *domain.User) error {
	r.byID[user.ID] = user
	r.byEmail[user.Email] = user
	return nil
}

func (r *fakeUserRepository) UpdateSubscription(_ context.Context, userID, tier string, expiresAt *time.Time) error {
	if user, ok := r.byID[userID]; ok {
		user.SubscriptionTier = tier
		user.SubscriptionExpiresAt = expiresAt
	}
	return nil
}

func (r *fakeUserRepository) Delete(_ context.Context, userID string) error {
	if user, ok := r.byID[userID]; ok {
		delete(r.byEmail, user.Email)
	}
	delete(r.byID, userID)
	return nil
}

func (r *fakeUserRepository) MarkEmailVerified(_ context.Context, userID string) error {
	if user, ok := r.byID[userID]; ok {
		user.EmailVerified = true
	}
	return nil
}

func (r *fakeUserRepository) UpdateEmailPending(_ context.Context, userID, newEmail string) error {
	if user, ok := r.byID[userID]; ok {
		user.PendingEmail = &newEmail
	}
	return nil
}

func (r *fakeUserRepository) ConfirmEmailChange(_ context.Context, userID, newEmail string) error {
	if user, ok := r.byID[userID]; ok {
		delete(r.byEmail, user.Email)
		user.Email = newEmail
		user.PendingEmail = nil
		user.EmailVerified = true
		r.byEmail[newEmail] = user
	}
	return nil
}

func (r *fakeUserRepository) RollbackEmailChange(_ context.Context, userID string) error {
	if user, ok := r.byID[userID]; ok {
		user.PendingEmail = nil
	}
	return nil
}

func (r *fakeUserRepository) GetByGoogleID(_ context.Context, googleID string) (*domain.User, error) {
	for _, user := range r.byID {
		if user.GoogleID != nil && *user.GoogleID == googleID {
			return user, nil
		}
	}
	return nil, nil
}

func (r *fakeUserRepository) GetByAppleID(_ context.Context, appleID string) (*domain.User, error) {
	for _, user := range r.byID {
		if user.AppleID != nil && *user.AppleID == appleID {
			return user, nil
		}
	}
	return nil, nil
}

func (r *fakeUserRepository) LinkGoogleAccount(_ context.Context, userID, googleID, email, name, picture string) error {
	if user, ok := r.byID[userID]; ok {
		user.GoogleID = &googleID
		user.GoogleEmail = &email
		user.GoogleName = &name
		user.GooglePicture = &picture
	}
	return nil
}

func (r *fakeUserRepository) UnlinkGoogleAccount(_ context.Context, userID string) error {
	if user, ok := r.byID[userID]; ok {
		user.GoogleID = nil
		user.GoogleEmail = nil
		user.GoogleName = nil
		user.GooglePicture = nil
	}
	return nil
}

func (r *fakeUserRepository) LinkAppleAccount(_ context.Context, userID, appleID, email, name string) error {
	if user, ok := r.byID[userID]; ok {
		user.AppleID = &appleID
		user.AppleEmail = &email
		user.AppleName = &name
	}
	return nil
}

func (r *fakeUserRepository) UnlinkAppleAccount(_ context.Context, userID string) error {
	if user, ok := r.byID[userID]; ok {
		user.AppleID = nil
		user.AppleEmail = nil
		user.AppleName = nil
	}
	return nil
}

func (r *fakeUserRepository) ConsumeAiCredit(_ context.Context, _ string) (bool, error) {
	return true, nil
}

func (r *fakeUserRepository) RefreshAiCredits(_ context.Context, _ string, _ int) error {
	return nil
}

func (r *fakeUserRepository) RefundAiCredit(_ context.Context, _ string) error {
	return nil
}

func (r *fakeUserRepository) ClaimPurchaseToken(_ context.Context, platform, token, userID string) (string, error) {
	return userID, nil
}

func (r *fakeUserRepository) ClaimWebhookEvent(_ context.Context, eventID, source string) (bool, error) {
	return true, nil
}
