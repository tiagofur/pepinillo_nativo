package services

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/stretchr/testify/require"

	"pepinillo/backend/internal/domain"
)

type fakeDeviceTokenRepo struct {
	items      []domain.DeviceToken
	upsertErr  error
	listErr    error
	deleteErr  error
	lastDelete string
}

func (f *fakeDeviceTokenRepo) Upsert(_ context.Context, token *domain.DeviceToken) error {
	if f.upsertErr != nil {
		return f.upsertErr
	}
	f.items = append(f.items, *token)
	return nil
}

func (f *fakeDeviceTokenRepo) ListByUser(_ context.Context, _ string) ([]domain.DeviceToken, error) {
	if f.listErr != nil {
		return nil, f.listErr
	}
	return f.items, nil
}

func (f *fakeDeviceTokenRepo) DeleteByToken(_ context.Context, _ string, token string) error {
	if f.deleteErr != nil {
		return f.deleteErr
	}
	f.lastDelete = token
	return nil
}

type fakePushProvider struct {
	sendErr error
	sent    int
}

func (f *fakePushProvider) Send(_ context.Context, _, _, _, _ string, _ map[string]string) error {
	if f.sendErr != nil {
		return f.sendErr
	}
	f.sent++
	return nil
}

func TestPushService_RegisterDevice_ValidatesInput(t *testing.T) {
	svc := NewPushService(&fakeDeviceTokenRepo{}, &fakePushProvider{})

	err := svc.RegisterDevice(context.Background(), "u1", "windows", "abc", nil, nil)
	require.ErrorIs(t, err, ErrInvalidPushPlatform)

	err = svc.RegisterDevice(context.Background(), "u1", "ios", "   ", nil, nil)
	require.ErrorIs(t, err, ErrInvalidPushToken)
}

func TestPushService_SendTestPush(t *testing.T) {
	repo := &fakeDeviceTokenRepo{
		items: []domain.DeviceToken{
			{UserID: "u1", Platform: "ios", Token: "t1", IsActive: true},
			{UserID: "u1", Platform: "android", Token: "t2", IsActive: true},
		},
	}
	provider := &fakePushProvider{}
	svc := NewPushService(repo, provider)

	err := svc.SendTestPush(context.Background(), "u1", "Hola", "Mensaje")
	require.NoError(t, err)
	require.Equal(t, 2, provider.sent)
}

func TestPushService_SendTestPush_PropagatesProviderError(t *testing.T) {
	repo := &fakeDeviceTokenRepo{
		items: []domain.DeviceToken{
			{UserID: "u1", Platform: "ios", Token: "t1", IsActive: true},
		},
	}
	svc := NewPushService(repo, &fakePushProvider{sendErr: errors.New("boom")})

	err := svc.SendTestPush(context.Background(), "u1", "Hola", "Mensaje")
	require.Error(t, err)
	require.Contains(t, err.Error(), "send push failed")
}

func TestPushService_SendRecurrenceGeneratedPush(t *testing.T) {
	repo := &fakeDeviceTokenRepo{
		items: []domain.DeviceToken{
			{UserID: "u1", Platform: "ios", Token: "t1", IsActive: true},
			{UserID: "u1", Platform: "android", Token: "t2", IsActive: true},
		},
	}
	provider := &fakePushProvider{}
	svc := NewPushService(repo, provider)

	err := svc.SendRecurrenceGeneratedPush(context.Background(), "u1", 3, RecurrencePushWindow{
		From: time.Date(2026, 3, 12, 0, 0, 0, 0, time.UTC),
		To:   time.Date(2026, 3, 26, 0, 0, 0, 0, time.UTC),
	})
	require.NoError(t, err)
	require.Equal(t, 2, provider.sent)
}

func TestPushService_SendRecurrenceGeneratedPush_NoCreated(t *testing.T) {
	svc := NewPushService(&fakeDeviceTokenRepo{}, &fakePushProvider{sendErr: errors.New("should-not-send")})
	err := svc.SendRecurrenceGeneratedPush(context.Background(), "u1", 0, RecurrencePushWindow{From: time.Now(), To: time.Now()})
	require.NoError(t, err)
}
