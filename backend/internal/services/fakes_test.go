package services

import (
	"context"
	"pepinillo/backend/internal/domain"
)

type fakeUserRepo struct {
	byID    map[string]*domain.User
	byEmail map[string]*domain.User
}

func newFakeUserRepo() *fakeUserRepo {
	return &fakeUserRepo{
		byID:    make(map[string]*domain.User),
		byEmail: make(map[string]*domain.User),
	}
}

func (r *fakeUserRepo) Create(_ context.Context, user *domain.User) error {
	r.byID[user.ID] = user
	r.byEmail[user.Email] = user
	return nil
}

func (r *fakeUserRepo) GetByID(_ context.Context, userID string) (*domain.User, error) {
	return r.byID[userID], nil
}

func (r *fakeUserRepo) GetByEmail(_ context.Context, email string) (*domain.User, error) {
	return r.byEmail[email], nil
}

func (r *fakeUserRepo) Update(_ context.Context, user *domain.User) error {
	r.byID[user.ID] = user
	r.byEmail[user.Email] = user
	return nil
}

func (r *fakeUserRepo) Delete(_ context.Context, userID string) error {
	if user, ok := r.byID[userID]; ok {
		delete(r.byEmail, user.Email)
	}
	delete(r.byID, userID)
	return nil
}

func (r *fakeUserRepo) MarkEmailVerified(_ context.Context, userID string) error {
	if user, ok := r.byID[userID]; ok {
		user.EmailVerified = true
	}
	return nil
}

func (r *fakeUserRepo) UpdateEmailPending(_ context.Context, userID, newEmail string) error {
	if user, ok := r.byID[userID]; ok {
		user.PendingEmail = &newEmail
	}
	return nil
}

func (r *fakeUserRepo) ConfirmEmailChange(_ context.Context, userID, newEmail string) error {
	if user, ok := r.byID[userID]; ok {
		delete(r.byEmail, user.Email)
		user.Email = newEmail
		user.PendingEmail = nil
		user.EmailVerified = true
		r.byEmail[newEmail] = user
	}
	return nil
}

func (r *fakeUserRepo) RollbackEmailChange(_ context.Context, userID string) error {
	if user, ok := r.byID[userID]; ok {
		user.PendingEmail = nil
	}
	return nil
}

func (r *fakeUserRepo) GetByGoogleID(_ context.Context, googleID string) (*domain.User, error) {
	for _, user := range r.byID {
		if user.GoogleID != nil && *user.GoogleID == googleID {
			return user, nil
		}
	}
	return nil, nil
}

func (r *fakeUserRepo) GetByAppleID(_ context.Context, appleID string) (*domain.User, error) {
	for _, user := range r.byID {
		if user.AppleID != nil && *user.AppleID == appleID {
			return user, nil
		}
	}
	return nil, nil
}

func (r *fakeUserRepo) LinkGoogleAccount(_ context.Context, userID, googleID, email, name, picture string) error {
	if user, ok := r.byID[userID]; ok {
		user.GoogleID = &googleID
		user.GoogleEmail = &email
		user.GoogleName = &name
		user.GooglePicture = &picture
	}
	return nil
}

func (r *fakeUserRepo) UnlinkGoogleAccount(_ context.Context, userID string) error {
	if user, ok := r.byID[userID]; ok {
		user.GoogleID = nil
		user.GoogleEmail = nil
		user.GoogleName = nil
		user.GooglePicture = nil
	}
	return nil
}

func (r *fakeUserRepo) LinkAppleAccount(_ context.Context, userID, appleID, email, name string) error {
	if user, ok := r.byID[userID]; ok {
		user.AppleID = &appleID
		user.AppleEmail = &email
		user.AppleName = &name
	}
	return nil
}

func (r *fakeUserRepo) UnlinkAppleAccount(_ context.Context, userID string) error {
	if user, ok := r.byID[userID]; ok {
		user.AppleID = nil
		user.AppleEmail = nil
		user.AppleName = nil
	}
	return nil
}

func (r *fakeUserRepo) ConsumeAiCredit(_ context.Context, _ string) (bool, error) {
	return true, nil
}

func (r *fakeUserRepo) RefreshAiCredits(_ context.Context, _ string, _ int) error {
	return nil
}
