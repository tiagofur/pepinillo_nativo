package services

import (
	"context"
	"testing"

	"github.com/stretchr/testify/require"

	"pepinillo/backend/internal/domain"
	"pepinillo/backend/internal/ports"
)

type scriptedPushProvider struct {
	errs map[string]error
	sent []string
}

func (f *scriptedPushProvider) Send(_ context.Context, _, token, _, _ string, _ map[string]string) error {
	if err, ok := f.errs[token]; ok {
		return err
	}
	f.sent = append(f.sent, token)
	return nil
}

// A3: one dead token must not suppress the user's other devices; the dead
// token is pruned and delivery succeeds.
func TestPushService_DeadTokenDoesNotBlockOthers(t *testing.T) {
	repo := &fakeDeviceTokenRepo{
		items: []domain.DeviceToken{
			{UserID: "u1", Platform: "ios", Token: "dead", IsActive: true},
			{UserID: "u1", Platform: "android", Token: "live", IsActive: true},
		},
	}
	provider := &scriptedPushProvider{errs: map[string]error{"dead": ports.ErrPushTokenUnregistered}}
	svc := NewPushService(repo, provider)

	require.NoError(t, svc.SendTestPush(context.Background(), "u1", "Hola", "Mensaje"))
	require.Equal(t, []string{"live"}, provider.sent)
	require.Equal(t, "dead", repo.lastDelete)
}

// A3: total failure still surfaces an error.
func TestPushService_AllTokensFailReturnsError(t *testing.T) {
	repo := &fakeDeviceTokenRepo{
		items: []domain.DeviceToken{
			{UserID: "u1", Platform: "ios", Token: "dead", IsActive: true},
		},
	}
	provider := &scriptedPushProvider{errs: map[string]error{"dead": ports.ErrPushTokenUnregistered}}
	svc := NewPushService(repo, provider)

	require.Error(t, svc.SendTestPush(context.Background(), "u1", "Hola", "Mensaje"))
	require.Equal(t, "dead", repo.lastDelete)
}
