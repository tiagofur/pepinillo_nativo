package services

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"

	"pepinillo/backend/internal/domain"
)

func rcSubscriberServer(t *testing.T, entitlements map[string]any) *httptest.Server {
	t.Helper()
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_ = json.NewEncoder(w).Encode(map[string]any{
			"subscriber": map[string]any{"entitlements": entitlements, "subscriptions": map[string]any{}},
		})
	}))
}

// U-C: an alias merge applies the transferred lifetime entitlement.
func TestHandleSubscriberAliasEvent_AppliesLifetime(t *testing.T) {
	srv := rcSubscriberServer(t, map[string]any{
		"pepinillo_plus": map[string]any{"expires_date": nil},
	})
	defer srv.Close()

	users := &MockUserRepository{}
	svc := NewRevenueCatService(users, RevenueCatConfig{APIBaseURL: srv.URL, APIKey: "k"})
	stored := &domain.User{ID: "user-1", Email: "u@x.com", SubscriptionTier: "free"}
	users.On("GetByID", mock.Anything, "user-1").Return(stored, nil)
	users.On("UpdateSubscription", mock.Anything, "user-1", "pepinillo_plus", mock.Anything).Return(nil)

	err := svc.handleSubscriberAliasEvent(context.Background(), "user-1", RevenueCatEvent{
		Type: "SUBSCRIBER_ALIAS", ID: "evt-1", Aliases: []string{"$RCAnonymousID:abc"},
	})
	require.NoError(t, err)
	users.AssertCalled(t, "UpdateSubscription", mock.Anything, "user-1", "pepinillo_plus", mock.Anything)
}

// U-C: unknown local user is not an error (signup/login verify converges later).
func TestHandleSubscriberAliasEvent_UnknownUserIsNoop(t *testing.T) {
	users := &MockUserRepository{}
	svc := NewRevenueCatService(users, RevenueCatConfig{APIBaseURL: "http://x", APIKey: "k"})
	users.On("GetByID", mock.Anything, "ghost").Return(nil, nil)

	require.NoError(t, svc.handleSubscriberAliasEvent(context.Background(), "ghost", RevenueCatEvent{Type: "SUBSCRIBER_ALIAS"}))
	users.AssertNotCalled(t, "UpdateSubscription", mock.Anything, mock.Anything, mock.Anything, mock.Anything)
}

// U-C: a free RC read never downgrades a stored grant.
func TestHandleSubscriberAliasEvent_FreeDoesNotDowngrade(t *testing.T) {
	srv := rcSubscriberServer(t, map[string]any{})
	defer srv.Close()

	users := &MockUserRepository{}
	svc := NewRevenueCatService(users, RevenueCatConfig{APIBaseURL: srv.URL, APIKey: "k"})
	future := time.Now().UTC().Add(30 * 24 * time.Hour)
	stored := &domain.User{
		ID: "user-1", Email: "u@x.com",
		SubscriptionTier: "everywhere_monthly", SubscriptionExpiresAt: &future,
	}
	users.On("GetByID", mock.Anything, "user-1").Return(stored, nil)

	require.NoError(t, svc.handleSubscriberAliasEvent(context.Background(), "user-1", RevenueCatEvent{Type: "SUBSCRIBER_ALIAS", ID: "evt-2"}))
	users.AssertNotCalled(t, "UpdateSubscription", mock.Anything, mock.Anything, mock.Anything, mock.Anything)
}
