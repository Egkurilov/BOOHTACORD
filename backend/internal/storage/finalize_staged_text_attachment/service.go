package finalizestagedtextattachment

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"unicode/utf8"
)

const MaxAttachmentBytes int64 = 25_000_000

var (
	ErrInvalidInput      = errors.New("invalid staged text attachment")
	ErrTargetUnavailable = errors.New("text attachment target unavailable")
)

type Input struct {
	ActorID, ChannelID, TempPath, OriginalName string
	SizeBytes                                  int64
}
type Request struct {
	ID, ActorID, ChannelID, OriginalName, StorageKey string
	SizeBytes                                        int64
}
type Result struct {
	ID, OwnerID, ChannelID, OriginalName, StorageKey string
	SizeBytes                                        int64
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
	if !validInput(input) {
		return Result{}, ErrInvalidInput
	}
	id, err := newIdentifier()
	if err != nil {
		return Result{}, fmt.Errorf("create attachment identifier: %w", err)
	}
	key, err := newIdentifier()
	if err != nil {
		return Result{}, fmt.Errorf("create attachment storage key: %w", err)
	}
	if err := service.mover.Move(input.TempPath, key); err != nil {
		return Result{}, fmt.Errorf("move staged attachment: %w", err)
	}
	result, err := service.store.Create(ctx, Request{ID: id, ActorID: input.ActorID, ChannelID: input.ChannelID, OriginalName: input.OriginalName, StorageKey: key, SizeBytes: input.SizeBytes})
	if err == nil {
		return result, nil
	}
	return Result{}, service.rollback(key, err)
}

func (service Service) rollback(key string, cause error) error {
	if err := service.mover.Remove(key); err != nil {
		return fmt.Errorf("%w; remove moved attachment: %v", cause, err)
	}
	if errors.Is(cause, ErrTargetUnavailable) {
		return ErrTargetUnavailable
	}
	return fmt.Errorf("persist unattached attachment: %w", cause)
}

func validInput(input Input) bool {
	return validUUID(input.ActorID) && validUUID(input.ChannelID) && input.TempPath != "" &&
		input.SizeBytes >= 0 && input.SizeBytes <= MaxAttachmentBytes && utf8.ValidString(input.OriginalName) &&
		input.OriginalName != "" && !strings.ContainsRune(input.OriginalName, '\x00')
}
