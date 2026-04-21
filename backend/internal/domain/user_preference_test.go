package domain

import (
	"encoding/json"
	"testing"
)

func TestUserPreferenceUnmarshal_AcceptsKey(t *testing.T) {
	payload := []byte(`{"userId":"u1","key":"theme","value":"forest"}`)

	var pref UserPreference
	if err := json.Unmarshal(payload, &pref); err != nil {
		t.Fatalf("unmarshal failed: %v", err)
	}

	if pref.Key != "theme" {
		t.Fatalf("expected key=theme, got %q", pref.Key)
	}
}

func TestUserPreferenceUnmarshal_AcceptsPreferenceKeyAlias(t *testing.T) {
	payload := []byte(`{"userId":"u1","preferenceKey":"theme","value":"forest"}`)

	var pref UserPreference
	if err := json.Unmarshal(payload, &pref); err != nil {
		t.Fatalf("unmarshal failed: %v", err)
	}

	if pref.Key != "theme" {
		t.Fatalf("expected key from preferenceKey alias, got %q", pref.Key)
	}
}
