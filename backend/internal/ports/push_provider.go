package ports

import "context"

type PushProvider interface {
	Send(ctx context.Context, platform, token, title, body string, data map[string]string) error
}
