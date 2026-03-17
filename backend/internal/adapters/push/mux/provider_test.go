package mux

import (
	"context"
	"testing"
)

type fakeProvider struct {
	sent int
}

func (f *fakeProvider) Send(_ context.Context, _, _, _, _ string, _ map[string]string) error {
	f.sent++
	return nil
}

func TestMuxRoutesByPlatform(t *testing.T) {
	ios := &fakeProvider{}
	android := &fakeProvider{}
	fallback := &fakeProvider{}
	p := NewProvider(ios, android, fallback)

	if err := p.Send(context.Background(), "ios", "t1", "a", "b", nil); err != nil {
		t.Fatalf("ios send failed: %v", err)
	}
	if err := p.Send(context.Background(), "android", "t2", "a", "b", nil); err != nil {
		t.Fatalf("android send failed: %v", err)
	}
	if err := p.Send(context.Background(), "unknown", "t3", "a", "b", nil); err != nil {
		t.Fatalf("fallback send failed: %v", err)
	}

	if ios.sent != 1 || android.sent != 1 || fallback.sent != 1 {
		t.Fatalf("unexpected counts ios=%d android=%d fallback=%d", ios.sent, android.sent, fallback.sent)
	}
}
