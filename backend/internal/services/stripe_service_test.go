package services

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
	"time"

	"pepinillo/backend/internal/domain"
)

const testWebhookSecret = "whsec_test_secret"

func testStripeConfig(baseURL string) StripeConfig {
	return StripeConfig{
		SecretKey:              "sk_test_x",
		WebhookSecret:          testWebhookSecret,
		PricePepinilloPlus:     "price_plus",
		PriceEverywhereMonthly: "price_monthly",
		PriceEverywhereAnnual:  "price_annual",
		SuccessURL:             "https://pepinillo.app/upgrade",
		APIBaseURL:             baseURL,
	}
}

func signStripePayload(t *testing.T, payload []byte, secret string, ts time.Time) string {
	t.Helper()
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte(fmt.Sprintf("%d", ts.Unix()) + "." + string(payload)))
	return fmt.Sprintf("t=%d,v1=%s", ts.Unix(), hex.EncodeToString(mac.Sum(nil)))
}

func stripeEventPayload(eventID, eventType string, obj map[string]any) []byte {
	body, _ := json.Marshal(map[string]any{
		"id":   eventID,
		"type": eventType,
		"data": map[string]any{"object": obj},
	})
	return body
}

// ---------- Signature ----------

func TestVerifyStripeSignature(t *testing.T) {
	payload := stripeEventPayload("evt_1", "checkout.session.completed", map[string]any{})
	ts := time.Now().UTC()
	valid := signStripePayload(t, payload, testWebhookSecret, ts)

	event, err := VerifyStripeSignature(payload, valid, testWebhookSecret, 5*time.Minute)
	if err != nil {
		t.Fatalf("valid signature rejected: %v", err)
	}
	if event.ID != "evt_1" || event.Type != "checkout.session.completed" {
		t.Fatalf("event fields lost: %+v", event)
	}

	if _, err := VerifyStripeSignature(payload, valid, "whsec_other", 5*time.Minute); err == nil {
		t.Fatal("wrong secret accepted")
	}

	stale := signStripePayload(t, payload, testWebhookSecret, ts.Add(-10*time.Minute))
	if _, err := VerifyStripeSignature(payload, stale, testWebhookSecret, 5*time.Minute); err == nil {
		t.Fatal("stale timestamp accepted")
	}

	if _, err := VerifyStripeSignature(payload, "", testWebhookSecret, 5*time.Minute); err == nil {
		t.Fatal("empty header accepted")
	}
	if _, err := VerifyStripeSignature(payload, "t=abc,v1=00", testWebhookSecret, 5*time.Minute); err == nil {
		t.Fatal("malformed header accepted")
	}

	tampered := stripeEventPayload("evt_2", "checkout.session.completed", map[string]any{})
	if _, err := VerifyStripeSignature(tampered, valid, testWebhookSecret, 5*time.Minute); err == nil {
		t.Fatal("tampered payload accepted")
	}
}

// ---------- Tier reconciliation ----------

func TestStripeEffectiveTierAtAndMaxTier(t *testing.T) {
	now := time.Now().UTC()
	future := now.Add(30 * 24 * time.Hour)
	plus := domain.TierPepinilloPlus
	monthly := domain.TierEverywhereMonthly

	// Stripe monthly beats a legacy pepinillo_plus purchase for sync gates.
	user := &domain.User{PepinilloPlusEntitlementAt: &now, StripeTier: &monthly, StripeExpiresAt: &future}
	if got := user.EffectiveTierAt(now); got != domain.TierEverywhereMonthly {
		t.Fatalf("expected stripe monthly to win, got %s", got)
	}

	// Expired Stripe subscription falls back to the legacy entitlement.
	past := now.Add(-time.Hour)
	user = &domain.User{PepinilloPlusEntitlementAt: &now, StripeTier: &monthly, StripeExpiresAt: &past}
	if got := user.EffectiveTierAt(now); got != domain.TierPepinilloPlus {
		t.Fatalf("expected fallback to pepinillo_plus, got %s", got)
	}

	// Store annual beats Stripe monthly (max across providers).
	annual := domain.TierEverywhereAnnual
	user = &domain.User{SubscriptionTier: annual, SubscriptionExpiresAt: &future, StripeTier: &monthly, StripeExpiresAt: &future}
	if got := user.EffectiveTierAt(now); got != domain.TierEverywhereAnnual {
		t.Fatalf("expected store annual to win, got %s", got)
	}

	// Stripe one-time purchase grants pepinillo_plus.
	user = &domain.User{StripeTier: &plus}
	if got := user.EffectiveTierAt(now); got != domain.TierPepinilloPlus {
		t.Fatalf("expected stripe plus, got %s", got)
	}

	if domain.MaxTier(domain.TierPepinilloPlus, domain.TierEverywhereMonthly) != domain.TierEverywhereMonthly {
		t.Fatal("MaxTier ordering broken (monthly vs plus)")
	}
	if domain.MaxTier(domain.TierEverywhereAnnual, domain.TierEverywhereMonthly) != domain.TierEverywhereAnnual {
		t.Fatal("MaxTier ordering broken (annual vs monthly)")
	}
}

// ---------- Checkout ----------

func TestCreateCheckoutSession(t *testing.T) {
	var capturedForm string
	var authHeader string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		authHeader = r.Header.Get("Authorization")
		body := make([]byte, r.ContentLength)
		_, _ = r.Body.Read(body)
		capturedForm = string(body)
		_ = json.NewEncoder(w).Encode(map[string]any{
			"id": "cs_test", "url": "https://checkout.stripe.com/c/pay/cs_test", "customer": "cus_123",
		})
	}))
	defer srv.Close()

	repo := newFakeUserRepo()
	repo.byID["u1"] = &domain.User{ID: "u1", Email: "a@b.c"}
	svc := NewStripeService(repo, testStripeConfig(srv.URL), nil, nil)

	res, err := svc.CreateCheckoutSession(context.Background(), "u1", StripePlanEverywhereMonthly, "", "")
	if err != nil {
		t.Fatalf("checkout failed: %v", err)
	}
	if res.CheckoutURL != "https://checkout.stripe.com/c/pay/cs_test" {
		t.Fatalf("unexpected url: %s", res.CheckoutURL)
	}
	if authHeader != "Bearer sk_test_x" {
		t.Fatalf("missing auth header: %q", authHeader)
	}
	form, err := url.ParseQuery(capturedForm)
	if err != nil {
		t.Fatalf("form not parseable: %v", err)
	}
	if form.Get("mode") != "subscription" || form.Get("client_reference_id") != "u1" ||
		form.Get("line_items[0][price]") != "price_monthly" || form.Get("customer_email") != "a@b.c" {
		t.Fatalf("unexpected form: %v", form)
	}
	if !strings.HasSuffix(form.Get("success_url"), "/upgrade?checkout=success") || strings.Contains(form.Get("success_url"), "upgrade/upgrade") {
		t.Fatalf("success_url malformed: %s", form.Get("success_url"))
	}
	if repo.byCustomer["cus_123"] != "u1" {
		t.Fatal("customer not bound to user")
	}

	// One-time plan uses payment mode.
	if _, err := svc.CreateCheckoutSession(context.Background(), "u1", StripePlanPepinilloPlus, "", ""); err != nil {
		t.Fatalf("plus checkout failed: %v", err)
	}
	if form.Get("mode") != "subscription" {
		// capturedForm holds the LAST request (plus checkout): payment mode.
		if !strings.Contains(capturedForm, "mode=payment") && form.Get("mode") != "payment" {
			t.Fatalf("plus plan should be payment mode: %s", capturedForm)
		}
	}

	if _, err := svc.CreateCheckoutSession(context.Background(), "u1", "bogus", "", ""); err == nil {
		t.Fatal("invalid plan accepted")
	}

	unconfigured := NewStripeService(repo, StripeConfig{}, nil, nil)
	if _, err := unconfigured.CreateCheckoutSession(context.Background(), "u1", StripePlanPepinilloPlus, "", ""); err == nil {
		t.Fatal("unconfigured service accepted checkout")
	}
}

// ---------- Webhook handling ----------

func TestHandleWebhookCheckoutCompleted(t *testing.T) {
	repo := newFakeUserRepo()
	repo.byID["u1"] = &domain.User{ID: "u1"}
	svc := NewStripeService(repo, testStripeConfig("https://api.stripe.invalid"), nil, nil)

	periodEnd := time.Now().Add(30 * 24 * time.Hour).Unix()
	payload := stripeEventPayload("evt_ck", "checkout.session.completed", map[string]any{
		"client_reference_id": "u1",
		"customer":            "cus_9",
		"metadata":            map[string]any{"user_id": "u1", "plan": StripePlanEverywhereMonthly},
		"current_period_end":  float64(periodEnd),
	})
	header := signStripePayload(t, payload, testWebhookSecret, time.Now().UTC())

	if err := svc.HandleWebhook(context.Background(), StripeWebhookInput{Payload: payload, Signature: header}); err != nil {
		t.Fatalf("webhook failed: %v", err)
	}
	gotTier := repo.stripeTier["u1"]
	if gotTier == nil || *gotTier != domain.TierEverywhereMonthly {
		t.Fatalf("expected everywhere_monthly, got %v", gotTier)
	}
	if repo.stripeExp["u1"] == nil || repo.stripeExp["u1"].Unix() != periodEnd {
		t.Fatalf("expected period end persisted")
	}
	if repo.byCustomer["cus_9"] != "u1" {
		t.Fatal("customer binding missing")
	}

	// Dedupe: same event id → no-op (no panic, state unchanged).
	repo.stripeTier["u1"] = nil
	if err := svc.HandleWebhook(context.Background(), StripeWebhookInput{Payload: payload, Signature: header}); err != nil {
		t.Fatalf("redelivery errored: %v", err)
	}
	if repo.stripeTier["u1"] != nil {
		t.Fatal("redelivery re-processed an already-claimed event")
	}

	// Bad signature rejected.
	if err := svc.HandleWebhook(context.Background(), StripeWebhookInput{Payload: payload, Signature: "t=1,v1=bad"}); err == nil {
		t.Fatal("bad signature accepted")
	}
}

func TestHandleWebhookSubscriptionDeleted(t *testing.T) {
	repo := newFakeUserRepo()
	plus := domain.TierPepinilloPlus
	repo.byID["u2"] = &domain.User{ID: "u2"}
	repo.byCustomer["cus_2"] = "u2"
	repo.stripeTier["u2"] = &plus
	svc := NewStripeService(repo, testStripeConfig("https://api.stripe.invalid"), nil, nil)

	payload := stripeEventPayload("evt_del", "customer.subscription.deleted", map[string]any{
		"customer": "cus_2",
		"status":   "canceled",
	})
	header := signStripePayload(t, payload, testWebhookSecret, time.Now().UTC())
	if err := svc.HandleWebhook(context.Background(), StripeWebhookInput{Payload: payload, Signature: header}); err != nil {
		t.Fatalf("webhook failed: %v", err)
	}
	if repo.stripeTier["u2"] != nil {
		t.Fatal("canceled subscription did not clear stripe tier")
	}

	// Store tier untouched: user keeps store entitlements.
	if repo.byID["u2"].SubscriptionTier != "" {
		t.Fatal("cancellation must not touch the store subscription columns")
	}
}

func TestHandleWebhookUnresolvableCustomerIgnored(t *testing.T) {
	repo := newFakeUserRepo()
	svc := NewStripeService(repo, testStripeConfig("https://api.stripe.invalid"), nil, nil)
	payload := stripeEventPayload("evt_x", "customer.subscription.updated", map[string]any{
		"customer": "cus_nobody",
		"status":   "active",
	})
	header := signStripePayload(t, payload, testWebhookSecret, time.Now().UTC())
	if err := svc.HandleWebhook(context.Background(), StripeWebhookInput{Payload: payload, Signature: header}); err != nil {
		t.Fatalf("unresolvable customer should be ignored, got: %v", err)
	}
}

func TestStripePortalSessionRequiresCustomer(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_ = json.NewEncoder(w).Encode(map[string]any{"url": "https://billing.stripe.com/session"})
	}))
	defer srv.Close()
	repo := newFakeUserRepo()
	repo.byID["u3"] = &domain.User{ID: "u3"}
	repo.byID["u4"] = &domain.User{ID: "u4", StripeCustomerID: strPtrVal("cus_4")}
	svc := NewStripeService(repo, testStripeConfig(srv.URL), nil, nil)

	if _, err := svc.CreatePortalSession(context.Background(), "u3"); err == nil {
		t.Fatal("portal without bound customer accepted")
	}
	res, err := svc.CreatePortalSession(context.Background(), "u4")
	if err != nil || res.PortalURL == "" {
		t.Fatalf("portal with customer failed: %v", err)
	}
}

func strPtrVal(s string) *string { return &s }
