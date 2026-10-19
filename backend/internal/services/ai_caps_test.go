package services

import (
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestTruncateRunes(t *testing.T) {
	require.Equal(t, "abc", truncateRunes("abc", 10))
	require.Equal(t, "", truncateRunes("abc", 0))
	// Rune-aware: multibyte chars are never split.
	s := "héllo wörld"
	got := truncateRunes(s, 5)
	require.Equal(t, "héllo\n[truncated]", got)
	require.True(t, len(got) > 0)
	require.False(t, strings.Contains(truncateRunes("short", 100), "[truncated]"))
}
