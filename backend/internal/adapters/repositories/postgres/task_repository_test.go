package postgres

import (
	"testing"
	"time"
)

func TestShouldApplyClientUpdate(t *testing.T) {
	now := time.Now().UTC()

	cases := []struct {
		name           string
		existingOffset time.Duration
		clientOffset   time.Duration
		want           bool
	}{
		{name: "apply when client newer", existingOffset: -10 * time.Minute, clientOffset: -5 * time.Minute, want: true},
		{name: "apply when same timestamp", existingOffset: -10 * time.Minute, clientOffset: -10 * time.Minute, want: true},
		{name: "skip when client older", existingOffset: -5 * time.Minute, clientOffset: -10 * time.Minute, want: false},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got := shouldApplyClientUpdate(now.Add(tc.existingOffset), now.Add(tc.clientOffset))
			if got != tc.want {
				t.Fatalf("expected %v, got %v", tc.want, got)
			}
		})
	}
}
