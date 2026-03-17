package noop

import "context"

// Provider is a no-op LLM provider that returns empty responses.
// Used when no API key is configured for graceful fallback.
type Provider struct{}

func NewProvider() *Provider {
	return &Provider{}
}

func (p *Provider) Generate(_ context.Context, _, _ string) (string, error) {
	return "", nil
}
