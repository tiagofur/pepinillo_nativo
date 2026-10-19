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

func TestResolveSyncTimestamp(t *testing.T) {
	now := time.Now().UTC()

	cases := []struct {
		name   string
		client time.Time
		want   time.Time
	}{
		// Slow device: past stamps preserved as-is so later edits compare
		// against the device's own timeline (no systematic self-lockout).
		{name: "past stamp preserved", client: now.Add(-time.Hour), want: now.Add(-time.Hour)},
		// Fast device: future stamps clamped to receipt time (no poisoning).
		{name: "future stamp clamped", client: now.Add(time.Hour), want: now},
		// Legacy zero stamp defaults to now.
		{name: "zero defaults to now", client: time.Time{}, want: now},
		{name: "exact now passes through", client: now, want: now},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := resolveSyncTimestamp(tc.client, now); !got.Equal(tc.want) {
				t.Fatalf("resolveSyncTimestamp(%v) = %v, want %v", tc.client, got, tc.want)
			}
		})
	}
}
