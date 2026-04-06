package ports

import "context"

type WebSocketManager interface {
	HandleConnection(ctx context.Context, userID string, conn interface{}) error
	SendToUser(userID string, message []byte) error
	SendToUserExcluding(userID, excludeDeviceID string, message []byte) error
	SendToAll(message []byte) error
	BroadcastToUsers(userIDs []string, message []byte) error
	DisconnectUser(userID string)
	UserCount(userID string) int
}
