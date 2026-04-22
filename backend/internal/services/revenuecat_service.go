package services

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"

	"pepinillo/backend/internal/ports"
)

var (
	ErrRevenueCatNotConfigured = errors.New("revenuecat_not_configured")
	ErrRevenueCatAPI           = errors.New("revenuecat_api_error")
	ErrInvalidWebhookAuth      = errors.New("invalid_webhook_auth")
)

type RevenueCatConfig struct {
	APIKey           string
	WebhookAuthToken string
	APIBaseURL       string
}

type RevenueCatService struct {
	users      ports.UserRepository
	behavior   ports.BehaviorLogger
	httpClient *http.Client
	cfg        RevenueCatConfig
}

func NewRevenueCatService(users ports.UserRepository, cfg RevenueCatConfig, behavior ...ports.BehaviorLogger) *RevenueCatService {
	cfg.APIBaseURL = strings.TrimSuffix(cfg.APIBaseURL, "/")

	var behaviorLogger ports.BehaviorLogger
	if len(behavior) > 0 {
		behaviorLogger = behavior[0]
	}

	return &RevenueCatService{
		users:      users,
		behavior:   behaviorLogger,
		httpClient: &http.Client{Timeout: 10 * time.Second},
		cfg:        cfg,
	}
}

// RevenueCat webhook payload structures
type RevenueCatWebhookPayload struct {
	APIVersion string          `json:"api_version"`
	Event      RevenueCatEvent `json:"event"`
}

type RevenueCatEvent struct {
	Type           string   `json:"type"`
	ID             string   `json:"id"`
	AppUserID      string   `json:"app_user_id"`
	Aliases        []string `json:"aliases"`
	ProductID      string   `json:"product_id"`
	EntitlementIDs []string `json:"entitlement_ids"`
	PeriodType     string   `json:"period_type"`
	PurchasedAtMs  int64    `json:"purchased_at_ms"`
	ExpirationAtMs int64    `json:"expiration_at_ms"`
	Store          string   `json:"store"`
	Environment    string   `json:"environment"`
	IsFamilyShare  bool     `json:"is_family_share"`
	Currency       string   `json:"currency"`
	Price          float64  `json:"price"`
}

// RevenueCat subscriber API response structures
type RevenueCatSubscriberResponse struct {
	Subscriber RevenueCatSubscriber `json:"subscriber"`
}

type RevenueCatSubscriber struct {
	Entitlements  map[string]RevenueCatEntitlement         `json:"entitlements"`
	Subscriptions map[string]RevenueCatSubscriptionProduct `json:"subscriptions"`
}

type RevenueCatEntitlement struct {
	ExpiresDate interface{} `json:"expires_date"` // Can be null or string
}

type RevenueCatSubscriptionProduct struct {
	ExpiresDate     interface{} `json:"expires_date"`
	PeriodType      string      `json:"period_type"`
	PurchasedDate   interface{} `json:"purchased_date"`
	Store           string      `json:"store"`
	IsSandbox       bool        `json:"is_sandbox"`
	UnsubscribeDate interface{} `json:"unsubscribe_date"`
	BillingIssues   interface{} `json:"billing_issues"`
}

// ValidateWebhookAuth verifies the webhook authorization token
func (s *RevenueCatService) ValidateWebhookAuth(authHeader string) error {
	if s.cfg.WebhookAuthToken == "" {
		return ErrRevenueCatNotConfigured
	}

	// Remove "Bearer " prefix if present
	token := strings.TrimPrefix(strings.TrimSpace(authHeader), "Bearer ")
	if token != s.cfg.WebhookAuthToken {
		return ErrInvalidWebhookAuth
	}
	return nil
}

// ProcessWebhookEvent handles incoming RevenueCat webhook events
func (s *RevenueCatService) ProcessWebhookEvent(ctx context.Context, payload *RevenueCatWebhookPayload) error {
	if payload == nil || payload.Event.AppUserID == "" {
		return ErrInvalidBillingPayload
	}

	appUserID := payload.Event.AppUserID
	eventType := strings.ToUpper(strings.TrimSpace(payload.Event.Type))

	// Find user by their RevenueCat app_user_id (typically their user ID)
	// In this implementation, we assume app_user_id maps directly to our user ID
	user, err := s.users.GetByID(ctx, appUserID)
	if err != nil {
		s.logRevenueCatEvent(ctx, appUserID, "webhook_process_failed", map[string]any{
			"reason":     err.Error(),
			"event_type": eventType,
		})
		return err
	}
	if user == nil {
		s.logRevenueCatEvent(ctx, appUserID, "webhook_user_not_found", map[string]any{
			"event_type": eventType,
		})
		return ErrUserNotFound
	}

	// Process different event types
	switch eventType {
	case "INITIAL_PURCHASE", "RENEWAL", "PRODUCT_CHANGE":
		return s.handlePurchaseEvent(ctx, user.ID, payload.Event)
	case "CANCELLATION", "EXPIRATION":
		return s.handleCancellationEvent(ctx, user.ID, payload.Event)
	case "BILLING_ISSUE":
		return s.handleBillingIssueEvent(ctx, user.ID, payload.Event)
	case "NON_RENEWING_PURCHASE":
		return s.handleNonRenewingPurchaseEvent(ctx, user.ID, payload.Event)
	case "SUBSCRIBER_ALIAS":
		// Just log it for now
		s.logRevenueCatEvent(ctx, user.ID, "subscriber_alias_merged", map[string]any{
			"aliases": payload.Event.Aliases,
		})
		return nil
	default:
		s.logRevenueCatEvent(ctx, user.ID, "webhook_unknown_event", map[string]any{
			"event_type": eventType,
		})
		return nil
	}
}

func (s *RevenueCatService) handlePurchaseEvent(ctx context.Context, userID string, event RevenueCatEvent) error {
	// Determine tier from product ID and entitlements
	tier, expiresAt := s.mapRevenueCatProductToTier(event)

	user, err := s.users.GetByID(ctx, userID)
	if err != nil {
		s.logRevenueCatEvent(ctx, userID, "webhook_process_failed", map[string]any{
			"reason":     err.Error(),
			"event_type": event.Type,
		})
		return err
	}

	user.SubscriptionTier = tier
	user.SubscriptionExpiresAt = expiresAt
	if err := s.users.Update(ctx, user); err != nil {
		s.logRevenueCatEvent(ctx, userID, "webhook_update_failed", map[string]any{
			"reason":     err.Error(),
			"event_type": event.Type,
		})
		return err
	}

	s.logRevenueCatEvent(ctx, userID, "webhook_purchase_processed", map[string]any{
		"event_type": event.Type,
		"tier":       tier,
		"product_id": event.ProductID,
		"store":      event.Store,
	})
	return nil
}

func (s *RevenueCatService) handleCancellationEvent(ctx context.Context, userID string, event RevenueCatEvent) error {
	user, err := s.users.GetByID(ctx, userID)
	if err != nil {
		s.logRevenueCatEvent(ctx, userID, "webhook_process_failed", map[string]any{
			"reason":     err.Error(),
			"event_type": event.Type,
		})
		return err
	}

	// For EXPIRATION, downgrade immediately
	// For CANCELLATION, we can set an expiry date if provided
	if event.Type == "EXPIRATION" {
		user.SubscriptionTier = "free"
		user.SubscriptionExpiresAt = nil
	} else if event.Type == "CANCELLATION" {
		// Keep the tier but mark it as expired at the expiration time
		user.SubscriptionTier = "free"
		if event.ExpirationAtMs > 0 {
			expiresAt := time.UnixMilli(event.ExpirationAtMs).UTC()
			user.SubscriptionExpiresAt = &expiresAt
		} else {
			user.SubscriptionExpiresAt = nil
		}
	}

	if err := s.users.Update(ctx, user); err != nil {
		s.logRevenueCatEvent(ctx, userID, "webhook_update_failed", map[string]any{
			"reason":     err.Error(),
			"event_type": event.Type,
		})
		return err
	}

	s.logRevenueCatEvent(ctx, userID, "webhook_cancellation_processed", map[string]any{
		"event_type": event.Type,
	})
	return nil
}

func (s *RevenueCatService) handleBillingIssueEvent(ctx context.Context, userID string, event RevenueCatEvent) error {
	// Log the billing issue but keep the current tier (grace period)
	s.logRevenueCatEvent(ctx, userID, "webhook_billing_issue", map[string]any{
		"product_id": event.ProductID,
		"store":      event.Store,
	})
	return nil
}

func (s *RevenueCatService) handleNonRenewingPurchaseEvent(ctx context.Context, userID string, event RevenueCatEvent) error {
	// Non-renewing purchases are typically one-time purchases or lifetime subscriptions
	user, err := s.users.GetByID(ctx, userID)
	if err != nil {
		s.logRevenueCatEvent(ctx, userID, "webhook_process_failed", map[string]any{
			"reason":     err.Error(),
			"event_type": event.Type,
		})
		return err
	}

	// Map to tier (typically lifetime)
	tier, expiresAt := s.mapRevenueCatProductToTier(event)
	user.SubscriptionTier = tier
	user.SubscriptionExpiresAt = expiresAt

	if err := s.users.Update(ctx, user); err != nil {
		s.logRevenueCatEvent(ctx, userID, "webhook_update_failed", map[string]any{
			"reason":     err.Error(),
			"event_type": event.Type,
		})
		return err
	}

	s.logRevenueCatEvent(ctx, userID, "webhook_non_renewing_purchase_processed", map[string]any{
		"tier":       tier,
		"product_id": event.ProductID,
	})
	return nil
}

// mapRevenueCatProductToTier maps RevenueCat product ID and expiration to our tier system
func (s *RevenueCatService) mapRevenueCatProductToTier(event RevenueCatEvent) (string, *time.Time) {
	// Check if any paid entitlement is active.
	// RevenueCat entitlements: "everywhere_plus" (subscriptions), "pepinillo_plus" (lifetime one-time).
	hasProEntitlement := false
	for _, ent := range event.EntitlementIDs {
		norm := strings.ToLower(strings.TrimSpace(ent))
		if norm == "everywhere_plus" || norm == "pepinillo_plus" {
			hasProEntitlement = true
			break
		}
	}

	if !hasProEntitlement {
		return "free", nil
	}

	// Determine canonical tier from product ID.
	// Product IDs: com.pepinillo.app.pro.lifetime, .monthly, .annual
	product := strings.ToLower(strings.TrimSpace(event.ProductID))

	var tier string
	switch {
	case strings.Contains(product, "lifetime"):
		// One-time purchase — Pepinillo+ (local premium, no backend sync)
		tier = "pepinillo_plus"
	case strings.Contains(product, "annual") || strings.Contains(product, "yearly"):
		tier = "everywhere_annual"
	case strings.Contains(product, "monthly") || strings.Contains(product, "month"):
		tier = "everywhere_monthly"
	default:
		// Fallback: treat unknown product as monthly subscription
		tier = "everywhere_monthly"
	}

	// Lifetime has no expiration; subscriptions may carry one.
	var expiresAt *time.Time
	if tier != "pepinillo_plus" && event.ExpirationAtMs > 0 {
		expires := time.UnixMilli(event.ExpirationAtMs).UTC()
		expiresAt = &expires
	}

	return tier, expiresAt
}

// VerifyViaRevenueCat queries RevenueCat API to get subscriber's current entitlements
func (s *RevenueCatService) VerifyViaRevenueCat(ctx context.Context, userID string) (*VerifyReceiptResult, error) {
	if s.cfg.APIKey == "" || s.cfg.APIBaseURL == "" {
		return nil, ErrRevenueCatNotConfigured
	}

	startedAt := time.Now().UTC()

	// Query RevenueCat API for subscriber info
	endpoint := fmt.Sprintf("%s/subscribers/%s", s.cfg.APIBaseURL, userID)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+s.cfg.APIKey)
	req.Header.Set("Accept", "application/json")

	resp, err := s.httpClient.Do(req)
	if err != nil {
		s.logRevenueCatEvent(ctx, userID, "verify_revenuecat_failed", map[string]any{
			"reason":     err.Error(),
			"durationMs": time.Since(startedAt).Milliseconds(),
		})
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusUnauthorized || resp.StatusCode == http.StatusForbidden {
		return nil, ErrRevenueCatNotConfigured
	}
	if resp.StatusCode == http.StatusNotFound {
		// Subscriber not found in RevenueCat, treat as free
		return &VerifyReceiptResult{
			Valid:                 true,
			SubscriptionTier:      "free",
			SubscriptionExpiresAt: nil,
			Source:                "revenuecat",
		}, nil
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, fmt.Errorf("revenuecat_verification_failed: status_%d", resp.StatusCode)
	}

	var payload RevenueCatSubscriberResponse
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		s.logRevenueCatEvent(ctx, userID, "verify_revenuecat_failed", map[string]any{
			"reason":     fmt.Sprintf("decode error: %v", err),
			"durationMs": time.Since(startedAt).Milliseconds(),
		})
		return nil, err
	}

	// Extract entitlement status
	tier, expiresAt := s.extractRevenueCatEntitlements(payload.Subscriber)

	s.logRevenueCatEvent(ctx, userID, "verify_revenuecat_succeeded", map[string]any{
		"tier":       tier,
		"durationMs": time.Since(startedAt).Milliseconds(),
	})

	return &VerifyReceiptResult{
		Valid:                 true,
		SubscriptionTier:      tier,
		SubscriptionExpiresAt: expiresAt,
		Source:                "revenuecat",
	}, nil
}

// extractRevenueCatEntitlements determines the canonical tier and expiration from a RevenueCat subscriber.
// RevenueCat entitlements: "everywhere_plus" (subscriptions), "pepinillo_plus" (lifetime one-time).
func (s *RevenueCatService) extractRevenueCatEntitlements(subscriber RevenueCatSubscriber) (string, *time.Time) {
	// Check pepinillo_plus first (one-time, lifetime — never expires).
	if _, hasPepinilloPlus := subscriber.Entitlements["pepinillo_plus"]; hasPepinilloPlus {
		return "pepinillo_plus", nil
	}

	// Check everywhere_plus (subscription).
	everywhereEntitlement, hasEverywhere := subscriber.Entitlements["everywhere_plus"]
	if !hasEverywhere {
		return "free", nil
	}

	// Check if the subscription entitlement has expired.
	if everywhereEntitlement.ExpiresDate != nil {
		expiresStr, ok := everywhereEntitlement.ExpiresDate.(string)
		if ok && expiresStr != "" && expiresStr != "null" {
			if expiresTime, err := time.Parse(time.RFC3339, expiresStr); err == nil {
				if time.Now().UTC().After(expiresTime) {
					return "free", nil
				}
				// Entitlement is active — determine monthly vs annual from subscriptions below.
			}
		}
	}

	// Walk active subscriptions to determine monthly vs annual and exact expiration.
	tier := "everywhere_monthly" // safe default
	var expiresAt *time.Time

	for productID, subscription := range subscriber.Subscriptions {
		productLower := strings.ToLower(productID)

		// Skip cancelled subscriptions.
		if subscription.UnsubscribeDate != nil {
			unsubStr, ok := subscription.UnsubscribeDate.(string)
			if ok && unsubStr != "" && unsubStr != "null" {
				continue
			}
		}

		// Map product ID to canonical tier.
		if strings.Contains(productLower, "annual") || strings.Contains(productLower, "yearly") {
			tier = "everywhere_annual"
		} else if strings.Contains(productLower, "monthly") || strings.Contains(productLower, "month") {
			if tier == "everywhere_monthly" {
				tier = "everywhere_monthly"
			}
		}

		// Extract expiration date from the active subscription.
		if expiresAt == nil && subscription.ExpiresDate != nil {
			expiresStr, ok := subscription.ExpiresDate.(string)
			if ok && expiresStr != "" && expiresStr != "null" {
				if expiresTime, err := time.Parse(time.RFC3339, expiresStr); err == nil {
					if time.Now().UTC().Before(expiresTime) {
						expiresAt = &expiresTime
					}
				}
			}
		}
	}

	return tier, expiresAt
}

func (s *RevenueCatService) logRevenueCatEvent(ctx context.Context, userID, eventType string, eventData map[string]any) {
	if s.behavior == nil {
		return
	}
	_ = s.behavior.LogEvent(ctx, userID, eventType, eventData)
}
