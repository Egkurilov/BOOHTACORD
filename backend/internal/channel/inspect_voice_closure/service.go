package inspectvoiceclosure

import (
	"context"
	"errors"
	"time"
)

var ErrNotFound = errors.New("voice closure not found")

type State struct {
	Closed, Archived bool
	Pending          int64
}
type Store interface {
	Read(context.Context, string) (State, error)
}
type Presence interface {
	CountRoomParticipants(context.Context, string) (int, error)
}
type Result struct {
	Phase              string    `json:"phase"`
	AdmissionClosed    bool      `json:"admission_closed"`
	PendingRevocations int64     `json:"pending_revocations"`
	RoomEmpty          *bool     `json:"room_empty"`
	CheckedAt          time.Time `json:"checked_at"`
	Detail             string    `json:"detail,omitempty"`
}
type Service struct {
	store    Store
	presence Presence
}

func New(store Store, presence Presence) Service { return Service{store, presence} }
func (s Service) Inspect(ctx context.Context, id string) (Result, error) {
	ctx, cancel := context.WithTimeout(ctx, 2*time.Second)
	defer cancel()
	state, err := s.store.Read(ctx, id)
	if err != nil {
		return Result{}, err
	}
	result := Result{Phase: "open", AdmissionClosed: state.Closed, PendingRevocations: state.Pending, CheckedAt: time.Now().UTC()}
	if state.Archived {
		result.Phase = "finalized"
		empty := true
		result.RoomEmpty = &empty
		return result, nil
	}
	if !state.Closed {
		return result, nil
	}
	result.Phase = "revoke_pending"
	count, err := s.presence.CountRoomParticipants(ctx, id)
	if err != nil {
		result.Detail = "sfu_unavailable"
		return result, nil
	}
	empty := count == 0
	result.RoomEmpty = &empty
	if empty && state.Pending == 0 {
		result.Phase = "room_empty"
	}
	return result, nil
}
