package ports

import "context"

type FileStorage interface {
	UploadProfileImage(ctx context.Context, userID, fileName, contentType string, data []byte) (string, error)
}
