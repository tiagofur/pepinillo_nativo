package minio

import (
	"bytes"
	"context"
	"fmt"
	"path"
	"strings"
	"time"

	miniogo "github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

type Storage struct {
	client        *miniogo.Client
	bucket        string
	publicBaseURL string
}

func NewStorage(endpoint, accessKey, secretKey, bucket, publicBaseURL string, useSSL bool) (*Storage, error) {
	client, err := miniogo.New(endpoint, &miniogo.Options{
		Creds:  credentials.NewStaticV4(accessKey, secretKey, ""),
		Secure: useSSL,
	})
	if err != nil {
		return nil, err
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	exists, err := client.BucketExists(ctx, bucket)
	if err != nil {
		return nil, err
	}
	if !exists {
		if err := client.MakeBucket(ctx, bucket, miniogo.MakeBucketOptions{}); err != nil {
			return nil, err
		}
	}
	return &Storage{client: client, bucket: bucket, publicBaseURL: strings.TrimSuffix(publicBaseURL, "/")}, nil
}

// Ping verifies object-storage reachability (R1: health checks reuse the
// boot-built client instead of constructing a throwaway one per check).
func (s *Storage) Ping(ctx context.Context) error {
	_, err := s.client.BucketExists(ctx, s.bucket)
	return err
}

func (s *Storage) UploadProfileImage(ctx context.Context, userID, fileName, contentType string, data []byte) (string, error) {
	ext := path.Ext(fileName)
	if ext == "" {
		ext = ".bin"
	}
	objectName := fmt.Sprintf("profiles/%s/%d%s", userID, time.Now().UTC().UnixMilli(), ext)
	reader := bytes.NewReader(data)
	_, err := s.client.PutObject(ctx, s.bucket, objectName, reader, int64(len(data)), miniogo.PutObjectOptions{ContentType: contentType})
	if err != nil {
		return "", err
	}
	if s.publicBaseURL != "" {
		return fmt.Sprintf("%s/%s/%s", s.publicBaseURL, s.bucket, objectName), nil
	}
	return fmt.Sprintf("/%s/%s", s.bucket, objectName), nil
}
