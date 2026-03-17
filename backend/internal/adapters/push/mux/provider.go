package mux

import (
	"context"
	"errors"
	"strings"

	"pepinillo/backend/internal/ports"
)

var ErrUnsupportedPlatform = errors.New("unsupported_push_platform")

type Provider struct {
	iosProvider     ports.PushProvider
	androidProvider ports.PushProvider
	fallback        ports.PushProvider
}

func NewProvider(iosProvider, androidProvider, fallback ports.PushProvider) *Provider {
	return &Provider{
		iosProvider:     iosProvider,
		androidProvider: androidProvider,
		fallback:        fallback,
	}
}

func (p *Provider) Send(ctx context.Context, platform, token, title, body string, data map[string]string) error {
	switch strings.ToLower(strings.TrimSpace(platform)) {
	case "ios":
		if p.iosProvider != nil {
			return p.iosProvider.Send(ctx, platform, token, title, body, data)
		}
	case "android":
		if p.androidProvider != nil {
			return p.androidProvider.Send(ctx, platform, token, title, body, data)
		}
	default:
		if p.fallback == nil {
			return ErrUnsupportedPlatform
		}
		return p.fallback.Send(ctx, platform, token, title, body, data)
	}

	if p.fallback != nil {
		return p.fallback.Send(ctx, platform, token, title, body, data)
	}
	return ErrUnsupportedPlatform
}
