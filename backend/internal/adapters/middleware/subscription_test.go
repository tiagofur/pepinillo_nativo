package middleware

import "testing"

func TestNormalizeTier(t *testing.T) {
	cases := []struct {
		input string
		want  string
	}{
		// Canonical tiers pass through unchanged.
		{"free", "free"},
		{"pepinillo_plus", "pepinillo_plus"},
		{"everywhere_monthly", "everywhere_monthly"},
		{"everywhere_annual", "everywhere_annual"},
		{"everywhere_lifetime", "everywhere_lifetime"},
		// Empty string → free.
		{"", "free"},
		// Unknown / legacy values → free (clean cutover, no aliases).
		{"pro", "free"},
		{"premium", "free"},
		{"pro_monthly", "free"},
		{"pro_annual", "free"},
		{"PRO_MONTHLY", "free"},
		{"EVERYWHERE_MONTHLY", "free"}, // case-sensitive canonical match
		{"unknown", "free"},
	}

	for _, tc := range cases {
		tc := tc
		t.Run(tc.input, func(t *testing.T) {
			got := NormalizeTier(tc.input)
			if got != tc.want {
				t.Errorf("NormalizeTier(%q) = %q, want %q", tc.input, got, tc.want)
			}
		})
	}
}

func TestCanSync(t *testing.T) {
	cases := []struct {
		tier string
		want bool
	}{
		{"everywhere_monthly", true},
		{"everywhere_annual", true},
		{"everywhere_lifetime", true},
		{"free", false},
		{"pepinillo_plus", false},
		{"", false},
		{"unknown", false},
	}

	for _, tc := range cases {
		tc := tc
		t.Run(tc.tier, func(t *testing.T) {
			got := CanSync(tc.tier)
			if got != tc.want {
				t.Errorf("CanSync(%q) = %v, want %v", tc.tier, got, tc.want)
			}
		})
	}
}
