package readmemberavatar

import (
	"context"
	"errors"
	"fmt"
)

var ErrAvatarNotFound = errors.New("member avatar not found")

type Store interface {
	FindAvatarKey(context.Context, string) (string, error)
}
type Files interface {
	ReadPNG(context.Context, string) ([]byte, error)
}
type Service struct {
	store Store
	files Files
}

func New(store Store, files Files) Service { return Service{store: store, files: files} }

func (service Service) Read(ctx context.Context, accountID string) ([]byte, error) {
	if accountID == "" {
		return nil, ErrAvatarNotFound
	}
	key, err := service.store.FindAvatarKey(ctx, accountID)
	if errors.Is(err, ErrAvatarNotFound) {
		return nil, ErrAvatarNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("find member avatar: %w", err)
	}
	data, err := service.files.ReadPNG(ctx, key)
	if err != nil {
		return nil, fmt.Errorf("read member avatar: %w", err)
	}
	return data, nil
}
