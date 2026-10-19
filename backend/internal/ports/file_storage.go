package ports

import "context"

type FileStorage interface {
	UploadProfileImage(ctx context.Context, userID, fileName, contentType string, data []byte) (string, error)
	// Ping verifies backend connectivity without transferring objects.
	Ping(ctx context.Context) error
}
