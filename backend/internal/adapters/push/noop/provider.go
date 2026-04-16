package noop

import (
	"context"
	"log/slog"
)

type Provider struct{}

func NewProvider() *Provider {
	return &Provider{}
}

func (p *Provider) Send(_ context.Context, platform, token, title, body string, data map[string]string) error {
	slog.Info("noop push",
		"platform", platform,
		"token", token,
		"title", title,
		"body", body,
		"data", data,
	)
	return nil
}
