package services

import (
	"testing"
	"time"

	"pepinillo/backend/internal/domain"
)

func TestEffectiveTier(t *testing.T) {
	now := time.Now().UTC()
	past := now.Add(-24 * time.Hour)
	future := now.Add(30 * 24 * time.Hour)

	cases := []struct {
		name string
		user domain.User
		want string
	}{
		{
			name: "free user, no entitlement",
			user: domain.User{
				SubscriptionTier:            "free",
				SubscriptionExpiresAt:       nil,
				PepinilloPlusEntitlementAt:  nil,
			},
			want: "free",
		},
		{
			name: "pepinillo_plus stored directly",
			user: domain.User{
				SubscriptionTier:            "pepinillo_plus",
				SubscriptionExpiresAt:       nil,
				PepinilloPlusEntitlementAt:  nil,
			},
			want: "pepinillo_plus",
		},
		{
			name: "everywhere_monthly active (no expiry = treated as active)",
			user: domain.User{
				SubscriptionTier:            "everywhere_monthly",
				SubscriptionExpiresAt:       nil,
				PepinilloPlusEntitlementAt:  nil,
			},
			want: "everywhere_monthly",
		},
		{
			name: "everywhere_annual active with future expiry",
			user: domain.User{
				SubscriptionTier:            "everywhere_annual",
				SubscriptionExpiresAt:       ptrTime(future),
				PepinilloPlusEntitlementAt:  nil,
			},
			want: "everywhere_annual",
		},
		{
			name: "everywhere_lifetime never expires",
			user: domain.User{
				SubscriptionTier:            "everywhere_lifetime",
				SubscriptionExpiresAt:       nil,
				PepinilloPlusEntitlementAt:  nil,
			},
			want: "everywhere_lifetime",
		},
		{
			name: "everywhere_monthly expired, no entitlement → free",
			user: domain.User{
				SubscriptionTier:            "everywhere_monthly",
				SubscriptionExpiresAt:       ptrTime(past),
				PepinilloPlusEntitlementAt:  nil,
			},
			want: "free",
		},
		{
			name: "everywhere_monthly expired, has pepinillo_plus entitlement → pepinillo_plus",
			user: domain.User{
				SubscriptionTier:            "everywhere_monthly",
				SubscriptionExpiresAt:       ptrTime(past),
				PepinilloPlusEntitlementAt:  ptrTime(past),
			},
			want: "pepinillo_plus",
		},
		{
			name: "free with pepinillo_plus entitlement → pepinillo_plus",
			user: domain.User{
				SubscriptionTier:            "free",
				SubscriptionExpiresAt:       nil,
				PepinilloPlusEntitlementAt:  ptrTime(past),
			},
			want: "pepinillo_plus",
		},
		{
			name: "unknown legacy tier with entitlement → pepinillo_plus",
			user: domain.User{
				SubscriptionTier:            "pro_monthly",
				SubscriptionExpiresAt:       nil,
				PepinilloPlusEntitlementAt:  ptrTime(past),
			},
			want: "pepinillo_plus",
		},
		{
			name: "unknown legacy tier, no entitlement → free",
			user: domain.User{
				SubscriptionTier:            "pro_monthly",
				SubscriptionExpiresAt:       nil,
				PepinilloPlusEntitlementAt:  nil,
			},
			want: "free",
		},
	}

	for _, tc := range cases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			got := EffectiveTier(&tc.user)
			if got != tc.want {
				t.Errorf("EffectiveTier() = %q, want %q", got, tc.want)
			}
		})
	}
}
