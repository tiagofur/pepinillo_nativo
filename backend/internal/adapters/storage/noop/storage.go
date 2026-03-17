package noop

import "context"

type Storage struct{}

func NewStorage() *Storage {
	return &Storage{}
}

func (s *Storage) UploadProfileImage(_ context.Context, userID, fileName, contentType string, data []byte) (string, error) {
	return "", nil
}
