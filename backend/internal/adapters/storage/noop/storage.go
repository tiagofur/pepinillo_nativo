package noop

import "context"

type Storage struct{}

func NewStorage() *Storage {
	return &Storage{}
}

func (s *Storage) UploadProfileImage(_ context.Context, userID, fileName, contentType string, data []byte) (string, error) {
	return "", nil
}

// Ping is a no-op for the noop backend (R1: keeps the FileStorage contract).
func (s *Storage) Ping(_ context.Context) error {
	return nil
}
