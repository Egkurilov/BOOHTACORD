package verifysocialreplay

import (
	"context"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	hub "voice-platform/backend/internal/realtime/event_hub"
)

type authenticatorFunc func(context.Context, string) (auth.Principal, error)

func (f authenticatorFunc) Authenticate(ctx context.Context, cookie string) (auth.Principal, error) {
	return f(ctx, cookie)
}

type replayJournal struct{ events []hub.Event }

func (*replayJournal) Append(context.Context, hub.Event, []string, string) error { return nil }
func (j *replayJournal) Replay(context.Context, string, string, string, int) ([]hub.Event, error) {
	return j.events, nil
}
func (*replayJournal) Authorize(context.Context, string, hub.Event) (bool, error) { return true, nil }
