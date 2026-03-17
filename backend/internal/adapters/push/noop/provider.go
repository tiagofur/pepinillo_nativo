package noop

import (
	"context"
	"log"
)

type Provider struct{}

func NewProvider() *Provider {
	return &Provider{}
}

func (p *Provider) Send(_ context.Context, platform, token, title, body string, data map[string]string) error {
	log.Printf("[NOOP PUSH] platform=%s token=%s title=%s body=%s data=%v", platform, token, title, body, data)
	return nil
}
