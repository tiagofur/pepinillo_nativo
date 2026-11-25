package domain

import (
	"testing"
)

// Issue #989 (S3): energy_level is free-form text on the wire because three
// client platforms shipped different vocabularies (Apple: deep/shallow/admin,
// Android: Deep/Regular/Light, web legacy: low/medium/high). The server must
// normalize on write so every stored value is canonical.
func TestNormalizeEnergyLevel(t *testing.T) {
	s := func(v string) *string { return &v }

	cases := []struct {
		name string
		in   *string
		want *string
	}{
		{"nil passes through", nil, nil},
		{"canonical deep", s("deep"), s("deep")},
		{"canonical shallow", s("shallow"), s("shallow")},
		{"canonical admin", s("admin"), s("admin")},
		{"case and space normalized", s("  DEEP "), s("deep")},
		{"android light", s("light"), s("shallow")},
		{"android regular", s("regular"), s("admin")},
		{"android deep stays", s("Deep"), s("deep")},
		{"web legacy low", s("low"), s("admin")},
		{"web legacy medium", s("medium"), s("shallow")},
		{"web legacy high", s("high"), s("deep")},
		{"empty becomes nil", s(""), nil},
		{"unknown fails shallow", s("urgent"), s("shallow")},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got := NormalizeEnergyLevel(tc.in)
			switch {
			case tc.want == nil && got != nil:
				t.Fatalf("want nil, got %q", *got)
			case tc.want != nil && got == nil:
				t.Fatalf("want %q, got nil", *tc.want)
			case tc.want != nil && *got != *tc.want:
				t.Fatalf("want %q, got %q", *tc.want, *got)
			}
		})
	}
}
