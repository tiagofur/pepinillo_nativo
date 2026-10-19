package services

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"

	"pepinillo/backend/internal/domain"
)

func TestIncomingEntitlementSupersedes(t *testing.T) {
	now := time.Date(2026, 6, 1, 0, 0, 0, 0, time.UTC)
	past := now.Add(-30 * 24 * time.Hour)
	future := now.Add(30 * 24 * time.Hour)
	farFuture := now.Add(365 * 24 * time.Hour)

	cases := []struct {
		name          string
		storedTier    string
		storedExp     *time.Time
		storedLife    bool
		inTier        string
		inExp         *time.Time
		want          bool
	}{
		{"lifetime incoming always wins", "everywhere_monthly", &future, false, "pepinillo_plus", nil, true},
		{"stored lifetime beats finite grant", "pepinillo_plus", nil, false, "everywhere_annual", &farFuture, false},
		{"stored entitlement flag beats finite grant", "free", nil, true, "everywhere_monthly", &farFuture, false},
		{"newer expiry wins", "everywhere_monthly", &future, false, "everywhere_annual", &farFuture, true},
		{"older expiry ignored", "everywhere_annual", &farFuture, false, "everywhere_monthly", &future, false},
		{"equal expiry ignored", "everywhere_monthly", &future, false, "everywhere_monthly", &future, false},
		{"lapsed stored grant accepts anything", "everywhere_monthly", &past, false, "everywhere_monthly", &future, true},
		{"unbounded stored kept over finite", "everywhere_monthly", nil, false, "everywhere_monthly", &future, false},
		{"unbounded refresh applies", "everywhere_monthly", nil, false, "everywhere_monthly", nil, true},
		{"free stored accepts grant", "free", nil, false, "everywhere_monthly", &future, true},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got := incomingEntitlementSupersedes(tc.storedTier, tc.storedExp, tc.storedLife, tc.inTier, tc.inExp, now)
			require.Equal(t, tc.want, got)
		})
	}
}

func newRevenueCatServiceForTest(users *MockUserRepository) *RevenueCatService {
	return NewRevenueCatService(users, RevenueCatConfig{})
}

func TestProcessWebhookEvent_DuplicateSkipped(t *testing.T) {
	users := &MockUserRepository{}
	svc := newRevenueCatServiceForTest(users)

	users.On("ClaimWebhookEvent", mock.Anything, "revenuecat:evt-1", "revenuecat").Return(false, nil)

	payload := &RevenueCatWebhookPayload{}
	payload.Event.ID = "evt-1"
	payload.Event.AppUserID = "user-1"
	payload.Event.Type = "RENEWAL"

	require.NoError(t, svc.ProcessWebhookEvent(context.Background(), payload))
	users.AssertNotCalled(t, "GetByID", mock.Anything, mock.Anything)
	users.AssertNotCalled(t, "UpdateSubscription", mock.Anything, mock.Anything, mock.Anything, mock.Anything)
}

func TestHandlePurchaseEvent_StaleRedeliveryIgnored(t *testing.T) {
	users := &MockUserRepository{}
	svc := newRevenueCatServiceForTest(users)

	storedExp := time.Date(2030, 1, 1, 0, 0, 0, 0, time.UTC)
	stored := &domain.User{
		ID: "user-1", Email: "u@x.com",
		SubscriptionTier: "everywhere_annual", SubscriptionExpiresAt: &storedExp,
	}
	users.On("GetByID", mock.Anything, "user-1").Return(stored, nil)

	// Stale event: monthly grant expiring 2025, delivered after the 2030 grant.
	event := RevenueCatEvent{
		Type: "RENEWAL", ID: "evt-old",
		ProductID:      "com.pepinillo.app.pro.monthly",
		EntitlementIDs: []string{"everywhere_plus"},
		ExpirationAtMs: time.Date(2025, 1, 1, 0, 0, 0, 0, time.UTC).UnixMilli(),
	}
	require.NoError(t, svc.handlePurchaseEvent(context.Background(), "user-1", event))
	users.AssertNotCalled(t, "UpdateSubscription", mock.Anything, mock.Anything, mock.Anything, mock.Anything)
}

func TestHandlePurchaseEvent_NewerGrantApplies(t *testing.T) {
	users := &MockUserRepository{}
	svc := newRevenueCatServiceForTest(users)

	storedExp := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	stored := &domain.User{
		ID: "user-1", Email: "u@x.com",
		SubscriptionTier: "everywhere_monthly", SubscriptionExpiresAt: &storedExp,
	}
	users.On("GetByID", mock.Anything, "user-1").Return(stored, nil)
	users.On("UpdateSubscription", mock.Anything, "user-1", "everywhere_annual", mock.Anything).Return(nil)

	event := RevenueCatEvent{
		Type: "RENEWAL", ID: "evt-new",
		ProductID:      "com.pepinillo.app.pro.annual",
		EntitlementIDs: []string{"everywhere_plus"},
		ExpirationAtMs: time.Date(2027, 1, 1, 0, 0, 0, 0, time.UTC).UnixMilli(),
	}
	require.NoError(t, svc.handlePurchaseEvent(context.Background(), "user-1", event))
	users.AssertCalled(t, "UpdateSubscription", mock.Anything, "user-1", "everywhere_annual", mock.Anything)
}
