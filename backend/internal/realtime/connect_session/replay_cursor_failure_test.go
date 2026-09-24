package connectsession

import (
	"context"
	"testing"

	"github.com/coder/websocket/wsjson"
	"voice-platform/backend/internal/identity/authenticate_session"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
	replaypostgres "voice-platform/backend/internal/realtime/replay_event/postgres"
)

func TestReplayCursorFailuresDemandFullResync(t *testing.T) {
	cases := []struct {
		name    string
		failure error
		reason  string
	}{
		{"expired", replaypostgres.ErrExpiredCursor, "cursor_expired"},
		{"restart", replaypostgres.ErrDifferentEpoch, "server_restart"},
		{"overflow", replaypostgres.ErrReplayOverflow, "replay_limit"},
		{"unknown", replaypostgres.ErrInvalidCursor, "cursor_invalid"},
	}
	for _, test := range cases {
		t.Run(test.name, func(t *testing.T) {
			hub := eventhub.New(8)
			hub.SetJournal(&replayJournal{replayError: test.failure})
			auth := authenticatorFunc(func(context.Context, string) (authenticatesession.Principal, error) {
				return authenticatesession.Principal{AccountID: "44444444-4444-4444-8444-444444444444"}, nil
			})
			connection, closeSocket := openReplaySocket(t, hub, auth)
			defer closeSocket()
			var event Event
			if err := wsjson.Read(context.Background(), connection, &event); err != nil || event.Kind != "connection.resync_required" || event.Payload["reason"] != test.reason {
				t.Fatalf("event=%#v error=%v", event, err)
			}
		})
	}
}
