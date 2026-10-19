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
// an unexpired subscription wins; otherwise a lifetime entitlement (explicit
// flag or sticky tier) wins; otherwise free. Pure function for testability.
func (u *User) EffectiveTierAt(now time.Time) string {
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

	// Google OAuth
	GoogleID      *string `json:"googleId,omitempty" gorm:"uniqueIndex"`
	GoogleEmail   *string `json:"googleEmail,omitempty"`
	GoogleName    *string `json:"googleName,omitempty"`
	GooglePicture *string `json:"googlePicture,omitempty"`

	// Apple OAuth
	AppleID    *string `json:"appleId,omitempty" gorm:"uniqueIndex"`
	AppleEmail *string `json:"appleEmail,omitempty"`
	AppleName  *string `json:"appleName,omitempty"`

	CreatedAt time.Time `json:"createdAt"`
	UpdatedAt time.Time `json:"updatedAt"`
}
