package domain

import "time"

// Tier names shared by services and middleware (single source of truth).
const (
	TierFree              = "free"
	TierPepinilloPlus     = "pepinillo_plus"
	TierEverywhereMonthly = "everywhere_monthly"
	TierEverywhereAnnual  = "everywhere_annual"
)

// EffectiveTierAt resolves the tier that actually gates features at time now:
// the strongest active entitlement wins across providers (an unexpired
// Everywhere+ subscription — store or Stripe — beats a lifetime flag; a
// lifetime flag beats free). Pure function for testability.
func (u *User) EffectiveTierAt(now time.Time) string {
	legacy := u.legacyEffectiveTierAt(now)
	return MaxTier(legacy, u.StripeEffectiveTierAt(now))
}

func (u *User) legacyEffectiveTierAt(now time.Time) string {
	switch u.SubscriptionTier {
	case TierEverywhereMonthly, TierEverywhereAnnual:
		if u.SubscriptionExpiresAt == nil || u.SubscriptionExpiresAt.After(now) {
			return u.SubscriptionTier
		}
		// Subscription expired — fall through to entitlement check.
	}

	if u.PepinilloPlusEntitlementAt != nil {
		return TierPepinilloPlus
	}
	if u.SubscriptionTier == TierPepinilloPlus {
		return TierPepinilloPlus
	}
	return TierFree
}

// StripeEffectiveTierAt resolves the tier granted by the web (Stripe) billing
// path: an active Stripe subscription tier, or pepinillo_plus when the
// one-time web purchase was confirmed.
func (u *User) StripeEffectiveTierAt(now time.Time) string {
	if u.StripeTier == nil {
		return TierFree
	}
	switch *u.StripeTier {
	case TierEverywhereMonthly, TierEverywhereAnnual:
		if u.StripeExpiresAt != nil && u.StripeExpiresAt.After(now) {
			return *u.StripeTier
		}
		return TierFree
	case TierPepinilloPlus:
		return TierPepinilloPlus
	default:
		return TierFree
	}
}

// MaxTier returns the stronger of two canonical tiers. Ordering:
// everywhere_annual > everywhere_monthly > pepinillo_plus > free. A lifetime
// Pepinillo+ is "strong" for its own scope; Everywhere tiers additionally
// unlock sync/AI, so they rank above it.
func MaxTier(a, b string) string {
	if TierRank(a) >= TierRank(b) {
		return a
	}
	return b
}

func TierRank(tier string) int {
	switch tier {
	case TierEverywhereAnnual:
		return 4
	case TierEverywhereMonthly:
		return 3
	case TierPepinilloPlus:
		return 2
	default:
		return 0
	}
}

type User struct {
	ID                    string     `json:"id" gorm:"type:uuid;primaryKey"`
	Email                 string     `json:"email" gorm:"uniqueIndex;not null"`
	Name                  string     `json:"name" gorm:"not null"`
	PasswordHash          *string    `json:"-"`
	ImageURL              *string    `json:"imageUrl"`
	SubscriptionTier      string     `json:"subscriptionTier" gorm:"default:free;not null"`
	SubscriptionExpiresAt *time.Time `json:"subscriptionExpiresAt"`
	EmailVerified         bool       `json:"emailVerified" gorm:"default:false;not null"`
	EmailVerifiedAt       *time.Time `json:"emailVerifiedAt"`
	PendingEmail          *string    `json:"pendingEmail,omitempty" gorm:"index"`
	EmailChangedAt        *time.Time `json:"emailChangedAt,omitempty"`

	// AI Credits (Everywhere/AI+ tier)
	AiCreditsBalance         int        `json:"aiCreditsBalance" gorm:"default:0;not null"`
	AiCreditsLastRefreshedAt *time.Time `json:"aiCreditsLastRefreshedAt"`

	// Pepinillo+ one-time purchase entitlement timestamp (set when purchase is
	// confirmed, never cleared by Everywhere+ activation/cancellation).
	PepinilloPlusEntitlementAt *time.Time `json:"pepinilloPlusEntitlementAt,omitempty"`

	// SyncDeviceID binds server-side backup to ONE device for Free and
	// Pepinillo+ tiers (#942 S5): the first successful sync upload claims it.
	// Empty = unbound. Everywhere+ tiers bypass the check (multi-device).
	SyncDeviceID string `json:"-" gorm:"column:sync_device_id"`

	// MetricsOptIn is explicit consent to include this user in the aggregated,
	// PII-free usage metrics served by /internal/stats. Defaults to false.
	MetricsOptIn bool `json:"metricsOptIn" gorm:"default:false;not null"`

	// Google OAuth
	GoogleID      *string `json:"googleId,omitempty" gorm:"uniqueIndex"`
	GoogleEmail   *string `json:"googleEmail,omitempty"`
	GoogleName    *string `json:"googleName,omitempty"`
	GooglePicture *string `json:"googlePicture,omitempty"`

	// Apple OAuth
	AppleID    *string `json:"appleId,omitempty" gorm:"uniqueIndex"`
	AppleEmail *string `json:"appleEmail,omitempty"`
	AppleName  *string `json:"appleName,omitempty"`

	// Stripe billing (web purchases). Kept separate from the store columns so
	// the effective tier resolves as the maximum across providers.
	StripeCustomerID *string    `json:"stripeCustomerId,omitempty" gorm:"index"`
	StripeTier       *string    `json:"stripeTier,omitempty"`
	StripeExpiresAt  *time.Time `json:"stripeExpiresAt,omitempty"`

	CreatedAt time.Time `json:"createdAt"`
	UpdatedAt time.Time `json:"updatedAt"`
}
