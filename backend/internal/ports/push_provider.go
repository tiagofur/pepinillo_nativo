package ports

import (
	"context"
	"errors"
)

// ErrPushTokenUnregistered signals a provider rejection meaning the device
// token is dead (FCM UNREGISTERED, APNS 410). Callers should deactivate the
// token instead of retrying it forever.
var ErrPushTokenUnregistered = errors.New("push_token_unregistered")

type PushProvider interface {
	Send(ctx context.Context, platform, token, title, body string, data map[string]string) error
}
