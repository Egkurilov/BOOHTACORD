package finalizestageddirectmessageattachment

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"unicode/utf8"

	"github.com/google/uuid"
)

const MaxAttachmentBytes int64 = 25_000_000

var (
	ErrInvalidInput      = errors.New("invalid staged direct message attachment")
	ErrTargetUnavailable = errors.New("direct message attachment target unavailable")
)

type Input struct {
	ActorID, DirectMessageID, TempPath, OriginalName string
	SizeBytes                                        int64
}
type Request struct {
	ID, ActorID, DirectMessageID, OriginalName, StorageKey string
	SizeBytes                                              int64
}
type Result struct {
	ID, OwnerID, DirectMessageID, OriginalName, StorageKey string
	SizeBytes                                              int64
}
type Store interface {
	Create(context.Context, Request) (Result, error)
}
type Mover interface {
	Move(string, string) error
	Remove(string) error
}
type Service struct {
	store Store
	mover Mover
}

func New(store Store, mover Mover) Service { return Service{store: store, mover: mover} }

func (service Service) Finalize(ctx context.Context, input Input) (Result, error) {
	if err := ctx.Err(); err != nil {
		return Result{}, err
	}
	if !validUUID(input.ActorID) || !validUUID(input.DirectMessageID) || input.TempPath == "" || input.SizeBytes < 0 || input.SizeBytes > MaxAttachmentBytes || !utf8.ValidString(input.OriginalName) || input.OriginalName == "" || strings.ContainsRune(input.OriginalName, '\x00') {
		return Result{}, ErrInvalidInput
	}
	id, key := uuid.NewString(), uuid.NewString()
	if err := service.mover.Move(input.TempPath, key); err != nil {
		return Result{}, fmt.Errorf("move staged direct message attachment: %w", err)
	}
	result, err := service.store.Create(ctx, Request{ID: id, ActorID: input.ActorID, DirectMessageID: input.DirectMessageID, OriginalName: input.OriginalName, StorageKey: key, SizeBytes: input.SizeBytes})
	if err == nil {
		return result, nil
	}
	if removeErr := service.mover.Remove(key); removeErr != nil {
		return Result{}, fmt.Errorf("%w; remove moved attachment: %v", err, removeErr)
	}
	if errors.Is(err, ErrTargetUnavailable) {
		return Result{}, ErrTargetUnavailable
	}
	return Result{}, fmt.Errorf("persist unattached direct message attachment: %w", err)
}

func validUUID(value string) bool { _, err := uuid.Parse(value); return err == nil && len(value) == 36 }
