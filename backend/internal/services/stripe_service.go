package services

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"pepinillo/backend/internal/domain"
	"pepinillo/backend/internal/ports"
)

// Stripe web-billing. Hand-rolled REST (form-encoded) + webhook signature
// verification, mirroring the repo idiom of billing_service.go (App Store
// JWS / Google Play OAuth are also hand-rolled over net/http). No SDK
// dependency; every external call is wrapped for testability via baseURL +
// injectable http.Client.

var (
	ErrStripeNotConfigured    = errors.New("billing_provider_not_configured")
	ErrStripeInvalidPlan      = errors.New("invalid_billing_payload")
	ErrStripeInvalidSignature = errors.New("invalid_stripe_signature")
	ErrStripeUnknownCustomer  = errors.New("stripe_customer_unlinked")
	ErrStripeAPIFailed        = errors.New("stripe_api_failed")
)

const (
	StripePlanPepinilloPlus     = "pepinillo_plus"
	StripePlanEverywhereMonthly = "everywhere_monthly"
	StripePlanEverywhereAnnual  = "everywhere_annual"
)

type StripeConfig struct {
	SecretKey              string
	WebhookSecret          string
	PricePepinilloPlus     string
	PriceEverywhereMonthly string
	PriceEverywhereAnnual  string
	SuccessURL             string
	CancelURL              string
	APIBaseURL             string // test override; default https://api.stripe.com
	APIVersion             string
}

func (c *StripeConfig) normalized() StripeConfig {
	cfg := *c
	cfg.APIBaseURL = strings.TrimSuffix(cfg.APIBaseURL, "/")
	if cfg.APIBaseURL == "" {
		cfg.APIBaseURL = "https://api.stripe.com"
	}
	if cfg.APIVersion == "" {
		cfg.APIVersion = "2024-06-20"
	}
	return cfg
}

func (c StripeConfig) priceFor(plan string) (string, bool) {
	switch plan {
	case StripePlanPepinilloPlus:
		return c.PricePepinilloPlus, c.PricePepinilloPlus != ""
	case StripePlanEverywhereMonthly:
		return c.PriceEverywhereMonthly, c.PriceEverywhereMonthly != ""
	case StripePlanEverywhereAnnual:
		return c.PriceEverywhereAnnual, c.PriceEverywhereAnnual != ""
	default:
		return "", false
	}
}

type StripeService struct {
	users      ports.UserRepository
	behavior   ports.BehaviorLogger
	httpClient *http.Client
	cfg        StripeConfig
	log        *slog.Logger
}

func NewStripeService(users ports.UserRepository, cfg StripeConfig, behavior ports.BehaviorLogger, log *slog.Logger) *StripeService {
	return &StripeService{
		users:      users,
		behavior:   behavior,
		httpClient: &http.Client{Timeout: 15 * time.Second},
		cfg:        cfg.normalized(),
		log:        log,
	}
}

func (s *StripeService) Configured() bool {
	return strings.TrimSpace(s.cfg.SecretKey) != ""
}

// ---------- Checkout / Portal ----------

type CheckoutSessionResult struct {
	CheckoutURL string `json:"checkoutUrl"`
}

type PortalSessionResult struct {
	PortalURL string `json:"portalUrl"`
}

// CreateCheckoutSession opens a Stripe Checkout for the plan: one-time
// payment for Pepinillo+, subscription for Everywhere. The returned URL is
// where the web client redirects the browser.
func (s *StripeService) CreateCheckoutSession(ctx context.Context, userID, plan, successURL, cancelURL string) (*CheckoutSessionResult, error) {
	if !s.Configured() {
		return nil, ErrStripeNotConfigured
	}
	price, ok := s.cfg.priceFor(plan)
	if !ok {
		return nil, ErrStripeInvalidPlan
	}
	user, err := s.users.GetByID(ctx, userID)
	if err != nil {
		return nil, err
	}
	if user == nil {
		return nil, ErrUserNotFound
	}

	form := url.Values{}
	form.Set("mode", checkoutModeFor(plan))
	form.Set("line_items[0][price]", price)
	form.Set("line_items[0][quantity]", "1")
	form.Set("client_reference_id", userID)
	form.Set("metadata[user_id]", userID)
	form.Set("metadata[plan]", plan)
	if successURL != "" {
		form.Set("success_url", successURL)
	} else {
		form.Set("success_url", s.upgradeURL(s.cfg.SuccessURL, "checkout=success"))
	}
	form.Set("cancel_url", firstNonEmpty(cancelURL, s.upgradeURL(s.cfg.CancelURL, "checkout=cancel")))
	if user.Email != "" {
		form.Set("customer_email", user.Email)
	}
	if user.StripeCustomerID != nil && *user.StripeCustomerID != "" {
		form.Set("customer", *user.StripeCustomerID)
		form.Del("customer_email")
	}

	var payload struct {
		ID       string `json:"id"`
		URL      string `json:"url"`
		Customer string `json:"customer"`
	}
	if err := s.apiForm(ctx, "POST", "/v1/checkout/sessions", form, &payload); err != nil {
		return nil, err
	}
	if payload.URL == "" {
		return nil, ErrStripeAPIFailed
	}
	// Bind the customer as soon as Stripe assigns one so later webhooks
	// (async events) can resolve the user even without client_reference_id.
	if payload.Customer != "" && (user.StripeCustomerID == nil || *user.StripeCustomerID != payload.Customer) {
		if err := s.users.SetStripeCustomer(ctx, userID, payload.Customer); err != nil {
			s.logWarn("stripe_bind_customer_failed", userID, err)
		}
	}
	s.logBilling(ctx, userID, "stripe_checkout_created", map[string]any{"plan": plan})
	return &CheckoutSessionResult{CheckoutURL: payload.URL}, nil
}

// CreatePortalSession opens the Stripe Billing Portal so the user can manage
// (cancel/update payment method) their web subscription.
func (s *StripeService) CreatePortalSession(ctx context.Context, userID string) (*PortalSessionResult, error) {
	if !s.Configured() {
		return nil, ErrStripeNotConfigured
	}
	user, err := s.users.GetByID(ctx, userID)
	if err != nil {
		return nil, err
	}
	if user == nil {
		return nil, ErrUserNotFound
	}
	if user.StripeCustomerID == nil || *user.StripeCustomerID == "" {
		return nil, ErrStripeUnknownCustomer
	}

	form := url.Values{}
	form.Set("customer", *user.StripeCustomerID)
	form.Set("return_url", s.defaultURL(s.cfg.SuccessURL, "/account"))

	var payload struct {
		URL string `json:"url"`
	}
	if err := s.apiForm(ctx, "POST", "/v1/billing_portal/sessions", form, &payload); err != nil {
		return nil, err
	}
	if payload.URL == "" {
		return nil, ErrStripeAPIFailed
	}
	return &PortalSessionResult{PortalURL: payload.URL}, nil
}

// ---------- Webhook ----------

type StripeWebhookInput struct {
	Payload   []byte
	Signature string
}

// HandleWebhook verifies the Stripe signature, dedupes by event id and
// reconciles the user's Stripe tier state. Always answers 2xx for events we
// choose to ignore (Stripe retries would otherwise hammer us forever).
func (s *StripeService) HandleWebhook(ctx context.Context, input StripeWebhookInput) error {
	if !s.Configured() || strings.TrimSpace(s.cfg.WebhookSecret) == "" {
		return ErrStripeNotConfigured
	}
	event, err := VerifyStripeSignature(input.Payload, input.Signature, s.cfg.WebhookSecret, 5*time.Minute)
	if err != nil {
		return err
	}

	claimed, err := s.users.ClaimWebhookEvent(ctx, event.ID, "stripe")
	if err != nil {
		return err
	}
	if !claimed {
		return nil // redelivery already processed
	}

	switch event.Type {
	case "checkout.session.completed":
		return s.handleCheckoutCompleted(ctx, event)
	case "customer.subscription.updated", "customer.subscription.deleted":
		return s.handleSubscriptionChanged(ctx, event)
	default:
		return nil
	}
}

type stripeEvent struct {
	ID   string          `json:"id"`
	Type string          `json:"type"`
	Data json.RawMessage `json:"data"`
}

func (e stripeEvent) object() (map[string]any, error) {
	var wrapper struct {
		Object map[string]any `json:"object"`
	}
	if err := json.Unmarshal(e.Data, &wrapper); err != nil {
		return nil, err
	}
	return wrapper.Object, nil
}

func (s *StripeService) handleCheckoutCompleted(ctx context.Context, event stripeEvent) error {
	obj, err := event.object()
	if err != nil {
		return nil
	}
	userID, _ := obj["client_reference_id"].(string)
	customer, _ := obj["customer"].(string)
	if userID == "" {
		userID, _ = obj["metadata"].(map[string]any)["user_id"].(string)
	}
	if userID == "" && customer != "" {
		user, err := s.users.GetByStripeCustomerID(ctx, customer)
		if err != nil || user == nil {
			return nil // unresolvable customer: ignore
		}
		userID = user.ID
	}
	if userID == "" {
		return nil
	}

	plan, _ := obj["metadata"].(map[string]any)["plan"].(string)
	// One-time purchases never expire; subscriptions get their period end.
	var expires *time.Time
	if currentPeriod, ok := obj["current_period_end"].(float64); ok && checkoutModeFor(plan) == "subscription" {
		t := time.Unix(int64(currentPeriod), 0).UTC()
		expires = &t
	}
	return s.applyStripeState(ctx, userID, customer, plan, expires)
}

func (s *StripeService) handleSubscriptionChanged(ctx context.Context, event stripeEvent) error {
	obj, err := event.object()
	if err != nil {
		return nil
	}
	customer, _ := obj["customer"].(string)
	if customer == "" {
		return nil
	}
	user, err := s.users.GetByStripeCustomerID(ctx, customer)
	if err != nil || user == nil {
		return nil
	}

	status, _ := obj["status"].(string)
	if status == "canceled" || status == "unpaid" || status == "incomplete_expired" {
		return s.applyStripeState(ctx, user.ID, customer, "", nil)
	}
	priceID := extractPriceID(obj)
	plan := s.planForPrice(priceID)
	var expires *time.Time
	if currentPeriod, ok := obj["current_period_end"].(float64); ok {
		t := time.Unix(int64(currentPeriod), 0).UTC()
		expires = &t
	}
	return s.applyStripeState(ctx, user.ID, customer, plan, expires)
}

func extractPriceID(obj map[string]any) string {
	items, ok := obj["items"].(map[string]any)
	if !ok {
		return ""
	}
	data, ok := items["data"].([]any)
	if !ok || len(data) == 0 {
		return ""
	}
	first, ok := data[0].(map[string]any)
	if !ok {
		return ""
	}
	price, _ := first["price"].(map[string]any)
	if price == nil {
		return ""
	}
	id, _ := price["id"].(string)
	return id
}

// applyStripeState persists the Stripe tier state.
func (s *StripeService) applyStripeState(ctx context.Context, userID, customer, plan string, expires *time.Time) error {
	var tierPtr *string
	if tier := tierForPlan(plan); tier != domain.TierFree {
		t := tier
		tierPtr = &t
	}
	if customer != "" {
		if err := s.users.SetStripeCustomer(ctx, userID, customer); err != nil {
			return err
		}
	}
	if err := s.users.UpdateStripeState(ctx, userID, tierPtr, expires); err != nil {
		return err
	}
	s.logBilling(ctx, userID, "stripe_state_updated", map[string]any{"plan": plan})
	return nil
}

func (s *StripeService) planForPrice(priceID string) string {
	switch priceID {
	case s.cfg.PricePepinilloPlus:
		return StripePlanPepinilloPlus
	case s.cfg.PriceEverywhereMonthly:
		return StripePlanEverywhereMonthly
	case s.cfg.PriceEverywhereAnnual:
		return StripePlanEverywhereAnnual
	default:
		return ""
	}
}

func tierForPlan(plan string) string {
	switch plan {
	case StripePlanPepinilloPlus:
		return domain.TierPepinilloPlus
	case StripePlanEverywhereMonthly:
		return domain.TierEverywhereMonthly
	case StripePlanEverywhereAnnual:
		return domain.TierEverywhereAnnual
	default:
		return domain.TierFree
	}
}

func checkoutModeFor(plan string) string {
	if plan == StripePlanPepinilloPlus {
		return "payment"
	}
	return "subscription"
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if strings.TrimSpace(v) != "" {
			return v
		}
	}
	return ""
}

func (s *StripeService) defaultURL(base, path string) string {
	base = strings.TrimSuffix(strings.TrimSpace(base), "/")
	if base == "" {
		return path
	}
	return base + path
}

// upgradeURL joins the configured base (which already ends in /upgrade) with
// a checkout result query, without duplicating the path.
func (s *StripeService) upgradeURL(base, query string) string {
	base = strings.TrimSuffix(strings.TrimSpace(base), "/")
	if base == "" {
		return "/upgrade?" + query
	}
	if strings.HasSuffix(base, "/upgrade") {
		return base + "?" + query
	}
	return base + "/upgrade?" + query
}

// ---------- Stripe REST + signature helpers ----------

func (s *StripeService) apiForm(ctx context.Context, method, path string, form url.Values, out any) error {
	req, err := http.NewRequestWithContext(ctx, method, s.cfg.APIBaseURL+path, strings.NewReader(form.Encode()))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+s.cfg.SecretKey)
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Set("Stripe-Version", s.cfg.APIVersion)

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("%w: status_%d", ErrStripeAPIFailed, resp.StatusCode)
	}
	return json.Unmarshal(body, out)
}

// VerifyStripeSignature implements Stripe's v1 signature scheme:
// header `t=<ts>,v1=<hmac>` where hmac = HMAC-SHA256(secret, "<ts>.<payload>").
// Rejects stale timestamps beyond tolerance and missing/mismatched v1.
func VerifyStripeSignature(payload []byte, header, secret string, tolerance time.Duration) (stripeEvent, error) {
	var event stripeEvent
	if header == "" {
		return event, ErrStripeInvalidSignature
	}
	var ts string
	var v1 string
	for _, part := range strings.Split(header, ",") {
		kv := strings.SplitN(strings.TrimSpace(part), "=", 2)
		if len(kv) != 2 {
			continue
		}
		switch kv[0] {
		case "t":
			ts = kv[1]
		case "v1":
			if v1 == "" {
				v1 = kv[1]
			}
		}
	}
	if ts == "" || v1 == "" {
		return event, ErrStripeInvalidSignature
	}
	tsUnix, err := strconv.ParseInt(ts, 10, 64)
	if err != nil {
		return event, ErrStripeInvalidSignature
	}
	if tolerance > 0 && time.Since(time.Unix(tsUnix, 0)) > tolerance {
		return event, ErrStripeInvalidSignature
	}

	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte(ts + "." + string(payload)))
	expected := hex.EncodeToString(mac.Sum(nil))
	if !hmac.Equal([]byte(expected), []byte(v1)) {
		return event, ErrStripeInvalidSignature
	}

	if err := json.Unmarshal(payload, &event); err != nil {
		return event, ErrStripeInvalidSignature
	}
	if event.ID == "" || event.Type == "" {
		return event, ErrStripeInvalidSignature
	}
	return event, nil
}

func (s *StripeService) logBilling(ctx context.Context, userID, event string, data map[string]any) {
	if s.behavior != nil {
		_ = s.behavior.LogEvent(ctx, userID, event, data)
	}
}

func (s *StripeService) logWarn(msg string, userID string, err error) {
	if s.log != nil {
		s.log.Warn(msg, "user_id", userID, "error", err.Error())
	}
}
