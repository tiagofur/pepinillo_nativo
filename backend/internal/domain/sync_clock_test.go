package domain

import (
	"testing"
	"time"
)

func TestResolveSyncTimestamp(t *testing.T) {
	now := time.Now().UTC()

	if got := ResolveSyncTimestamp(time.Time{}, now); !got.Equal(now) {
		t.Fatalf("zero defaults to now, got %v", got)
	}
	past := now.Add(-time.Hour)
	if got := ResolveSyncTimestamp(past, now); !got.Equal(past) {
		t.Fatalf("past preserved, got %v", got)
	}
	if got := ResolveSyncTimestamp(now.Add(time.Hour), now); !got.Equal(now) {
		t.Fatalf("future clamped to now, got %v", got)
	}
}
