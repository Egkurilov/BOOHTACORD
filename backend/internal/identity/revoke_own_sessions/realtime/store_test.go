package sessionrealtime

import (
	"context"
	"errors"
	"testing"
	revoke "voice-platform/backend/internal/identity/revoke_own_sessions"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

type fixtureStore struct {
	result revoke.Result
	err    error
}

func (s fixtureStore) Revoke(context.Context, revoke.Input) (revoke.Result, error) {
	return s.result, s.err
}

type fixtureEvents struct {
	targets []string
	events  []eventhub.Event
}

func (p *fixtureEvents) PublishToAccounts(targets []string, event eventhub.Event) {
	p.targets = targets
	p.events = append(p.events, event)
}
func TestOnlyCommittedRevocationPublishesCallerPrivateInvalidation(t *testing.T) {
	for _, row := range []struct {
		count    int
		err      error
		expected int
	}{
		{1, nil, 1}, {0, nil, 0}, {1, errors.New("rolled back"), 0},
	} {
		events := &fixtureEvents{}
		store := Store{Inner: fixtureStore{result: revoke.Result{Count: row.count}, err: row.err}, Events: events}
		_, _ = store.Revoke(context.Background(), revoke.Input{AccountID: "owner"})
		if len(events.events) != row.expected {
			t.Fatal("post-commit publication boundary failed")
		}
		if row.expected > 0 && (len(events.targets) != 1 || events.targets[0] != "owner" || events.events[0].Kind != "session.state_changed" || len(events.events[0].Payload) != 0) {
			t.Fatal("session invalidation leaks metadata or broadcasts")
		}
	}
}
