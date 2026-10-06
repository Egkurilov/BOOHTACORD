package acquirevoicelease

import (
	"context"
	"crypto/sha256"
	"errors"
	"fmt"
	flowstage "voice-platform/backend/internal/observability/flow_stage"
)

var (
	ErrInvalidInput            = errors.New("invalid voice lease input")
	ErrVoiceChannelUnavailable = errors.New("voice channel unavailable")
	ErrSessionUnavailable      = errors.New("voice session unavailable")
	ErrActiveLease             = errors.New("active voice lease exists")
)

type Input struct {
	ActorID, ChannelID string
	SessionDigest      [sha256.Size]byte
	Transfer           bool
}
type Request struct {
	ID string
	Input
}
type Result struct {
	ID, ChannelID, ExistingChannelID string
	Transferred                      bool
}
type Store interface {
	Acquire(context.Context, Request) (Result, error)
}
type Service struct {
	store Store
	newID func() (string, error)
}

func New(store Store) Service { return Service{store: store, newID: newLeaseID} }

func (service Service) Acquire(context context.Context, input Input) (result Result, err error) {
	context, span := flowstage.Begin(context, "voice.lease.server", "lease")
	defer func() {
		flowstage.End(span, err, flowstage.Reject(ErrInvalidInput, "invalid"), flowstage.Reject(ErrActiveLease, "conflict"), flowstage.Reject(ErrSessionUnavailable, "revoked"), flowstage.Reject(ErrVoiceChannelUnavailable, "permission_denied"))
	}()
	if input.ActorID == "" || input.ChannelID == "" || input.SessionDigest == [sha256.Size]byte{} {
		return Result{}, ErrInvalidInput
	}
	id, err := service.newID()
	if err != nil {
		return Result{}, fmt.Errorf("create voice lease identifier: %w", err)
	}
	result, err = service.store.Acquire(context, Request{ID: id, Input: input})
	if errors.Is(err, ErrActiveLease) {
		return result, ErrActiveLease
	}
	if errors.Is(err, ErrVoiceChannelUnavailable) || errors.Is(err, ErrSessionUnavailable) {
		return Result{}, err
	}
	if err != nil {
		return Result{}, fmt.Errorf("persist voice lease: %w", err)
	}
	return result, nil
}
