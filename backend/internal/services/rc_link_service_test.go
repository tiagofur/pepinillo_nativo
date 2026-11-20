package services

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"pepinillo/backend/internal/adapters/stores/memory"
	"pepinillo/backend/internal/domain"
)

// rcLinkSubscriberServer fakes the RevenueCat REST /subscribers/{id}
// endpoint with canned subscriber JSON per app_user_id — per-ID routing,
// unlike rcSubscriberServer (alias tests) which serves a single fixture.
func rcLinkSubscriberServer(subscribers map[string]string) *httptest.Server {
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		id := strings.TrimPrefix(r.URL.Path, "/subscribers/")
		body, ok := subscribers[id]
		if !ok {
			w.WriteHeader(http.StatusNotFound)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(body))
	}))
}

func newRcLinkHarness(t *testing.T, subscribers map[string]string) (*RcLinkService, *RevenueCatService, *fakeUserRepo, string) {
	t.Helper()
	srv := rcLinkSubscriberServer(subscribers)
	t.Cleanup(srv.Close)

	repo := newFakeUserRepo()
	user := &domain.User{
		ID:               "11111111-1111-1111-1111-111111111111",
		Email:            "buyer@pepinillo.test",
		SubscriptionTier: domain.TierFree,
	}
	if err := repo.Create(context.Background(), user); err != nil {
		t.Fatalf("seed user: %v", err)
	}

	rc := NewRevenueCatService(repo, RevenueCatConfig{
		APIKey:     "sk_test",
		APIBaseURL: srv.URL,
	})
	svc := NewRcLinkService(repo, memory.NewAuthStore(), rc)
	return svc, rc, repo, user.ID
}

const plusSubscriber = `{"subscriber":{"entitlements":{"pepinillo_plus":{"expires_date":null}},"subscriptions":{}}}`
const emptySubscriber = `{"subscriber":{"entitlements":{},"subscriptions":{}}}`

func TestCreateLinkCodeIsSixDigitsWithTTL(t *testing.T) {
	svc, _, _, _ := newRcLinkHarness(t, map[string]string{})
	code, expiresAt, err := svc.CreateLinkCode(context.Background(), "11111111-1111-1111-1111-111111111111")
	if err != nil {
		t.Fatalf("CreateLinkCode: %v", err)
	}
	if len(code) != 6 {
		t.Fatalf("code length = %d, want 6", len(code))
	}
	if want := time.Now().UTC().Add(rcLinkCodeTTLSeconds * time.Second); expiresAt.Before(want.Add(-time.Minute)) || expiresAt.After(want.Add(time.Minute)) {
		t.Fatalf("expiresAt %v not ~15min out", expiresAt)
	}
}

func TestClaimLinkCodeGrantsPepinilloPlusAndBinds(t *testing.T) {
	svc, _, repo, userID := newRcLinkHarness(t, map[string]string{"$RCAnonymousID:abc": plusSubscriber})
	ctx := context.Background()

	code, _, err := svc.CreateLinkCode(ctx, userID)
	if err != nil {
		t.Fatalf("CreateLinkCode: %v", err)
	}

	user, tier, expiresAt, err := svc.ClaimLinkCode(ctx, code, "$RCAnonymousID:abc")
	if err != nil {
		t.Fatalf("ClaimLinkCode: %v", err)
	}
	if tier != domain.TierPepinilloPlus {
		t.Fatalf("tier = %q, want pepinillo_plus", tier)
	}
	if expiresAt != nil {
		t.Fatalf("lifetime grant must have nil expiry, got %v", expiresAt)
	}
	if user.SubscriptionTier != domain.TierPepinilloPlus {
		t.Fatalf("stored tier = %q, want pepinillo_plus", user.SubscriptionTier)
	}
	if user.RcAppUserID == nil || *user.RcAppUserID != "$RCAnonymousID:abc" {
		t.Fatalf("RcAppUserID not bound: %v", user.RcAppUserID)
	}
	if got := repo.byRc["$RCAnonymousID:abc"]; got != userID {
		t.Fatalf("byRc reverse mapping = %q, want %q", got, userID)
	}
}

func TestClaimLinkCodeRejectsMissingEntitlement(t *testing.T) {
	svc, _, repo, userID := newRcLinkHarness(t, map[string]string{"$RCAnonymousID:nope": emptySubscriber})
	ctx := context.Background()

	code, _, _ := svc.CreateLinkCode(ctx, userID)
	_, _, _, err := svc.ClaimLinkCode(ctx, code, "$RCAnonymousID:nope")
	if err != ErrRcLinkNoEntitlement {
		t.Fatalf("err = %v, want ErrRcLinkNoEntitlement", err)
	}
	// Fail closed: no tier write, no bind.
	user := repo.byID[userID]
	if user.SubscriptionTier != domain.TierFree {
		t.Fatalf("tier = %q, want free (no grant on missing entitlement)", user.SubscriptionTier)
	}
	if user.RcAppUserID != nil {
		t.Fatalf("RcAppUserID bound on failed claim: %v", user.RcAppUserID)
	}
}

func TestClaimLinkCodeIsSingleUse(t *testing.T) {
	svc, _, _, userID := newRcLinkHarness(t, map[string]string{"$RCAnonymousID:abc": plusSubscriber})
	ctx := context.Background()

	code, _, _ := svc.CreateLinkCode(ctx, userID)
	if _, _, _, err := svc.ClaimLinkCode(ctx, code, "$RCAnonymousID:abc"); err != nil {
		t.Fatalf("first claim: %v", err)
	}
	_, _, _, err := svc.ClaimLinkCode(ctx, code, "$RCAnonymousID:abc")
	if err != ErrRcLinkInvalidCode {
		t.Fatalf("second claim err = %v, want ErrRcLinkInvalidCode", err)
	}
}

func TestClaimLinkCodeLapsedEverywhereFailsClosed(t *testing.T) {
	// A LAPSED Everywhere read surfaces as "free" from the RC REST API: the
	// claim must fail closed (no grant, no bind) and must never downgrade a
	// stored Pepinillo+ grant (B3 parity with webhooks).
	svc, _, repo, userID := newRcLinkHarness(t, map[string]string{
		"$RCAnonymousID:abc": `{"subscriber":{"entitlements":{"everywhere_plus":{"expires_date":"2020-01-01T00:00:00Z"}},"subscriptions":{}}}`,
	})
	ctx := context.Background()
	repo.byID[userID].SubscriptionTier = domain.TierPepinilloPlus

	code, _, _ := svc.CreateLinkCode(ctx, userID)
	_, _, _, err := svc.ClaimLinkCode(ctx, code, "$RCAnonymousID:abc")
	if err != ErrRcLinkNoEntitlement {
		t.Fatalf("err = %v, want ErrRcLinkNoEntitlement", err)
	}
	if repo.byID[userID].SubscriptionTier != domain.TierPepinilloPlus {
		t.Fatalf("lapsed claim downgraded plus: stored=%q", repo.byID[userID].SubscriptionTier)
	}
	if repo.byID[userID].RcAppUserID != nil {
		t.Fatalf("RcAppUserID bound on lapsed claim: %v", repo.byID[userID].RcAppUserID)
	}
}

func TestWebhookResolvesBoundAnonymousID(t *testing.T) {
	// Renewals that arrive BEFORE the native app calls logIn (still carrying
	// the anonymous RC ID) must reach the buyer through the #953 bind.
	_, rc, repo, userID := newRcLinkHarness(t, map[string]string{"$RCAnonymousID:abc": plusSubscriber})
	ctx := context.Background()
	repo.SetRcAppUserID(ctx, userID, "$RCAnonymousID:abc")

	future := time.Now().Add(30 * 24 * time.Hour).UnixMilli()
	err := rc.ProcessWebhookEvent(ctx, &RevenueCatWebhookPayload{
		APIVersion: "1.0",
		Event: RevenueCatEvent{
			Type:           "INITIAL_PURCHASE",
			ID:             "evt-resolved-1",
			AppUserID:      "$RCAnonymousID:abc",
			ProductID:      "com.pepinillo.app.everywhere.annual",
			EntitlementIDs: []string{"everywhere_plus"},
			ExpirationAtMs: future,
			Store:          "APP_STORE",
		},
	})
	if err != nil {
		t.Fatalf("ProcessWebhookEvent: %v", err)
	}
	if got := repo.byID[userID].SubscriptionTier; got != domain.TierEverywhereAnnual {
		t.Fatalf("tier = %q, want everywhere_annual via bound anonymous ID", got)
	}
}
