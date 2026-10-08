package managevoicetimeout

import (
	"context"
	"errors"
	"github.com/google/uuid"
	"time"
)

var (
	ErrInvalidInput    = errors.New("invalid voice timeout")
	ErrForbidden       = errors.New("voice timeout forbidden")
	ErrUnauthenticated = errors.New("voice timeout session unavailable")
	ErrNotFound        = errors.New("voice timeout target unavailable")
)

type Input struct {
	ActorID, TargetID string
	SessionDigest     [32]byte
	ExpiresAt         time.Time
	Reason            string
}
type State struct {
	Active            bool       `json:"active"`
	ExpiresAt         *time.Time `json:"expires_at,omitempty"`
	Reason            string     `json:"reason_code,omitempty"`
	RevokedLeases     int        `json:"revoked_leases"`
	RevocationPending bool       `json:"revocation_pending"`
}
type Store interface {
	Set(context.Context, Input) (State, error)
	Clear(context.Context, Input) (State, error)
	Read(context.Context, Input) (State, error)
}
type Service struct{ store Store }

func New(store Store) Service { return Service{store: store} }
func (s Service) Set(ctx context.Context, in Input) (State, error) {
	var ok bool
	in, ok = normalizeIdentity(in)
	if !ok || in.ExpiresAt.IsZero() || !ValidReason(in.Reason) {
		return State{}, ErrInvalidInput
	}
	in.ExpiresAt = in.ExpiresAt.UTC().Truncate(time.Microsecond)
	return s.store.Set(ctx, in)
}
func (s Service) Clear(ctx context.Context, in Input) (State, error) {
	in, ok := normalizeIdentity(in)
	if !ok {
		return State{}, ErrInvalidInput
	}
	return s.store.Clear(ctx, in)
}
func (s Service) Read(ctx context.Context, in Input) (State, error) {
	in, ok := normalizeIdentity(in)
	if !ok {
		return State{}, ErrInvalidInput
	}
	return s.store.Read(ctx, in)
}
func normalizeIdentity(in Input) (Input, bool) {
	actor, err := uuid.Parse(in.ActorID)
	if err != nil {
		return in, false
	}
	target, err := uuid.Parse(in.TargetID)
	if err != nil {
		return in, false
	}
	in.ActorID = actor.String()
	in.TargetID = target.String()
	return in, in.SessionDigest != [32]byte{}
}
func ValidReason(reason string) bool {
	switch reason {
	case "DISRUPTION", "HARASSMENT", "SPAM", "OTHER":
		return true
	}
	return false
}
