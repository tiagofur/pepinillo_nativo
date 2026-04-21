package services

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/require"

	"pepinillo/backend/internal/domain"
)

// ---------------------------------------------------------------------------
// LWW Preference Repository (simulates per-key last-writer-wins)
// ---------------------------------------------------------------------------

// lwwPreferenceRepository is a fake that enforces per-key LWW semantics
// to mirror the real Postgres implementation.
type lwwPreferenceRepository struct {
	prefs  map[string]domain.UserPreference // key → pref
	getErr error
}

func newLWWPreferenceRepository(initial ...domain.UserPreference) *lwwPreferenceRepository {
	repo := &lwwPreferenceRepository{prefs: make(map[string]domain.UserPreference)}
	for _, p := range initial {
		repo.prefs[p.Key] = p
	}
	return repo
}

func (r *lwwPreferenceRepository) GetByUser(_ context.Context, _ string) ([]domain.UserPreference, error) {
	if r.getErr != nil {
		return nil, r.getErr
	}
	result := make([]domain.UserPreference, 0, len(r.prefs))
	for _, p := range r.prefs {
		result = append(result, p)
	}
	return result, nil
}

func (r *lwwPreferenceRepository) UpsertBatch(_ context.Context, incoming []domain.UserPreference) ([]domain.UserPreference, error) {
	for _, p := range incoming {
		if cur, ok := r.prefs[p.Key]; ok {
			if p.UpdatedAt.After(cur.UpdatedAt) {
				r.prefs[p.Key] = p
			}
		} else {
			r.prefs[p.Key] = p
		}
	}
	result := make([]domain.UserPreference, 0, len(r.prefs))
	for _, p := range r.prefs {
		result = append(result, p)
	}
	return result, nil
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

func TestUpsertPreferences_NewerTimestampWins(t *testing.T) {
	old := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	newer := time.Date(2026, 3, 24, 0, 0, 0, 0, time.UTC)

	repo := newLWWPreferenceRepository(
		domain.UserPreference{UserID: "u1", Key: "theme", Value: "light", UpdatedAt: old},
	)
	svc := NewPreferenceService(repo, nil)

	merged, err := svc.UpsertPreferences(context.Background(), "u1", "d1", []domain.UserPreference{
		{Key: "theme", Value: "dark", UpdatedAt: newer},
	})
	require.NoError(t, err)
	require.Len(t, merged, 1)
	require.Equal(t, "dark", merged[0].Value)
}

func TestUpsertPreferences_OlderTimestampLoses(t *testing.T) {
	server := time.Date(2026, 3, 24, 12, 0, 0, 0, time.UTC)
	older := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)

	repo := newLWWPreferenceRepository(
		domain.UserPreference{UserID: "u1", Key: "theme", Value: "dark", UpdatedAt: server},
	)
	svc := NewPreferenceService(repo, nil)

	merged, err := svc.UpsertPreferences(context.Background(), "u1", "d1", []domain.UserPreference{
		{Key: "theme", Value: "light", UpdatedAt: older},
	})
	require.NoError(t, err)
	require.Len(t, merged, 1)
	// Server value should be kept
	require.Equal(t, "dark", merged[0].Value)
}

func TestUpsertPreferences_MixedTimestamps(t *testing.T) {
	serverTime := time.Date(2026, 3, 24, 12, 0, 0, 0, time.UTC)
	newerTime := time.Date(2026, 3, 25, 0, 0, 0, 0, time.UTC)
	olderTime := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)

	repo := newLWWPreferenceRepository(
		domain.UserPreference{UserID: "u1", Key: "theme", Value: "dark", UpdatedAt: serverTime},
		domain.UserPreference{UserID: "u1", Key: "lang", Value: "en", UpdatedAt: serverTime},
	)
	svc := NewPreferenceService(repo, nil)

	merged, err := svc.UpsertPreferences(context.Background(), "u1", "d1", []domain.UserPreference{
		{Key: "theme", Value: "solarized", UpdatedAt: newerTime}, // wins
		{Key: "lang", Value: "es", UpdatedAt: olderTime},         // loses
	})
	require.NoError(t, err)
	require.Len(t, merged, 2)

	byKey := make(map[string]string)
	for _, p := range merged {
		byKey[p.Key] = p.Value
	}
	require.Equal(t, "solarized", byKey["theme"])
	require.Equal(t, "en", byKey["lang"])
}

func TestUpsertPreferences_ReturnsMergedSet(t *testing.T) {
	now := time.Now().UTC()
	repo := newLWWPreferenceRepository(
		domain.UserPreference{UserID: "u1", Key: "existing", Value: "val1", UpdatedAt: now},
	)
	svc := NewPreferenceService(repo, nil)

	merged, err := svc.UpsertPreferences(context.Background(), "u1", "d1", []domain.UserPreference{
		{Key: "new_key", Value: "val2", UpdatedAt: now},
	})
	require.NoError(t, err)
	require.Len(t, merged, 2, "should contain both existing and new preferences")
}

func TestUpsertPreferences_EmptyInput(t *testing.T) {
	now := time.Now().UTC()
	repo := newLWWPreferenceRepository(
		domain.UserPreference{UserID: "u1", Key: "theme", Value: "dark", UpdatedAt: now},
	)
	svc := NewPreferenceService(repo, nil)

	merged, err := svc.UpsertPreferences(context.Background(), "u1", "d1", nil)
	require.NoError(t, err)
	require.Len(t, merged, 1)
	require.Equal(t, "dark", merged[0].Value)
}

func TestUpsertPreferences_WSNotification(t *testing.T) {
	now := time.Now().UTC()
	ws := &fakeWSManager{}
	repo := newLWWPreferenceRepository()
	svc := NewPreferenceService(repo, ws)

	_, err := svc.UpsertPreferences(context.Background(), "u1", "d1", []domain.UserPreference{
		{Key: "theme", Value: "dark", UpdatedAt: now},
	})
	require.NoError(t, err)
	require.Len(t, ws.sentMessages, 1)
	require.Equal(t, "u1", ws.sentMessages[0].userID)
	require.Equal(t, "d1", ws.sentMessages[0].excludeDeviceID)
}

func TestUpsertPreferences_RejectsEmptyKey(t *testing.T) {
	repo := newLWWPreferenceRepository()
	svc := NewPreferenceService(repo, nil)

	_, err := svc.UpsertPreferences(context.Background(), "u1", "d1", []domain.UserPreference{
		{Key: "", Value: "dark"},
	})
	require.ErrorIs(t, err, ErrInvalidPreferenceKey)
}
