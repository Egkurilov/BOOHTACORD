package uploadownavatar

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"image"
	_ "image/jpeg"
	"image/png"
	"mime"
	"strings"
)

const (
	maxUploadBytes = 2 << 20
	maxDimension   = 4096
	maxPNGBytes    = 8 << 20
)

var (
	ErrInvalidImage       = errors.New("invalid avatar image")
	ErrProfileUnavailable = errors.New("profile unavailable")
	ErrAvatarNotFound     = errors.New("avatar not found")
)

type Input struct {
	AccountID, ContentType string
	Data                   []byte
}
type Store interface {
	ReplaceAvatarKey(context.Context, string, string) (string, error)
	ClearAvatarKey(context.Context, string) (string, error)
}
type Files interface {
	SavePNG(context.Context, []byte) (string, error)
	Delete(context.Context, string) error
}
type Service struct {
	store Store
	files Files
}

func New(store Store, files Files) Service { return Service{store: store, files: files} }

func (service Service) Upload(ctx context.Context, input Input) (string, error) {
	mediaType, _, err := mime.ParseMediaType(input.ContentType)
	if input.AccountID == "" || len(input.Data) == 0 || len(input.Data) > maxUploadBytes || err != nil || (mediaType != "image/png" && mediaType != "image/jpeg") {
		return "", ErrInvalidImage
	}
	configuration, format, err := image.DecodeConfig(bytes.NewReader(input.Data))
	if err != nil || format != mediaType[strings.IndexByte(mediaType, '/')+1:] || configuration.Width < 1 || configuration.Height < 1 || configuration.Width > maxDimension || configuration.Height > maxDimension {
		return "", ErrInvalidImage
	}
	decoded, decodedFormat, err := image.Decode(bytes.NewReader(input.Data))
	if err != nil || decodedFormat != format {
		return "", ErrInvalidImage
	}
	var normalized bytes.Buffer
	if err := png.Encode(&normalized, decoded); err != nil || normalized.Len() > maxPNGBytes {
		return "", ErrInvalidImage
	}
	key, err := service.files.SavePNG(ctx, normalized.Bytes())
	if err != nil {
		return "", fmt.Errorf("save normalized avatar: %w", err)
	}
	oldKey, err := service.store.ReplaceAvatarKey(ctx, input.AccountID, key)
	if err != nil {
		_ = service.files.Delete(ctx, key)
		return "", fmt.Errorf("replace account avatar: %w", err)
	}
	if oldKey != "" && oldKey != key {
		_ = service.files.Delete(ctx, oldKey)
	}
	return key, nil
}

func (service Service) Delete(ctx context.Context, accountID string) error {
	if accountID == "" {
		return ErrProfileUnavailable
	}
	key, err := service.store.ClearAvatarKey(ctx, accountID)
	if err != nil {
		return fmt.Errorf("clear profile avatar: %w", err)
	}
	if key != "" {
		if err := service.files.Delete(ctx, key); err != nil {
			return fmt.Errorf("remove profile avatar: %w", err)
		}
	}
	return nil
}
