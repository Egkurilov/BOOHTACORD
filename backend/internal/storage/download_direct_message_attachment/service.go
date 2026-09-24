package downloaddirectmessageattachment

import (
	"context"
	"errors"
	"fmt"
	"io"
	"strings"
	"unicode/utf8"

	"github.com/google/uuid"
	downloadtext "voice-platform/backend/internal/storage/download_text_attachment"
)

const MaxAttachmentBytes = downloadtext.MaxAttachmentBytes

var (
	ErrInvalidInput          = errors.New("invalid direct message attachment download")
	ErrAttachmentUnavailable = errors.New("direct message attachment unavailable")
	ErrFileUnavailable       = downloadtext.ErrFileUnavailable
)

type Input struct{ ActorID, DirectMessageID, AttachmentID string }
type Metadata struct {
	OriginalName, StorageKey string
	SizeBytes                int64
}
type Opened struct {
	Metadata Metadata
	Reader   io.ReadCloser
}
type Store interface {
	Find(context.Context, Input) (Metadata, error)
}
type Files interface {
	Open(string, int64) (io.ReadCloser, error)
}
type Service struct {
	store Store
	files Files
}

func New(store Store, files Files) Service { return Service{store: store, files: files} }

func (service Service) Open(ctx context.Context, input Input) (Opened, error) {
	if err := ctx.Err(); err != nil {
		return Opened{}, err
	}
	if !validUUID(input.ActorID) || !validUUID(input.DirectMessageID) || !validUUID(input.AttachmentID) {
		return Opened{}, ErrInvalidInput
	}
	metadata, err := service.store.Find(ctx, input)
	if errors.Is(err, ErrAttachmentUnavailable) {
		return Opened{}, ErrAttachmentUnavailable
	}
	if err != nil {
		return Opened{}, fmt.Errorf("find direct message attachment: %w", err)
	}
	if !validMetadata(metadata) {
		return Opened{}, errors.New("invalid authorized direct message attachment metadata")
	}
	reader, err := service.files.Open(metadata.StorageKey, metadata.SizeBytes)
	if errors.Is(err, ErrFileUnavailable) {
		return Opened{}, ErrAttachmentUnavailable
	}
	if err != nil {
		return Opened{}, fmt.Errorf("open authorized direct message attachment: %w", err)
	}
	return Opened{Metadata: metadata, Reader: reader}, nil
}

func validMetadata(metadata Metadata) bool {
	return utf8.ValidString(metadata.OriginalName) && metadata.OriginalName != "" &&
		!strings.ContainsRune(metadata.OriginalName, '\x00') && validUUID(metadata.StorageKey) &&
		metadata.SizeBytes >= 0 && metadata.SizeBytes <= MaxAttachmentBytes
}

func validUUID(value string) bool { _, err := uuid.Parse(value); return err == nil && len(value) == 36 }
