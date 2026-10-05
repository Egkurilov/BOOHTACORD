package sessionrealtime

import (
	"context"
	"github.com/google/uuid"
	"time"
	revoke "voice-platform/backend/internal/identity/revoke_own_sessions"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

type Repository interface {
	Revoke(context.Context, revoke.Input) (revoke.Result, error)
}
type Publisher interface {
	PublishToAccounts([]string, eventhub.Event)
}
type Store struct {
	Inner  Repository
	Events Publisher
}

func (s Store) Revoke(ctx context.Context, input revoke.Input) (revoke.Result, error) {
	result, err := s.Inner.Revoke(ctx, input)
	if err == nil && result.Count > 0 && s.Events != nil {
		s.Events.PublishToAccounts([]string{input.AccountID}, eventhub.Event{
			EventID: uuid.NewString(), Kind: "session.state_changed", OccurredAt: time.Now().UTC(), Payload: map[string]any{},
		})
	}
	return result, err
}
